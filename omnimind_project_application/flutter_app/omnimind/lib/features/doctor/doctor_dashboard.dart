// lib/features/doctor/doctor_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/models.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/app_providers.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firestore_service.dart';
import 'patient_detail_page.dart';
import '../auth/login_screen.dart';

class DoctorDashboard extends StatelessWidget {
  const DoctorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B1120),
              Color(0xFF111827),
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 190,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0F172A),
                        Color(0xFF111827),
                        Color(0xFF1E293B),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          22, 20, 22, 28),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF06B6D4),
                                      Color(0xFF14B8A6),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                              0xFF06B6D4)
                                          .withOpacity(0.25),
                                      blurRadius: 22,
                                      offset:
                                          const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    user?.name[0]
                                            .toUpperCase() ??
                                        'D',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome Back',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Dr. ${user?.name ?? 'Doctor'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight:
                                            FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'AI Mental Health Dashboard',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.65),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(18),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (user != null)
                    _DoctorPatientStream(
                      doctorUid: user.uid,
                    ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorPatientStream extends StatelessWidget {
  final String doctorUid;

  const _DoctorPatientStream({
    required this.doctorUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: AuthService().getDoctorPatients(
        doctorUid,
      ),
      builder: (_, snap) {
        final patients = snap.data ?? [];

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Patients',
                    value: '${patients.length}',
                    icon: Icons.people_alt_rounded,
                    color: const Color(0xFF06B6D4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    label: 'Active Today',
                    value:
                        '${(patients.length * 0.6).round()}',
                    icon:
                        Icons.monitor_heart_rounded,
                    color: const Color(0xFF14B8A6),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              'Your Patients',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            if (patients.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius:
                      BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        Colors.white.withOpacity(0.06),
                  ),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        size: 52,
                        color: Colors.white54,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'No patients assigned yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...patients.map(
                (p) => _PatientListTile(
                  patient: p,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

Color _getRiskColor(String risk) {
  switch (risk.toLowerCase()) {
    case 'low':
      return Colors.greenAccent;
    case 'moderate':
      return Colors.orangeAccent;
    case 'high':
      return Colors.redAccent;
    default:
      return Colors.blueGrey;
  }
}

class _PatientListTile extends StatelessWidget {
  final AppUser patient;

  const _PatientListTile({
    required this.patient,
  });

  Future<String> _getPatientRiskFromFirestore(String patientUid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      final data = userDoc.data();
      if (data != null) {
        final riskLevel = data['riskLevel'] as String?;
        if (riskLevel != null &&
            riskLevel.trim().isNotEmpty &&
            riskLevel.toLowerCase().trim() != 'unknown') {
          return riskLevel.toLowerCase().trim();
        }
      }

      final assessSnap = await FirebaseFirestore.instance
          .collection('assessments')
          .doc(patientUid)
          .collection('results')
          .get();

      if (assessSnap.docs.isEmpty) return 'unknown';

      int phq = 0, gad = 0, pss = 0, spin = 0;
      for (final doc in assessSnap.docs) {
        final name = doc.id.toUpperCase();
        final score = (doc.data()['score'] as int?) ?? 0;

        if (name.contains('PHQ')) phq = score;
        if (name.contains('GAD')) gad = score;
        if (name.contains('PSS')) pss = score;
        if (name.contains('SPIN')) spin = score;
      }

      if (phq >= 15 || gad >= 15 || pss >= 27) return 'high';
      if (phq >= 10 || gad >= 10 || pss >= 14 || spin >= 20) {
        return 'moderate';
      }
      if (phq >= 5 || gad >= 5 || pss >= 7 || spin >= 10) return 'low';

      if (phq + gad + pss + spin > 0) return 'low';

      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(

      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),

        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF06B6D4),
                Color(0xFF14B8A6),
              ],
            ),
          ),
          child: Center(
            child: Text(
              patient.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ),

        title: Text(
          patient.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 16,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),

            Text(
              patient.email,
              style: TextStyle(
                fontSize: 12,
                color:
                    Colors.white.withOpacity(0.7),
              ),
            ),

            const SizedBox(height: 6),

            FutureBuilder<DateTime?>(
              future: FirestoreService()
                  .getPatientLastActive(
                      patient.uid),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white
                          .withOpacity(0.5),
                    ),
                  );
                }

                return Text(
                  'Last active ${timeago.format(snap.data!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.white.withOpacity(0.6),
                  ),
                );
              },
            ),
          ],
        ),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<String>(
              future: _getPatientRiskFromFirestore(patient.uid),
              builder: (context, snap) {
                final risk = (snap.data ?? 'unknown').trim().toLowerCase();

                final color = _getRiskColor(risk);
                final label = (risk.isEmpty || risk == 'unknown')
                    ? 'NO DATA'
                    : risk.toUpperCase();

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: color.withOpacity(0.25),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 10),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Colors.white.withOpacity(0.6),
            ),
          ],
        ),

        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  PatientDetailPage(
                patient: patient,
              ),
            ),
          );
        },
      ),
    );
  }
}