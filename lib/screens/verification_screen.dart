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
  final bool isReset;

  const VerificationScreen({
    super.key,
    required this.regNo,
    required this.portalPassword,
    required this.appPassword,
    this.isReset = false,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  
  // Progress & Bus control
  late final AnimationController _progressController;
  late final AnimationController _busController;
  
  bool _isSuccess = false;
  String? _apiError;

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
  }

  Future<void> _runRegistration() async {
    try {
      final Map<String, dynamic>? response;
      if (widget.isReset) {
        response = await _authService.resetPassword(
          regNo: widget.regNo,
          portalPassword: widget.portalPassword,
          newPassword: widget.appPassword,
        );
      } else {
        response = await _authService.registerStudent(
          regNo: widget.regNo,
          portalPassword: widget.portalPassword,
          appPassword: widget.appPassword,
        );
      }

      if (response != null && mounted) {
        setState(() {
          _isSuccess = true;
        });
      } else {
        throw Exception(widget.isReset 
            ? "Password reset failed. Invalid response from server."
            : "Registration failed. Invalid response from server.");
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = widget.isReset
            ? "Password reset failed. Check network or credentials."
            : "Registration failed. Check network or credentials.";
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
      backgroundColor: CommutasColors.background,
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
                    borderRadius: BorderRadius.zero,
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.isReset ? 'PASSWORD RESET VERIFICATION' : 'STUDENT ENROLLMENT VERIFICATION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: CommutasColors.accentCobalt,
                        ),
                      ),
                      const SizedBox(height: 24.0),

                      // Single status message with slide and fade transitions
                      _buildStatusRow(),

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

                      // "PROCEED TO SIGN IN" button on success
                      if (_isSuccess) ...[
                        const SizedBox(height: 24.0),
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: CommutasColors.primaryNavy,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            child: Text(
                              'PROCEED TO SIGN IN',
                              style: CommutasTextStyles.buttonLabel,
                            ),
                          ),
                        ),
                      ],

                      // "RETURN TO FORM" button on error
                      if (_apiError != null) ...[
                        const SizedBox(height: 24.0),
                        SizedBox(
                          height: 48,
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: CommutasColors.primaryNavy,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: () {
                              Navigator.pop(context, _apiError);
                            },
                            child: Text(
                              'RETURN TO FORM',
                              style: CommutasTextStyles.buttonLabel,
                            ),
                          ),
                        ),
                      ],
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
                            isCrashed: _apiError != null,
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

  Widget _buildStatusRow() {
    final bool isError = _apiError != null;
    final bool isCompleted = _isSuccess;
    final bool isProcessing = !isError && !isCompleted;

    Widget iconWidget;
    String text;
    Color textColor;

    if (isCompleted) {
      iconWidget = const Icon(Icons.check, color: CommutasColors.success, size: 18);
      text = widget.isReset 
          ? "Transit account secured!"
          : "Transit account setup complete!";
      textColor = CommutasColors.success;
    } else if (isError) {
      iconWidget = const Icon(Icons.close, color: CommutasColors.danger, size: 18);
      text = 'Error: $_apiError';
      textColor = CommutasColors.danger;
    } else {
      iconWidget = const SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.accentCobalt),
        ),
      );
      text = widget.isReset
          ? "Securing your transit account..."
          : "Setting up your transit account...";
      textColor = CommutasColors.inkText;
    }

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('status_${isCompleted ? 'success' : (isError ? 'error' : 'processing')}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 8.0 * (1.0 - value)),
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
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isProcessing ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HanddrawnBusPainter extends CustomPainter {
  final double animationValue;
  final bool isCrashed;

  _HanddrawnBusPainter({
    required this.animationValue,
    required this.isCrashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.navyInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (isCrashed) {
      canvas.save();
      // Rotate around the center of the canvas
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(-0.08); // More explicit tilt
      canvas.translate(-size.width / 2, -size.height / 2);
    }

    final bounce = isCrashed ? 0.0 : math.sin(animationValue * 2 * math.pi) * 2.0;

    final double top = 10.0 + bounce;
    final double bottom = size.height - 20.0 + bounce;
    final double left = 10.0;
    final double right = size.width - 10.0;

    // Body lines (jagged crumbled line for front bumper side on impact)
    canvas.drawLine(Offset(left, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
    if (isCrashed) {
      // Draw crumbled front edge line
      final path = Path()
        ..moveTo(left, top)
        ..lineTo(left + 2, top + 8)
        ..lineTo(left - 3, top + 15)
        ..lineTo(left + 1, top + 22)
        ..lineTo(left - 2, top + 30)
        ..lineTo(left + 3, bottom - 10)
        ..lineTo(left, bottom);
      canvas.drawPath(path, paint);
    } else {
      canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
    }

    // Front windshield
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 24, top + 6), paint);
    canvas.drawLine(Offset(left + 24, top + 6), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 18), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 8, top + 18), paint);

    // Windshield cracks on crash
    if (isCrashed) {
      final crackPaint = Paint()
        ..color = CommutasColors.navyInk.withValues(alpha: 0.7)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(left + 8, top + 18), Offset(left + 15, top + 11), crackPaint);
      canvas.drawLine(Offset(left + 15, top + 11), Offset(left + 21, top + 15), crackPaint);
      canvas.drawLine(Offset(left + 15, top + 11), Offset(left + 11, top + 7), crackPaint);
    }

    // Windows
    for (int i = 0; i < 3; i++) {
      final double wx = left + 32.0 + i * 20.0;
      canvas.drawRect(Rect.fromLTWH(wx, top + 6, 14, 12), paint);
    }

    // Sketchy headlights (faint light rays or broken cracks)
    if (!isCrashed) {
      canvas.drawLine(Offset(left, bottom - 10), Offset(left - 4, bottom - 10), paint);
      final rayPaint = Paint()
        ..color = Colors.orangeAccent.withValues(alpha: 0.8)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 14), rayPaint);
      canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 6), rayPaint);
    } else {
      // Cracked headlight lines
      canvas.drawLine(Offset(left, bottom - 12), Offset(left - 3, bottom - 8), paint);
      canvas.drawLine(Offset(left - 3, bottom - 8), Offset(left, bottom - 4), paint);
    }

    // Bumper
    canvas.drawLine(Offset(left - 4, bottom - 2), Offset(left + 4, bottom - 2), paint);
    canvas.drawLine(Offset(right - 4, bottom - 2), Offset(right + 4, bottom - 2), paint);

    // Wheels (Front wheel is broken/detached and tilted on crash)
    final double wheelRadius = 8.0;
    final double leftWheelX = left + 20.0;
    final double rightWheelX = right - 20.0;
    final double wheelY = bottom + 8.0 - bounce;

    final double currentLeftWheelX = isCrashed ? leftWheelX - 4.0 : leftWheelX;
    final double currentLeftWheelY = isCrashed ? wheelY - 3.0 : wheelY;

    // Wheel 1 (Front - offset and broken)
    canvas.drawCircle(Offset(currentLeftWheelX, currentLeftWheelY), wheelRadius, paint);
    final angle = isCrashed ? -0.6 : animationValue * 2 * math.pi;
    canvas.drawLine(
      Offset(currentLeftWheelX, currentLeftWheelY),
      Offset(currentLeftWheelX + wheelRadius * math.cos(angle), currentLeftWheelY + wheelRadius * math.sin(angle)),
      paint,
    );
    canvas.drawLine(
      Offset(currentLeftWheelX, currentLeftWheelY),
      Offset(currentLeftWheelX + wheelRadius * math.cos(angle + math.pi), currentLeftWheelY + wheelRadius * math.sin(angle + math.pi)),
      paint,
    );

    // Wheel 2 (Rear)
    canvas.drawCircle(Offset(rightWheelX, wheelY), wheelRadius, paint);
    final angleRear = isCrashed ? 0.4 : animationValue * 2 * math.pi;
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angleRear), wheelY + wheelRadius * math.sin(angleRear)),
      paint,
    );
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angleRear + math.pi), wheelY + wheelRadius * math.sin(angleRear + math.pi)),
      paint,
    );

    if (isCrashed) {
      // 1. Sketchy impact sparks radiating from front bumper (left side)
      final sparkPaint = Paint()
        ..color = Colors.orangeAccent
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final double sx = left - 4;
      final double sy = bottom - 2;

      // Spark length animated to flicker
      final double sparkLen = 10.0 + math.sin(animationValue * 4 * math.pi) * 4.0;

      canvas.drawLine(Offset(sx, sy), Offset(sx - sparkLen, sy - sparkLen * 0.4), sparkPaint);
      canvas.drawLine(Offset(sx, sy), Offset(sx - sparkLen * 1.3, sy + sparkLen * 0.1), sparkPaint);
      canvas.drawLine(Offset(sx, sy), Offset(sx - sparkLen * 0.8, sy + sparkLen * 0.7), sparkPaint);
      canvas.drawLine(Offset(sx, sy), Offset(sx - sparkLen * 0.5, sy - sparkLen * 0.8), sparkPaint);

      // 2. Animated translucent rising and expanding smoke puffs (left side hood)
      final smokePaint = Paint()
        ..color = CommutasColors.slateMuted.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      final smokeOutline = Paint()
        ..color = CommutasColors.slateMuted.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final double hx = left + 14;
      final double hy = top;

      // Puff 1
      final double p1Y = hy - 14.0 - (animationValue * 16.0);
      final double p1X = hx - 4.0 + math.sin(animationValue * 2 * math.pi) * 3.0;
      final double p1Radius = 6.0 + (animationValue * 4.0);
      canvas.drawCircle(Offset(p1X, p1Y), p1Radius, smokePaint);
      canvas.drawCircle(Offset(p1X, p1Y), p1Radius, smokeOutline);

      // Puff 2
      final double p2Val = (animationValue + 0.5) % 1.0;
      final double p2Y = hy - 14.0 - (p2Val * 20.0);
      final double p2X = hx + 8.0 + math.cos(p2Val * 2 * math.pi) * 4.0;
      final double p2Radius = 5.0 + (p2Val * 5.0);
      canvas.drawCircle(Offset(p2X, p2Y), p2Radius, smokePaint);
      canvas.drawCircle(Offset(p2X, p2Y), p2Radius, smokeOutline);
    }

    if (isCrashed) {
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HanddrawnBusPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isCrashed != isCrashed;
  }
}
