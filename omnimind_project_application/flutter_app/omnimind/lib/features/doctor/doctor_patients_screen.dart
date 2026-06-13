import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import 'patient_detail_page.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

Color _getRiskColor(String risk) {

  switch (risk.toLowerCase().trim()) {
    case 'high':
      return const Color(0xFFF44336);
    case 'moderate':
      return const Color(0xFFFF9800);
    case 'low':
      return const Color(0xFF4CAF50);
    default:
      return Colors.blueGrey;
  }
}

String _getRiskLabel(String risk) {
  switch (risk.toLowerCase().trim()) {
    case 'high':
      return 'HIGH RISK';
    case 'moderate':
      return 'MODERATE';
    case 'low':
      return 'LOW RISK';
    case 'critical':
      return 'CRITICAL';
    case 'unknown':
    default:
      return 'UNKNOWN';
  }
}


class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _fs = FirestoreService();

  String? _removingPatientUid;

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


  Future<void> _confirmAndRemove({
    required BuildContext context,
    required AppUser patient,
    required String doctorUid,
  }) async {
    final role = context.read<AuthProvider>().user?.role;
    if (role != UserRole.doctor) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not authorized to remove patients.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1520),
        title: const Text(
          'Remove patient?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will remove ${patient.name} from the system and delete their related patient data.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _removingPatientUid = patient.uid);

    try {
      await _fs.removePatientData(patient.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient removed successfully.')),
      );
      // Stream will refresh because user doc is deleted.
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove patient.')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _removingPatientUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1120),
        body: Center(
          child: Text(
            'Doctor not authenticated',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    if (user.role != UserRole.doctor) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1120),
        body: Center(
          child: Text(
            'Not authorized',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final doctorUid = user.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: StreamBuilder<List<AppUser>>(
        stream: AuthService().getDoctorPatients(doctorUid),
        builder: (context, snap) {
          final patients = snap.data ?? [];

          if (patients.isEmpty) {
            return const Center(
              child: Text(
                'No patients assigned yet',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final p = patients[i];
              final isRemoving = _removingPatientUid == p.uid;

              return Card(
                color: Colors.white.withOpacity(0.04),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                child: ListTile(
                  title: Text(
                    p.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    p.email,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  leading: IconButton(
                    tooltip: 'Remove patient',
                    icon: isRemoving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF6B6B),
                            ),
                          )
                        : const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFFF6B6B)),
                    onPressed: isRemoving
                        ? null
                        : () => _confirmAndRemove(
                              context: context,
                              patient: p,
                              doctorUid: doctorUid,
                            ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<String>(
                        future: _getPatientRiskFromFirestore(p.uid),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const SizedBox(
                              width: 60,
                              height: 20,
                            );
                          }
                          final risk = snap.data!;
                          final color = _getRiskColor(risk);
                          final label = _getRiskLabel(risk);


                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: color.withOpacity(0.3),
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
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white60,
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PatientDetailPage(patient: p),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
