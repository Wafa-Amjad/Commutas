import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import '../theme.dart';
import '../screens/services/auth_service.dart';

class VerificationScreen extends StatefulWidget {
  final String regNo;
  final String portalPassword;
  final String appPassword;

  const VerificationScreen({
    super.key,
    required this.regNo,
    required this.portalPassword,
    required this.appPassword,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  
  // Progress & Bus control
  late final AnimationController _progressController;
  late final AnimationController _busController;
  
  int _activeStep = 0;
  bool _isSuccess = false;
  String? _apiError;

  // Verification steps
  final List<String> _steps = [
    'Connecting to Commutas transit server...',
    'Verifying student academic enrollment...',
    'Authenticating registration credentials...',
    'Configuring transit wallet credentials...',
    'Generating secure application access keys...',
    'Registration completed successfully.'
  ];

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // Average verification time
    )..forward();

    _busController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Start registration API call
    _runRegistration();

    // Simulate step progression animations
    _animateSteps();
  }

  void _animateSteps() async {
    for (int i = 0; i < _steps.length - 1; i++) {
      if (!mounted || _isSuccess || _apiError != null) break;
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted && !_isSuccess && _apiError == null) {
        setState(() {
          _activeStep = i + 1;
        });
      }
    }
  }

  Future<void> _runRegistration() async {
    try {
      final response = await _authService.registerStudent(
        regNo: widget.regNo,
        portalPassword: widget.portalPassword,
        appPassword: widget.appPassword,
      );

      if (response != null && mounted) {
        setState(() {
          _isSuccess = true;
          _activeStep = _steps.length - 1; // Highlight final success step
        });
        
        // Let user see the completed successful screen
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) {
          Navigator.pop(context, true); // Returns success to LoginScreen
        }
      } else {
        throw Exception("Registration failed. Invalid response from server.");
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = "Registration failed. Check network or credentials.";
        if (e is DioException) {
          final detail = e.response?.data?['detail'];
          if (detail != null) {
            errorMsg = detail.toString();
          } else if (e.message != null) {
            errorMsg = e.message!;
          }
        } else {
          errorMsg = e.toString();
        }
        
        setState(() {
          _apiError = errorMsg;
        });

        // Delay returning so user can read the error state details
        await Future.delayed(const Duration(milliseconds: 2500));
        if (mounted) {
          Navigator.pop(context, errorMsg); // Return error message
        }
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _busController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Branding Header
                Center(
                  child: Image.asset(
                    'assets/logo_theme_cropped.png',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32.0),

                // Main stand-alone card
                Container(
                  decoration: BoxDecoration(
                    color: CommutasColors.white,
                    border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'STUDENT ENROLLMENT VERIFICATION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: CommutasColors.accentCobalt,
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      // Step sequence with custom slide+fade text transitions
                      for (int i = 0; i < _steps.length; i++)
                        if (i <= _activeStep)
                          _buildStepRow(i),

                      const SizedBox(height: 24.0),

                      // Full-width linear progress bar - zero radius
                      Container(
                        height: 4,
                        color: CommutasColors.surface,
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            double value = _progressController.value;
                            if (_isSuccess) value = 1.0;
                            if (_apiError != null) value = 1.0;
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: value,
                              child: Container(
                                color: _apiError != null 
                                    ? CommutasColors.danger 
                                    : (_isSuccess ? CommutasColors.success : CommutasColors.accentCobalt),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32.0),

                // Bottom Animated Handdrawn Bus
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 80,
                    child: AnimatedBuilder(
                      animation: _busController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _HanddrawnBusPainter(
                            animationValue: _busController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int index) {
    final isPending = index == _activeStep && !_isSuccess && _apiError == null;
    final isCompleted = index < _activeStep || _isSuccess;
    final isError = _apiError != null && index == _activeStep;

    Widget iconWidget = const SizedBox(
      height: 16,
      width: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.slateMuted),
      ),
    );

    if (isCompleted) {
      iconWidget = const Icon(Icons.check, color: CommutasColors.success, size: 16);
    } else if (isError) {
      iconWidget = const Icon(Icons.close, color: CommutasColors.danger, size: 16);
    } else if (isPending) {
      iconWidget = const SizedBox(
        height: 14,
        width: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.accentCobalt),
        ),
      );
    }

    String renderedStepText = _steps[index];
    if (isError && _apiError != null) {
      renderedStepText = 'Error: $_apiError';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(24.0 * (1.0 - value), 0.0), // slide in from right
              child: child,
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: iconWidget,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                renderedStepText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isPending ? FontWeight.bold : FontWeight.normal,
                  color: isError 
                      ? CommutasColors.danger 
                      : (isPending ? CommutasColors.accentCobalt : CommutasColors.inkText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HanddrawnBusPainter extends CustomPainter {
  final double animationValue;

  _HanddrawnBusPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.navyInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bounce = math.sin(animationValue * 2 * math.pi) * 2.0;

    final double top = 10.0 + bounce;
    final double bottom = size.height - 20.0 + bounce;
    final double left = 10.0;
    final double right = size.width - 10.0;

    // Body lines
    canvas.drawLine(Offset(left, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);

    // Front windshield
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 24, top + 6), paint);
    canvas.drawLine(Offset(left + 24, top + 6), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 18), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 8, top + 18), paint);

    // Windows
    for (int i = 0; i < 3; i++) {
      final double wx = left + 32.0 + i * 20.0;
      canvas.drawRect(Rect.fromLTWH(wx, top + 6, 14, 12), paint);
    }

    // Sketchy headlights (faint light rays)
    canvas.drawLine(Offset(left, bottom - 10), Offset(left - 4, bottom - 10), paint);
    final rayPaint = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 14), rayPaint);
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 6), rayPaint);

    // Bumper
    canvas.drawLine(Offset(left - 4, bottom - 2), Offset(left + 4, bottom - 2), paint);
    canvas.drawLine(Offset(right - 4, bottom - 2), Offset(right + 4, bottom - 2), paint);

    // Wheels
    final double wheelRadius = 8.0;
    final double leftWheelX = left + 20.0;
    final double rightWheelX = right - 20.0;
    final double wheelY = bottom + 8.0 - bounce;

    // Wheel 1
    canvas.drawCircle(Offset(leftWheelX, wheelY), wheelRadius, paint);
    final angle = animationValue * 2 * math.pi;
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      paint,
    );
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      paint,
    );

    // Wheel 2
    canvas.drawCircle(Offset(rightWheelX, wheelY), wheelRadius, paint);
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      paint,
    );
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HanddrawnBusPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
