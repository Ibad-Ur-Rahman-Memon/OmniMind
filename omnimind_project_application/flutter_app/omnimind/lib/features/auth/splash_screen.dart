import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/providers/app_providers.dart';
import '../../shared/theme/app_theme.dart';

import '../doctor/doctor_dashboard.dart';
import '../dashboard/patient_home.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeNavigate();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeNavigate() {
    final auth = context.read<AuthProvider>();

    if (_navigated) return;
    if (auth.loading) return;

    _navigated = true;

    final dest =
        auth.user != null
            ? (auth.isDoctor
                ? const DoctorDashboard()
                : const PatientHome())
            : const LoginScreen();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, __, ___) => dest,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_navigated && !auth.loading) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeNavigate(),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          /// BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.darkGradient,
              ),
            ),
          ),

          /// GLOW EFFECT
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          /// CONTENT
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1200),
                    tween: Tween<double>(
                      begin: 0.8,
                      end: 1,
                    ),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
                      height: 130,
                      width: 130,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: AppColors.primaryGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 35,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        size: 62,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Text(
                    'OmniMind',
                    style: GoogleFonts.poppins(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lightText,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'AI Mental Health Companion',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppColors.lightText.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 60),

                  SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.secondary,
                      ),
                      backgroundColor:
                          AppColors.lightTextSecondary.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

