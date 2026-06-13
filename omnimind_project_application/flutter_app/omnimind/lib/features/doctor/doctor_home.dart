// lib/features/doctor/doctor_home.dart

import 'package:flutter/material.dart';
import 'doctor_dashboard.dart';
import 'doctor_patients_screen.dart';

import '../../core/providers/app_providers.dart';
import '../../features/auth/login_screen.dart';
import '../../core/services/auth_service.dart';

import 'package:provider/provider.dart';





class DoctorHome extends StatefulWidget {
  const DoctorHome({super.key});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  int _index = 0;

  final _pages = const [
    DoctorDashboard(),
    DoctorPatientsScreen(),
    // index 2: handled by logout action
    SizedBox.shrink(),
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),

      body: IndexedStack(
        index: _index,
        children: _pages,
      ),

      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),

        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),

          child: BottomNavigationBar(
            currentIndex: _index,

            onTap: (i) async {
              if (i == 2) {
                final auth = context.read<AuthProvider>();
                await auth.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                );
                return;
              }
              setState(() => _index = i);
            },

            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,

            selectedItemColor: const Color(0xFF06B6D4),
            unselectedItemColor:
                Colors.white.withOpacity(0.55),

            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),

            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),

            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.dashboard_outlined,
                    size: 24,
                  ),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.dashboard_rounded,
                    size: 26,
                  ),
                ),
                label: 'Dashboard',
              ),

              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: 24,
                  ),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.people_rounded,
                    size: 26,
                  ),
                ),
                label: 'Patients',
              ),

              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 24,
                  ),
                ),
                activeIcon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 26,
                  ),
                ),
                label: 'Logout',
              ),
            ],
          ),
        ),
      ),
    );
  }
}