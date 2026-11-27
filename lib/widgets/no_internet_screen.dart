import 'package:flutter/material.dart';

import '../screens/services/connectivity_service.dart';
import '../theme.dart';
import 'offline_banner.dart';

class NoInternetScreen extends StatelessWidget {
  final Future<void> Function()? onRetry;

  const NoInternetScreen({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final service = ConnectivityService.instance;

    return ColoredBox(
      color: CommutasColors.backgroundGray,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const OfflineBanner(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 240,
                      height: 190,
                      child: CustomPaint(painter: _OfflineTransitPainter()),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'No internet connection',
                      textAlign: TextAlign.center,
                      style: CommutasTextStyles.heading1.copyWith(
                        color: CommutasColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: CommutasTextStyles.bodyMedium.copyWith(
                        color: CommutasColors.slateMuted,
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 52,
                      width: 180,
                      child: ElevatedButton(
                        onPressed: service.isChecking
                            ? null
                            : () async {
                                if (onRetry != null) {
                                  await onRetry!();
                                } else {
                                  await service.checkNow();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CommutasColors.primaryNavy,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              CommutasColors.primaryNavy.withOpacity(0.45),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          elevation: 0,
                        ),
                        child: service.isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Retry',
                                style: CommutasTextStyles.buttonLabel,
                              ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      "We'll reconnect automatically when you're back online.",
                      textAlign: TextAlign.center,
                      style: CommutasTextStyles.bodySmall.copyWith(
                        color: CommutasColors.slateMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineTransitPainter extends CustomPainter {
  const _OfflineTransitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final navy = Paint()
      ..color = CommutasColors.primaryNavy
      ..style = PaintingStyle.fill;
    final green = Paint()
      ..color = CommutasColors.emeraldGreen
      ..style = PaintingStyle.fill;
    final sage = Paint()
      ..color = CommutasColors.sageGreen
      ..style = PaintingStyle.fill;
    final red = Paint()
      ..color = CommutasColors.danger
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final outline = Paint()
      ..color = CommutasColors.primaryNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final bus = Rect.fromLTWH(18, 66, 142, 72);
    canvas.drawRect(bus, navy);
    canvas.drawRect(Rect.fromLTWH(18, 116, 142, 22), green);
    canvas.drawRect(Rect.fromLTWH(32, 78, 38, 22), sage);
    canvas.drawRect(Rect.fromLTWH(78, 78, 38, 22), sage);
    canvas.drawCircle(const Offset(50, 144), 11, navy);
    canvas.drawCircle(const Offset(128, 144), 11, navy);
    canvas.drawRect(Rect.fromLTWH(28, 58, 122, 8), green);
    canvas.drawLine(const Offset(170, 46), const Offset(170, 153), outline);
    canvas.drawLine(const Offset(166, 153), const Offset(188, 153), outline);

    final phone = RRect.fromRectAndRadius(
      const Rect.fromLTWH(174, 66, 48, 78),
      const Radius.circular(4),
    );
    canvas.drawRRect(phone, outline);
    canvas.drawCircle(const Offset(198, 132), 2, navy);
    canvas.drawArc(
      Rect.fromLTWH(184, 83, 28, 22),
      3.35,
      2.0,
      false,
      outline,
    );
    canvas.drawArc(
      Rect.fromLTWH(190, 91, 16, 12),
      3.35,
      2.0,
      false,
      outline,
    );
    canvas.drawLine(const Offset(181, 76), const Offset(215, 113), red);

    canvas.drawLine(const Offset(12, 166), const Offset(224, 166), outline);
    canvas.drawLine(const Offset(20, 176), const Offset(215, 176), outline);
  }

  @override
  bool shouldRepaint(covariant _OfflineTransitPainter oldDelegate) => false;
}
