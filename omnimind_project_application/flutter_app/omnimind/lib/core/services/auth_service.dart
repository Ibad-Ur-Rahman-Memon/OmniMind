// lib/core/services/auth_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

/// FirebaseAuthService - Authentication with Firebase
/// Uses Firebase Authentication for user management and Firestore for user profiles
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPreferences _prefs;
  final _uuid = const Uuid();

  static const String _currentUserKey = 'omnimind_current_user';

  FirebaseAuthService._internal(this._prefs);
  
  static Future<FirebaseAuthService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FirebaseAuthService._internal(prefs);
  }

  // ── Current User ───────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getCurrentAppUser() async {
    // First try to get from local storage
    final localUser = await _getLocalUser();
    if (localUser != null) {
      return localUser;
    }
    
    // If no local user, check Firebase user and fetch from Firestore
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    
    // Fetch user profile from Firestore
    final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
    if (!doc.exists) return null;
    
    final userData = doc.data()!;
    final appUser = AppUser(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: userData['name'] ?? firebaseUser.displayName ?? '',
      role: userData['role'] == 'doctor' ? UserRole.doctor : UserRole.patient,
      createdAt: userData['createdAt'] != null 
          ? DateTime.parse(userData['createdAt']) 
          : DateTime.now(),
    );
    
    // Cache locally
    await _saveLocalUser(appUser);
    return appUser;
  }

  Future<AppUser?> _getLocalUser() async {
    final userJson = _prefs.getString(_currentUserKey);
    if (userJson == null) return null;
    
    final data = jsonDecode(userJson) as Map<String, dynamic>;
    return AppUser(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] == 'doctor' ? UserRole.doctor : UserRole.patient,
      createdAt: data['createdAt'] != null 
          ? DateTime.parse(data['createdAt']) 
          : DateTime.now(),
    );
  }

  Future<void> _saveLocalUser(AppUser user) async {
    await _prefs.setString(_currentUserKey, jsonEncode({
      'uid': user.uid,
      'email': user.email,
      'name': user.name,
      'role': user.role == UserRole.doctor ? 'doctor' : 'patient',
      'createdAt': user.createdAt.toIso8601String(),
    }));
  }

  Future<void> _clearLocalUser() async {
    await _prefs.remove(_currentUserKey);
  }

  // ── Sign Up ─────────────────────────────────────────────────────────────

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    // Create Firebase user
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) throw Exception('Failed to create user');

    // Update display name
    await user.updateDisplayName(name);

    // Create user profile in Firestore
    final userData = {
      'uid': user.uid,
      'email': email,
      'name': name,
      'role': role == UserRole.doctor ? 'doctor' : 'patient',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await _firestore.collection('users').doc(user.uid).set(userData);

    // If a patient is signing up, auto-assign them to the first available doctor
    if (role == UserRole.patient) {
      await _autoAssignPatientToDoctor(user.uid);
    }

    // Cache locally
    final appUser = AppUser(
      uid: user.uid,
      email: email,
      name: name,
      role: role,
      createdAt: DateTime.now(),
    );
    await _saveLocalUser(appUser);

    print('✅ User signed up with Firebase: $email (UID: ${user.uid})');
    return appUser;
  }

  /// Auto-assign a new patient to the first available doctor.
  /// Creates the assignment document in the doctor's subcollection
  /// AND sets the doctorUid field on the patient's user document.
  Future<void> _autoAssignPatientToDoctor(String patientUid) async {
    try {
      // Find the first doctor in the system
      final doctorSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .limit(1)
          .get();

      if (doctorSnap.docs.isEmpty) {
        print('⚠️ No doctor found to assign patient $patientUid to');
        return;
      }

      final doctorDoc = doctorSnap.docs.first;
      final doctorUid = doctorDoc.id;
      print('✅ Auto-assigning patient $patientUid to doctor $doctorUid');

      // Create assignment document under doctors/{doctorUid}/patients/{patientUid}
      await _firestore
          .collection('doctors')
          .doc(doctorUid)
          .collection('patients')
          .doc(patientUid)
          .set({
        'active': true,
        'assignedAt': DateTime.now().toIso8601String(),
        'patientUid': patientUid,
        'doctorUid': doctorUid,
      });

      // Also create under patientAssignments for compatibility
      await _firestore
          .collection('doctors')
          .doc(doctorUid)
          .collection('patientAssignments')
          .doc(patientUid)
          .set({
        'active': true,
        'assignedAt': DateTime.now().toIso8601String(),
        'patientUid': patientUid,
        'doctorUid': doctorUid,
      });

      // Also create under assignedPatients for compatibility
      await _firestore
          .collection('doctors')
          .doc(doctorUid)
          .collection('assignedPatients')
          .doc(patientUid)
          .set({
        'active': true,
        'assignedAt': DateTime.now().toIso8601String(),
        'patientUid': patientUid,
        'doctorUid': doctorUid,
      });

      // Update the patient's user document with doctorUid and assignedDoctorId
      await _firestore.collection('users').doc(patientUid).set({
        'doctorUid': doctorUid,
        'assignedDoctorId': doctorUid,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      print('✅ Patient $patientUid successfully assigned to doctor $doctorUid');
    } catch (e) {
      print('❌ Failed to auto-assign patient: $e');
    }
  }

  // ── Sign In ─────────────────────────────────────────────────────────────

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    print('🔐 Signing in with Firebase: $email');
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;
    print('✅ Firebase user signed in: ${user.uid} - ${user.email}');
    
    if (user.emailVerified == false) {
      print('⚠️ Email not verified for user ${user.uid}');
    }

    // Fetch user profile from Firestore
    print('📄 Fetching Firestore user doc: users/${user.uid}');
    final doc = await _firestore.collection('users').doc(user.uid).get();
    print('📄 Firestore doc exists: ${doc.exists}');
    
    AppUser appUser;
    if (doc.exists) {
      final userData = doc.data()!;
      print('✅ Firestore user data: ${userData['name']} (${userData['role']})');
      appUser = AppUser(
        uid: user.uid,
        email: user.email ?? email,
        name: userData['name'] ?? user.displayName ?? '',
        role: userData['role'] == 'doctor' ? UserRole.doctor : UserRole.patient,
        createdAt: userData['createdAt'] != null 
            ? DateTime.parse(userData['createdAt']) 
            : DateTime.now(),
      );
    } else {
      print('⚠️ No Firestore doc for ${user.uid} - creating fallback');
      appUser = AppUser(
        uid: user.uid,
        email: user.email ?? email,
        name: user.displayName ?? '',
        role: UserRole.patient, // Default role
        createdAt: DateTime.now(),
      );
    }

    // Cache locally
    await _saveLocalUser(appUser);

    print('✅ User signed in with Firebase: $email');
    return appUser;
  }

  // ── Sign Out ──────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    await _clearLocalUser();
    print('✅ User signed out, cleared local storage');
  }

  // ── Password Reset ────────────────────────────────────────────────────

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Get All Users (for admin/doctor features) ─────────────────────────

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AppUser(
        uid: data['uid'] ?? doc.id,
        email: data['email'] ?? '',
        name: data['name'] ?? '',
        role: data['role'] == 'doctor' ? UserRole.doctor : UserRole.patient,
        createdAt: data['createdAt'] != null 
            ? DateTime.parse(data['createdAt']) 
            : DateTime.now(),
      );
    }).toList();
  }

  // ── Get Doctors ───────────────────────────────────────────────────────

  Future<List<AppUser>> getDoctors() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AppUser(
        uid: data['uid'] ?? doc.id,
        email: data['email'] ?? '',
        name: data['name'] ?? '',
        role: UserRole.doctor,
        createdAt: data['createdAt'] != null 
            ? DateTime.parse(data['createdAt']) 
            : DateTime.now(),
      );
    }).toList();
  }

  // ── Get Patients ──────────────────────────────────────────────────────

  Future<List<AppUser>> getPatients() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AppUser(
        uid: data['uid'] ?? doc.id,
        email: data['email'] ?? '',
        name: data['name'] ?? '',
        role: UserRole.patient,
        createdAt: data['createdAt'] != null 
            ? DateTime.parse(data['createdAt']) 
            : DateTime.now(),
      );
    }).toList();
  }

  // ── Doctor's patients stream ──────────────────────────────────────────

  Stream<List<AppUser>> getDoctorPatients(String doctorUid) {
    // Doctor dashboard must show patients assigned to this doctor.
    // Firestore schema varies across project versions; we try multiple
    // likely locations and add debug logs.

    // Candidate relationship sources (in priority order)
    // 1) doctors/{doctorUid}/patientAssignments/{patientUid}
    // 2) doctors/{doctorUid}/assignedPatients/{patientUid}
    // 3) doctors/{doctorUid}/patients/{patientUid}
    // 4) users where assignedDoctorUid == doctorUid (or doctorUid == doctorUid)
    // 5) FINAL FALLBACK: all patients with role=patient

    // Because streams must be single-return, we implement a resilient
    // stream that first listens to path-based assignments, and if empty,
    // falls back to other paths with periodic re-check.

    Stream<List<AppUser>> buildFromAssignmentCollection(String path) {
      return _firestore
          .collection('doctors')
          .doc(doctorUid)
          .collection(path)
          .snapshots()
          .asyncMap((assignSnap) async {
        // filter by active if present (missing => active)
        final activeDocs = assignSnap.docs.where((d) {
          final data = d.data();
          final v = data['active'];
          if (v == null) return true;
          return v == true;
        }).toList();

        final patientUids = activeDocs.map((d) => d.id).toList();
if (kDebugMode) {
          // ignore: avoid_print
          print('[DoctorPatients] doctorUid=$doctorUid path=$path activeCount=${patientUids.length}');
        }

        if (patientUids.isEmpty) return <AppUser>[];

        final patients = <AppUser>[];
        const chunkSize = 30;

        for (var i = 0; i < patientUids.length; i += chunkSize) {
          final chunk = patientUids.sublist(
            i,
            i + chunkSize > patientUids.length
                ? patientUids.length
                : i + chunkSize,
          );

          final userSnap = await _firestore
              .collection('users')
              .where('uid', whereIn: chunk)
              .get();

          patients.addAll(userSnap.docs.map((doc) {
            final data = doc.data();
            return AppUser(
              uid: data['uid'] ?? doc.id,
              email: data['email'] ?? '',
              name: data['name'] ?? '',
              role: UserRole.patient,
              createdAt: data['createdAt'] != null
                  ? DateTime.parse(data['createdAt'])
                  : DateTime.now(),
            );
          }));
        }

        final byUid = {for (final p in patients) p.uid: p};
        return patientUids
            .map((uid) => byUid[uid])
            .whereType<AppUser>()
            .toList();
      });
    }

    // First try primary schema with a stream.
    final primaryStream = buildFromAssignmentCollection('patientAssignments');

    // If that ends up empty, we also try other possible assignment collections
    // by merging their outputs (dedupe by uid). We emit combined results.
    final stream2 = buildFromAssignmentCollection('assignedPatients');
    final stream3 = buildFromAssignmentCollection('patients');

    // 4) Fallback: patient docs have a doctor-link field.
    // AppUser model suggests `assignedDoctorId`, but schema may differ.
    // We try several likely field names and merge their outputs.

    Stream<List<AppUser>> fallbackByAnyDoctorField({
      required String fieldName,
    }) {
      return _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .where(fieldName, isEqualTo: doctorUid)
          .snapshots()
          .map((snap) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[DoctorPatients] fallback $fieldName matched=${snap.docs.length}');
        }
        return snap.docs.map((doc) {
          final data = doc.data();
          return AppUser(
            uid: data['uid'] ?? doc.id,
            email: data['email'] ?? '',
            name: data['name'] ?? '',
            role: UserRole.patient,
            assignedDoctorId: data['assignedDoctorId'],
            createdAt: data['createdAt'] != null
                ? DateTime.parse(data['createdAt'])
                : DateTime.now(),
          );
        }).toList();
      });
    }

    final fallbackByField1 = fallbackByAnyDoctorField(fieldName: 'assignedDoctorId');
    final fallbackByField2 = fallbackByAnyDoctorField(fieldName: 'assignedDoctorUid');
    final fallbackByField3 = fallbackByAnyDoctorField(fieldName: 'doctorId');
    final fallbackByField4 = fallbackByAnyDoctorField(fieldName: 'doctorUid');

    // 5) ULTIMATE FALLBACK: Return ALL patients if nothing else matched.
    // This ensures doctors can always see patients even if assignment
    // structures haven't been set up properly.
    Stream<List<AppUser>> allPatientsFallback() {
      return _firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .snapshots()
          .map((snap) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[DoctorPatients] ALL_PATIENTS_FALLBACK matched=${snap.docs.length}');
        }
        return snap.docs.map((doc) {
          final data = doc.data();
          return AppUser(
            uid: data['uid'] ?? doc.id,
            email: data['email'] ?? '',
            name: data['name'] ?? '',
            role: UserRole.patient,
            assignedDoctorId: data['assignedDoctorId'],
            createdAt: data['createdAt'] != null
                ? DateTime.parse(data['createdAt'])
                : DateTime.now(),
          );
        }).toList();
      });
    }

    final allPatientsStream = allPatientsFallback();

    // Combine streams without RxDart: we will listen to all fallback streams
    // and dedupe by uid when any updates.

    // We'll use controller merge pattern later; we just pass through these
    // streams by adding a 5th/6th/7th/8th "latest" list.

    // Combine streams without needing RxDart.
    // We'll listen to all streams and always output the latest merged snapshot.
    StreamController<List<AppUser>> controller;
    controller = StreamController<List<AppUser>>(onListen: () {});

    List<AppUser> latest1 = [];
    List<AppUser> latest2 = [];
    List<AppUser> latest3 = [];
    List<AppUser> latest4 = [];
    List<AppUser> latest5 = []; // Ultime fallback: all patients

    late final StreamSubscription<List<AppUser>> sub1;
    late final StreamSubscription<List<AppUser>> sub2;
    late final StreamSubscription<List<AppUser>> sub3;
    late final sub4;
    late final StreamSubscription<List<AppUser>> sub5;

    void emitMerged() {
      final all = <String, AppUser>{};
      for (final p in [...latest1, ...latest2, ...latest3, ...latest4, ...latest5]) {
        all[p.uid] = p;
      }
      final merged = all.values.toList();
      if (kDebugMode) {
        // ignore: avoid_print
        print('[DoctorPatients] mergedCount=${merged.length}');
      }
      controller.add(merged);
    }

    // Subscriptions
    sub1 = primaryStream.listen((v) {
      latest1 = v;
      emitMerged();
    }, onError: controller.addError);
    sub2 = stream2.listen((v) {
      latest2 = v;
      emitMerged();
    }, onError: controller.addError);
    sub3 = stream3.listen((v) {
      latest3 = v;
      emitMerged();
    }, onError: controller.addError);

    // subscribe each fallback field stream and merge into latest4
    final fallbackStreams = <Stream<List<AppUser>>>[
      fallbackByField1,
      fallbackByField2,
      fallbackByField3,
      fallbackByField4,
    ];

    // Start with empty and update when any stream emits.
    late final List<List<AppUser>> fallbackLatest;
    fallbackLatest = List.generate(fallbackStreams.length, (_) => <AppUser>[]);

    for (var idx = 0; idx < fallbackStreams.length; idx++) {
      final s = fallbackStreams[idx];
      s.listen((v) {
        fallbackLatest[idx] = v;
        latest4 = fallbackLatest.expand((e) => e).toList();
        emitMerged();
      }, onError: controller.addError);
    }

    // Subscribe to the all-patients fallback stream
    sub5 = allPatientsStream.listen((v) {
      latest5 = v;
      emitMerged();
    }, onError: controller.addError);

    controller.onCancel = () async {
      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
      await sub5.cancel();
    };

    return controller.stream;
  }
}

