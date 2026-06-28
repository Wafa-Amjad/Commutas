import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'login_signup_screen.dart';
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    Timer(const Duration(milliseconds: 2500), _navigateToNextScreen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final isSessionActive = prefs.getBool('session_active') ?? false;

    if (isSessionActive && mounted) {
      final name = prefs.getString('session_name') ?? '';
      final regNo = prefs.getString('session_reg_no') ?? '';
      final role = prefs.getString('session_role') ?? 'student';
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MainScreen(
            studentName: name,
            studentRegNo: regNo,
            role: role,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const LoginSignupScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo_theme_transparent.png',
                height: 160,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16.0),
              Text(
                'Your ticket to a smarter commute.',
                style: CommutasTextStyles.sectionEyebrow.copyWith(
                  color: CommutasColors.slateMuted,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 80.0),
              const _ThreeDotLoader(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreeDotLoader extends StatefulWidget {
  const _ThreeDotLoader();

  @override
  State<_ThreeDotLoader> createState() => _ThreeDotLoaderState();
}

class _ThreeDotLoaderState extends State<_ThreeDotLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final double value = math.sin((_controller.value * 2 * math.pi) - (index * math.pi / 3));
            final double translation = (value + 1.0) * 3.5;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              transform: Matrix4.translationValues(0.0, -translation, 0.0),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: CommutasColors.accentCobalt,
                shape: BoxShape.rectangle,
              ),
            );
          }),
        );
      },
    );
  }
}
