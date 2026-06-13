import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

// UI-only styling tweaks for dark premium glassmorphism login screens
// (Business logic/animations/flow are unchanged.)

import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/theme/app_theme.dart';

import '../dashboard/patient_home.dart';
import '../doctor/doctor_home.dart';
import '../offline/offline_access_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _obscure = true;

  final _signInEmail = TextEditingController();
  final _signInPass = TextEditingController();

  final _signUpName = TextEditingController();
  final _signUpEmail = TextEditingController();
  final _signUpPass = TextEditingController();

  UserRole _selectedRole = UserRole.patient;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);

    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();

    _signInEmail.dispose();
    _signInPass.dispose();

    _signUpName.dispose();
    _signUpEmail.dispose();
    _signUpPass.dispose();

    super.dispose();
  }

  void _navigateAfterAuth() {
    final auth = context.read<AuthProvider>();

    final dest = auth.isDoctor ? const DoctorHome() : const PatientHome();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => dest),
    );
  }

  Future<void> _signIn() async {
    final auth = context.read<AuthProvider>();

    final ok = await auth.signIn(
      email: _signInEmail.text.trim(),
      password: _signInPass.text,
    );

    if (ok && mounted) {
      _navigateAfterAuth();
    }
  }

  Future<void> _signUp() async {
    final name = _signUpName.text.trim();
    final email = _signUpEmail.text.trim();
    final pass = _signUpPass.text;

    if (name.isEmpty) {
      _showSnack('Please enter your name');
      return;
    }

    final auth = context.read<AuthProvider>();

    final ok = await auth.signUp(
      email: email,
      password: pass,
      name: name,
      role: _selectedRole,
    );

    if (ok && mounted) {
      _navigateAfterAuth();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _signInEmail.text.trim();

    if (email.isEmpty) {
      _showSnack('Enter your email to reset your password');
      return;
    }

    _showSnack('Password reset is not available yet (demo UI)');
  }

  void _socialLogin(String provider) {
    _showSnack('$provider login is UI-only in this demo');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Stack(
        children: [
          // Premium dark-glass overlay for the sign-in background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: AppColors.loginOverlay.withOpacity(0.35),
            ),
          ),

          SafeArea(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth =
                      constraints.maxWidth > 500 ? 500.0 : constraints.maxWidth;

                  return Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth > 450 ? 28 : 20,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween(begin: 0, end: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) {
                            final dy = (1 - t) * 20;
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, dy),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              // Header
                              Column(
                                children: [
                                  Text(
                                    'OmniMind',
                                    style: GoogleFonts.poppins(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      color: const Color.fromARGB(
                                          255, 69, 98, 118),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Your AI Mental Health Companion',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      color: const Color.fromARGB(255, 60, 87, 100)
                                          .withOpacity(0.8),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              _GlassCard(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: AppColors.loginGlassFill
                                            .withOpacity(0.18),
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border: Border.all(
                                          color: AppColors.loginGlassBorder
                                              .withOpacity(0.08),

                                        ),
                                      ),
                                      child: TabBar(
                                        controller: _tabs,
                                        indicator: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.secondary,
                                            ],
                                          ),
                                        ),
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        dividerColor: Colors.transparent,
                                        labelColor: Colors.white,
                                        unselectedLabelColor: Colors.white60,
                                        tabs: const [
                                          Tab(text: 'Sign In'),
                                          Tab(text: 'Create Account'),
                                        ],
                                        labelStyle: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 22),

                                    if (auth.error != null)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 14),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: AppColors.accent
                                                .withOpacity(0.35),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              color: AppColors.accent,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                auth.error!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.accent,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.close,
                                                color: AppColors.accent,
                                              ),
                                              onPressed: auth.clearError,
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Bounded height for TabBarView without collapsing on
                                    // very small screens / when keyboard opens.
                                    LayoutBuilder(
                                      builder: (context, tabConstraints) {
                                        final maxH = tabConstraints.maxHeight.isFinite
                                            ? tabConstraints.maxHeight
                                            : 520.0;

                                        final tabHeight = maxH.clamp(260.0, 560.0);

                                        return SizedBox(
                                          height: tabHeight,
                                          child: TabBarView(
                                            controller: _tabs,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            children: [
                                              _buildSignIn(auth),
                                              _buildSignUp(auth),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              Text(
                                'Secure • Private • HIPAA Compliant',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF7B90AE).withOpacity(0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignIn(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome Back',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color.fromARGB(255, 111, 111, 131),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Continue your wellness journey',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color.fromARGB(255, 111, 111, 132).withOpacity(0.75),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),

          _TextField(
            controller: _signInEmail,
            hintText: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 14),

          _TextField(
            controller: _signInPass,
            hintText: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signIn(),
            suffixIcon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
            suffixIconOnPressed: () {
              setState(() => _obscure = !_obscure);
            },
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _forgotPassword,
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(
                  color: const Color.fromARGB(255, 111, 111, 132).withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Spacer removed: TabBarView height can shrink on small devices and
          // keyboard open; scrolling will handle extra content without overflow.

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: auth.loading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                auth.loading ? '' : 'Sign In',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // teal offline button (FIX 1)
          Container(
            margin: const EdgeInsets.only(top: 0),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                      child: Divider(
                    color: Colors.white.withOpacity(0.15),
                  )),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                      child: Divider(
                    color: Colors.white.withOpacity(0.15),
                  )),
                ]),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OfflineAccessScreen(),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF00C9A7).withOpacity(0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.offline_bolt_rounded,
                          color: Color(0xFF00C9A7),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Access Offline Toolkit',
                          style: TextStyle(
                            color: Color(0xFF00C9A7),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No login required · Crisis resources always available',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),


        ],
      ),
    );
  }

  Widget _buildSignUp(AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create Account',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color.fromARGB(255, 111, 111, 130),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Join your AI wellness companion',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color.fromARGB(255, 111, 111, 133).withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),

          _TextField(
            controller: _signUpName,
            hintText: 'Full name',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 14),

          _TextField(
            controller: _signUpEmail,
            hintText: 'Email address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 14),

          _TextField(
            controller: _signUpPass,
            hintText: 'Password',
            icon: Icons.lock_outline,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signUp(),
            suffixIcon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            ),
            suffixIconOnPressed: () {
              setState(() => _obscure = !_obscure);
            },
          ),

          const SizedBox(height: 18),

          Text(
            'I am a',
            style: GoogleFonts.poppins(
              color: const Color.fromARGB(255, 111, 111, 133).withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _RoleChip(
                label: 'Patient',
                emoji: '🤍',
                selected: _selectedRole == UserRole.patient,
                onTap: () {
                  setState(() => _selectedRole = UserRole.patient);
                },
              ),
              _RoleChip(
                label: 'Doctor',
                emoji: '🧑‍⚕️',
                selected: _selectedRole == UserRole.doctor,
                onTap: () {
                  setState(() => _selectedRole = UserRole.doctor);
                },
              ),
            ],
          ),

          const Spacer(),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: auth.loading ? null : _signUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                auth.loading ? '' : 'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Reduce transparency for premium readability
            color: AppColors.loginGlassFill.withOpacity(0.28),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: AppColors.loginGlassBorder.withOpacity(0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.22),
                blurRadius: 34,
                spreadRadius: 1,
                offset: const Offset(0, 14),
              ),
              // soft cyan/teal glow
              BoxShadow(
                color: AppColors.secondary.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  static const double _hPad = 4;

  static const double _vPad = 0;
  const _TextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.suffixIcon,
    this.suffixIconOnPressed,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;
  final VoidCallback? suffixIconOnPressed;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.55)),
        prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.9)),
        suffixIcon: suffixIcon == null
            ? null
            : IconButton(
                onPressed: suffixIconOnPressed,
                icon: suffixIcon!,
                color: Colors.white,
              ),
        filled: true,
        fillColor: AppColors.lightSurface.withOpacity(0.18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.secondary,
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Text(
          '$emoji $label',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }
}