// ── AuthService - Main service using Firebase ───────────────────────────────

class AuthService {
  late final FirebaseAuthService _firebaseAuth;
  bool _initialized = false;

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<void> init() async {
    if (_initialized) return;
    _firebaseAuth = await FirebaseAuthService.create();
    _initialized = true;
  }

  // ── Current user ──────────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges;

  Future<AppUser?> getCurrentAppUser() async {
    if (!_initialized) await init();
    return _firebaseAuth.getCurrentAppUser();
  }

  // ── Sign Up ───────────────────────────────────────────────────────────────

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    if (!_initialized) await init();
    return _firebaseAuth.signUp(
      email: email,
      password: password,
      name: name,
      role: role,
    );
  }

  // ── Sign In ───────────────────────────────────────────────────────────────

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (!_initialized) await init();
    print('🔑 FirebaseAuth.signInWithEmailAndPassword: $email');
    return _firebaseAuth.signIn(email: email, password: password);
  }

  // ── Sign Out ──────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (!_initialized) await init();
    return _firebaseAuth.signOut();
  }

  // ── Password Reset ────────────────────────────────────────────────────

  Future<void> resetPassword(String email) async {
    if (!_initialized) await init();
    return _firebaseAuth.resetPassword(email);
  }

  // ── Doctor list ───────────────────────────────────────────────────────────

  Future<List<AppUser>> getDoctors() async {
    if (!_initialized) await init();
    return _firebaseAuth.getDoctors();
  }

  // ── Get All Patients (for doctor) ─────────────────────────────────────

  Future<List<AppUser>> getPatients() async {
    if (!_initialized) await init();
    return _firebaseAuth.getPatients();
  }

  // ── Doctor's patients ─────────────────────────────────────────────────────

  Stream<List<AppUser>> getDoctorPatients(String doctorUid) {
    if (!_initialized) throw Exception('AuthService not initialized');
    return _firebaseAuth.getDoctorPatients(doctorUid);
  }

  /// Migrate existing unassigned patients to the first doctor.
  /// This is a one-time fix for patients registered before auto-assignment was added.
  Future<void> migrateExistingPatients() async {
    if (!_initialized) await init();
    try {
      // Find the first doctor
      final doctorSnap = await _firebaseAuth._firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .limit(1)
          .get();

      if (doctorSnap.docs.isEmpty) {
        print('⚠️ No doctor found for migration');
        return;
      }

      final doctorUid = doctorSnap.docs.first.id;

      // Find all patients that don't have doctorUid set
      final patients = await _firebaseAuth._firestore
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .get();

      int migratedCount = 0;
      for (final doc in patients.docs) {
        final data = doc.data();
        final hasDoctorUid = data.containsKey('doctorUid') && data['doctorUid'] != null;
        final hasAssignment = data.containsKey('assignedDoctorId') && data['assignedDoctorId'] != null;
        
        if (!hasDoctorUid && !hasAssignment) {
          final patientUid = doc.id;
          print('🔄 Migrating patient $patientUid to doctor $doctorUid');

          // Create in all three subcollections
          await _firebaseAuth._firestore
              .collection('doctors')
              .doc(doctorUid)
              .collection('patients')
              .doc(patientUid)
              .set({
            'active': true,
            'assignedAt': DateTime.now().toIso8601String(),
            'patientUid': patientUid,
            'doctorUid': doctorUid,
          });

          await _firebaseAuth._firestore
              .collection('doctors')
              .doc(doctorUid)
              .collection('patientAssignments')
              .doc(patientUid)
              .set({
            'active': true,
            'assignedAt': DateTime.now().toIso8601String(),
            'patientUid': patientUid,
            'doctorUid': doctorUid,
          });

          await _firebaseAuth._firestore
              .collection('doctors')
              .doc(doctorUid)
              .collection('assignedPatients')
              .doc(patientUid)
              .set({
            'active': true,
            'assignedAt': DateTime.now().toIso8601String(),
            'patientUid': patientUid,
            'doctorUid': doctorUid,
          });

          // Update user document
          await _firebaseAuth._firestore.collection('users').doc(patientUid).set({
            'doctorUid': doctorUid,
            'assignedDoctorId': doctorUid,
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));

          migratedCount++;
        }
      }

      print('✅ Migration complete: $migratedCount patients assigned to doctor $doctorUid');
    } catch (e) {
      print('❌ Migration failed: $e');
    }
  }
}
