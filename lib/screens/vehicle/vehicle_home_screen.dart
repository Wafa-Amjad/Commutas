import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../theme.dart';
import 'vehicle_history_screen.dart';

class VehicleHomeScreen extends StatefulWidget {
  final String vehicleName;
  final String vehicleRegNo;

  const VehicleHomeScreen({
    super.key,
    required this.vehicleName,
    required this.vehicleRegNo,
  });

  @override
  State<VehicleHomeScreen> createState() => _VehicleHomeScreenState();
}

class _VehicleHomeScreenState extends State<VehicleHomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _isGpsActive = true;
  bool _isBusActive = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double _calculateTotalFares() {
    return VehicleHistoryScreen.dummyTransactions
        .where((tx) => tx.status == 'SUCCESS')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  int _calculateTotalPassengers() {
    return VehicleHistoryScreen.dummyTransactions
        .where((tx) => tx.status == 'SUCCESS')
        .length;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning, Captain';
    if (hour < 17) return 'Good Afternoon, Captain';
    return 'Good Evening, Captain';
  }

  @override
  Widget build(BuildContext context) {
    final totalFares = _calculateTotalFares();
    final totalPassengers = _calculateTotalPassengers();

    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeaderCard(totalFares, totalPassengers),
            const SizedBox(height: 16),
            _buildStationAnimationCard(),
            _buildRoadDivider(),
            _buildStatusControls(),
            _buildRoadDivider(),
            _buildRoutesAndTimings(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      title: Row(
        children: [
          Image.asset(
            'assets/logo_theme_cropped.png',
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.directions_bus_rounded, color: CommutasColors.emeraldGreen, size: 24),
          ),
          const SizedBox(width: 8),
          Text(
            'COMMUTAS VEHICLE',
            style: CommutasTextStyles.labelBold.copyWith(fontSize: 14, letterSpacing: 1),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: CommutasColors.primaryNavy),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeaderCard(double totalFares, int totalPassengers) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: CommutasColors.primaryNavy,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.vehicleName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Reg No: ${widget.vehicleRegNo}',
                      style: GoogleFonts.inter(
                        color: CommutasColors.emeraldGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isBusActive = !_isBusActive;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isBusActive ? CommutasColors.emeraldGreen.withOpacity(0.15) : Colors.white10,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: _isBusActive ? CommutasColors.emeraldGreen : Colors.white30,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isBusActive ? CommutasColors.success : Colors.white30,
                          shape: BoxShape.rectangle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isBusActive ? 'ON DUTY' : 'OFF DUTY',
                        style: TextStyle(
                          color: _isBusActive ? CommutasColors.emeraldGreen : Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Fares',
                      style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rs. ${totalFares.toStringAsFixed(2)}',
                      style: CommutasTextStyles.heading2.copyWith(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.2),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Passengers',
                      style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white60),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalPassengers Taps',
                      style: CommutasTextStyles.heading2.copyWith(color: Colors.white, fontSize: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStationAnimationCard() {
    return Container(
      height: 140,
      decoration: CommutasShapes.cardDecoration,
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // 1. Station background grid
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _StationBackgroundPainter(animationValue: _animationController.value),
                );
              },
            ),
          ),

          // 2. Interactive Bus and Boarding Passengers
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      painter: _StationActivityPainter(
                        animationValue: _animationController.value,
                        isGpsActive: _isGpsActive,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 3. Foreground details
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.90),
                    Colors.white.withOpacity(0.20),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NFC GATEWAY ACTIVE',
                        style: CommutasTextStyles.labelBold.copyWith(
                          color: CommutasColors.primaryNavy,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Awaiting student contactless taps',
                        style: CommutasTextStyles.bodySmall.copyWith(
                          color: CommutasColors.slateMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: CommutasColors.primaryNavy,
                        child: const Row(
                          children: [
                            Icon(Icons.nfc_rounded, color: CommutasColors.emeraldGreen, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'HCE READER READY',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
        ],
      ),
    );
  }

  Widget _buildRoadDivider() {
    return const SizedBox(
      height: 24,
      width: double.infinity,
      child: CustomPaint(
        painter: _RoadDividerPainter(),
      ),
    );
  }

  Widget _buildStatusControls() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: CommutasShapes.cardDecoration,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: _isGpsActive ? CommutasColors.lightGreenBg : CommutasColors.slateMuted.withOpacity(0.1),
                      child: Icon(
                        Icons.gps_fixed_rounded,
                        color: _isGpsActive ? CommutasColors.emeraldGreen : CommutasColors.slateMuted,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GPS Tracking',
                          style: CommutasTextStyles.labelBold.copyWith(fontSize: 12),
                        ),
                        Text(
                          _isGpsActive ? 'Broadcasting location' : 'GPS Disconnected',
                          style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: _isGpsActive,
                  onChanged: (val) {
                    setState(() {
                      _isGpsActive = val;
                    });
                  },
                  activeColor: CommutasColors.emeraldGreen,
                  activeTrackColor: CommutasColors.lightGreenBg,
                  inactiveThumbColor: CommutasColors.slateMuted,
                  inactiveTrackColor: Colors.grey[200],
                  trackOutlineColor: MaterialStateProperty.resolveWith((states) => Colors.transparent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoutesAndTimings() {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Bus Routes & Timings',
              style: CommutasTextStyles.heading2.copyWith(fontSize: 16),
            ),
          ),
          TabBar(
            indicatorColor: CommutasColors.emeraldGreen,
            labelColor: CommutasColors.emeraldGreen,
            unselectedLabelColor: CommutasColors.primaryNavy.withOpacity(0.5),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Morning Sessions'),
              Tab(text: 'Evening Sessions'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: TabBarView(
              children: [
                ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildRouteTimingCard('Route 01', 'Main Campus → PMA Road → Dhamtor Campus', '08:00 AM - 08:40 AM'),
                    const SizedBox(height: 12),
                    _buildRouteTimingCard('Route 02', 'Main Campus → Fawara Chowk → Dhamtor Campus', '08:00 AM - 08:40 AM'),
                    const SizedBox(height: 12),
                    _buildRouteTimingCard('Route 03', 'Main Campus → Murree Road → Dhamtor Campus', '08:00 AM - 08:40 AM'),
                  ],
                ),
                ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildRouteTimingCard('Route 01', 'Dhamtor Campus → PMA Road → Main Campus', '01:30 PM - 02:10 PM'),
                    const SizedBox(height: 12),
                    _buildRouteTimingCard('Route 02', 'Dhamtor Campus → Fawara Chowk → Main Campus', '04:30 PM - 05:10 PM'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimingCard(String route, String path, String timing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CommutasShapes.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: CommutasColors.primaryNavy,
            child: Text(
              route,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  path,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: CommutasColors.primaryNavy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timing,
                  style: const TextStyle(color: CommutasColors.slateMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: CommutasColors.lineBorder),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Station Background Grid Painter (Isometric perspective)
// ──────────────────────────────────────────────────────────
class _StationBackgroundPainter extends CustomPainter {
  final double animationValue;

  _StationBackgroundPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double horizonY = size.height * 0.5;
    final double centerX = size.width / 2;

    // Background sky color
    final skyPaint = Paint()..color = Colors.grey[50]!;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizonY), skyPaint);

    // Platform ground color
    final groundPaint = Paint()..color = Colors.grey[100]!;
    canvas.drawRect(Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY), groundPaint);

    // Grid lines for perspective
    final gridPaint = Paint()
      ..color = CommutasColors.lineBorder.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Horizon line
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), gridPaint);

    // Radiating floor lines
    const int linesCount = 10;
    for (int i = 0; i <= linesCount; i++) {
      final double x = (i / linesCount) * size.width;
      canvas.drawLine(
        Offset(x, horizonY),
        Offset(centerX + (x - centerX) * 2.5, size.height),
        gridPaint,
      );
    }

    // Moving platform lines
    const int horizLines = 4;
    for (int i = 0; i < horizLines; i++) {
      final double progress = (i + (animationValue * 0.2)) / horizLines;
      final double y = horizonY + (size.height - horizonY) * progress;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StationBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// ──────────────────────────────────────────────────────────
// Station Activity Painter (Bus parked & Passengers Boarding)
// ──────────────────────────────────────────────────────────
class _StationActivityPainter extends CustomPainter {
  final double animationValue;
  final bool isGpsActive;

  _StationActivityPainter({required this.animationValue, required this.isGpsActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.primaryNavy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = CommutasColors.primaryNavy
      ..style = PaintingStyle.fill;

    // 1. Draw Parked Bus (Centered, facing left)
    final double busWidth = 120;
    final double busHeight = 54;
    final double busLeft = size.width * 0.45;
    final double busTop = size.height * 0.38;
    final double busBottom = busTop + busHeight;

    // Bounce effect for engine idling
    final double idleBounce = math.sin(animationValue * 6 * math.pi) * 0.6;
    final double activeBusTop = busTop + idleBounce;
    final double activeBusBottom = busBottom + idleBounce;

    // Bus body outline
    canvas.drawRect(Rect.fromLTRB(busLeft, activeBusTop, busLeft + busWidth, activeBusBottom), paint);

    // Front windshield (left side since it faces left)
    canvas.drawRect(Rect.fromLTWH(busLeft + 6, activeBusTop + 6, 18, 16), paint);

    // Passenger windows
    for (int i = 0; i < 3; i++) {
      final double wx = busLeft + 32.0 + (i * 24.0);
      canvas.drawRect(Rect.fromLTWH(wx, activeBusTop + 6, 16, 14), paint);
    }

    // Bus door (Open for boarding)
    final doorPaint = Paint()
      ..color = CommutasColors.emeraldGreen.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final doorOutline = Paint()
      ..color = CommutasColors.emeraldGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final double doorLeft = busLeft + 104;
    canvas.drawRect(Rect.fromLTRB(doorLeft, activeBusTop + 12, doorLeft + 12, activeBusBottom), doorPaint);
    canvas.drawRect(Rect.fromLTRB(doorLeft, activeBusTop + 12, doorLeft + 12, activeBusBottom), doorOutline);

    // Wheels (Static but with engine idle vibration)
    final double wheelY = activeBusBottom + 6;
    canvas.drawCircle(Offset(busLeft + 24, wheelY), 7, fillPaint);
    canvas.drawCircle(Offset(busLeft + 24, wheelY), 7, paint);
    canvas.drawCircle(Offset(busLeft + 90, wheelY), 7, fillPaint);
    canvas.drawCircle(Offset(busLeft + 90, wheelY), 7, paint);

    // 2. Draw Boarding Passengers
    for (int i = 0; i < 3; i++) {
      final double passengerProgress = (animationValue + (i * 0.33)) % 1.0;
      
      final double startX = size.width - 20;
      final double endX = doorLeft + 6;
      final double passengerX = startX + (endX - startX) * passengerProgress;
      
      if (passengerX > endX) {
        final double passengerY = activeBusBottom + 4 + (math.sin(passengerProgress * 15 * math.pi) * 1.5);
        
        // Head
        canvas.drawCircle(Offset(passengerX, passengerY - 14), 3.5, fillPaint);
        // Body
        canvas.drawLine(Offset(passengerX, passengerY - 10), Offset(passengerX, passengerY), paint);
        // Arms
        canvas.drawLine(Offset(passengerX - 2, passengerY - 8), Offset(passengerX + 2, passengerY - 4), paint);
        // Legs
        canvas.drawLine(Offset(passengerX, passengerY), Offset(passengerX - 2, passengerY + 6), paint);
        canvas.drawLine(Offset(passengerX, passengerY), Offset(passengerX + 2, passengerY + 6), paint);

        // Active Phone NFC Wave
        if (i == 0 && passengerProgress > 0.75) {
          final nfcWavePaint = Paint()
            ..color = CommutasColors.emeraldGreen.withOpacity(1.0 - ((passengerProgress - 0.75) * 4))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(Offset(passengerX - 4, passengerY - 8), 3 + (passengerProgress - 0.75) * 20, nfcWavePaint);
        }
      }
    }

    // 3. NFC Reader Pulse on the bus (near the door)
    final double nfcPulseVal = (animationValue * 2) % 1.0;
    final nfcPulsePaint = Paint()
      ..color = CommutasColors.emeraldGreen.withOpacity(0.3 * (1.0 - nfcPulseVal))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(doorLeft + 6, activeBusTop + 18), 4 + (nfcPulseVal * 18), nfcPulsePaint);

    // 4. GPS pulse
    if (isGpsActive) {
      final double gpsPulseVal = (animationValue * 1.5) % 1.0;
      final gpsPulsePaint = Paint()
        ..color = CommutasColors.emeraldGreen.withOpacity(0.4 * (1.0 - gpsPulseVal))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(busLeft + 16, activeBusTop - 4), 2 + (gpsPulseVal * 12), gpsPulsePaint);
      
      final gpsAntennaPaint = Paint()
        ..color = CommutasColors.emeraldGreen
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(busLeft + 16, activeBusTop - 4), 2.5, gpsAntennaPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StationActivityPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.isGpsActive != isGpsActive;
  }
}

// ──────────────────────────────────────────────────────────
// Sketchy road divider painter
// ──────────────────────────────────────────────────────────
class _RoadDividerPainter extends CustomPainter {
  const _RoadDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.lineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final double y = size.height / 2;
    const double dashWidth = 14.0;
    const double gapWidth = 10.0;
    double x = 0;

    while (x < size.width) {
      final double wobble = math.sin(x * 0.3) * 0.8;
      canvas.drawLine(
        Offset(x, y + wobble),
        Offset(math.min(x + dashWidth, size.width), y - wobble),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadDividerPainter oldDelegate) => false;
}
