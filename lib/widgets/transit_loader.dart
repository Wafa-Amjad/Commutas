import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class TransitLoader extends StatefulWidget {
  const TransitLoader({super.key});

  @override
  State<TransitLoader> createState() => _TransitLoaderState();
}

class _TransitLoaderState extends State<TransitLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Timer _statusTimer;
  int _statusIndex = 0;

  final List<String> _statuses = [
    'Connecting to COMSATS Portal...',
    'Authenticating credentials...',
    'Verifying enrollment status...',
    'Syncing academic records...',
    'Generating application token...',
    'Finalizing secure environment...'
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (mounted) {
        setState(() {
          _statusIndex = (_statusIndex + 1) % _statuses.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _statusTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: CommutasColors.white,
          border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mature stylized card icon
            Center(
              child: SizedBox(
                width: 80,
                height: 52,
                child: CustomPaint(
                  painter: _MinimalCardPainter(pulse: _controller.value),
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            
            // Serious Section Eyebrow
            Text(
              'SECURE VERIFICATION',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: CommutasColors.accentCobalt,
              ),
            ),
            const SizedBox(height: 12.0),
            
            // Linear Progress Indicator - Zero Radius
            Container(
              height: 4,
              color: CommutasColors.surface,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.3 + 0.7 * _controller.value,
                    child: Container(
                      color: CommutasColors.navyInk,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Animated Status Msg
            SizedBox(
              height: 36,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statuses[_statusIndex],
                  key: ValueKey<String>(_statuses[_statusIndex]),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: CommutasColors.slateMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalCardPainter extends CustomPainter {
  final double pulse;

  _MinimalCardPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = CommutasColors.navyInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Zero corner radius rect
    final cardRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(cardRect, borderPaint);

    // Minimal chip outline
    final chipPaint = Paint()
      ..color = CommutasColors.lineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final chipRect = Rect.fromLTWH(8, 16, 16, 12);
    canvas.drawRect(chipRect, chipPaint);

    // Minimal signature/mag strip line
    final stripPaint = Paint()
      ..color = CommutasColors.lineBorder
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(32, 22), Offset(size.width - 8, 22), stripPaint);
    canvas.drawLine(Offset(32, 28), Offset(size.width - 16, 28), stripPaint);

    // Subtle pulsing network connection indicator (abstract concentric line)
    final beaconPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double maxRadius = 24.0;
    final double radius = 2.0 + (pulse * maxRadius);
    final double opacity = (1.0 - pulse).clamp(0.0, 1.0);
    
    beaconPaint.color = CommutasColors.accentCobalt.withValues(alpha: opacity * 0.4);
    canvas.drawCircle(Offset(size.width - 16, 16), radius, beaconPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalCardPainter oldDelegate) {
    return oldDelegate.pulse != pulse;
  }
}
