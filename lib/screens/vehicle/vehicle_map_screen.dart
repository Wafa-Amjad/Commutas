import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../theme.dart';

class VehicleMapScreen extends StatefulWidget {
  const VehicleMapScreen({super.key});

  @override
  State<VehicleMapScreen> createState() => _VehicleMapScreenState();
}

class _VehicleMapScreenState extends State<VehicleMapScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _navController;
  bool _isNavigating = false;
  String _activeRoute = 'Route 03 - City Center';
  
  // List of dynamic routes that the admin can assign
  final List<String> _availableRoutes = [
    'Route 03 - City Center',
    'Route 01 - Mandian & Supply',
    'Route 05 - Pine Hills & Hostel',
    'Route 02 - Abbottabad Bypass',
  ];

  // Turn-by-turn navigation instructions
  final List<String> _instructions = [
    'Head South on University Road toward Main Gate',
    'In 500m, turn left onto Karakoram Highway',
    'Continue straight past Mandian Chowk (2.1 km)',
    'In 800m, keep right at Supply Junction',
    'Arrive at City Center Terminal on the left',
  ];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );

    _navController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _toggleNavigation() {
    if (_isNavigating) {
      _navController.stop();
      _navController.reset();
      setState(() {
        _isNavigating = false;
      });
    } else {
      setState(() {
        _isNavigating = true;
      });
      _navController.forward(from: 0.0).then((_) {
        setState(() {
          _isNavigating = false;
        });
      });
    }
  }

  // Opens external Google Maps with COMSATS Abbottabad coordinates
  Future<void> _launchExternalMap() async {
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=34.1912,73.2418');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch external maps.')),
        );
      }
    }
  }

  void _cycleRoute() {
    final currentIndex = _availableRoutes.indexOf(_activeRoute);
    final nextIndex = (currentIndex + 1) % _availableRoutes.length;
    setState(() {
      _activeRoute = _availableRoutes[nextIndex];
      // Reset navigation if active
      if (_isNavigating) {
        _navController.stop();
        _navController.reset();
        _isNavigating = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Route updated by Admin: $_activeRoute'),
        backgroundColor: CommutasColors.primaryNavy,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  String _getCurrentInstruction() {
    if (!_isNavigating) return 'Ready to start route navigation';
    final double val = _navController.value;
    final int index = (val * _instructions.length).floor().clamp(0, _instructions.length - 1);
    return _instructions[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('GPS Route Tracker'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route_rounded, color: CommutasColors.primaryNavy),
            tooltip: 'Simulate Admin Change Route',
            onPressed: _cycleRoute,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Stylized Vector Map
          Positioned.fill(
            child: CustomPaint(
              painter: _VectorMapPainter(
                progress: _isNavigating ? _navController.value : 0.0,
              ),
            ),
          ),

          // 2. Turn-by-Turn Guidance Overlay (Top)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildGuidanceCard(),
          ),

          // 3. Navigation Controls (Bottom Panel like Uber/inDriver)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildNavigationPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CommutasShapes.cardDecoration.copyWith(
        color: CommutasColors.primaryNavy,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: CommutasColors.emeraldGreen,
            child: Icon(
              _isNavigating ? Icons.navigation_rounded : Icons.gps_fixed_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isNavigating ? 'NAVIGATION ACTIVE' : 'ROUTE AWAITING START',
                  style: CommutasTextStyles.labelBold.copyWith(
                    color: CommutasColors.emeraldGreen,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getCurrentInstruction(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationPanel() {
    // Calculate simulated stats based on navigation progress
    final double progress = _isNavigating ? _navController.value : 0.0;
    final double totalDist = 5.6; // km
    final double remainingDist = totalDist * (1.0 - progress);
    final int remainingTime = (14 * (1.0 - progress)).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: CommutasShapes.cardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        color: CommutasColors.emeraldGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _activeRoute,
                        style: CommutasTextStyles.labelBold.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Admin-Managed Route (Dynamic)',
                    style: CommutasTextStyles.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _cycleRoute,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: CommutasColors.lightGreenBg,
                  child: Text(
                    'CHANGE',
                    style: CommutasTextStyles.labelCaption.copyWith(fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: CommutasColors.lineBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: CommutasColors.slateMuted, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNavigating ? '$remainingTime mins' : '-- mins',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Est. Time', style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.straighten_rounded, color: CommutasColors.slateMuted, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isNavigating ? '${remainingDist.toStringAsFixed(1)} km' : '${totalDist.toStringAsFixed(1)} km',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Distance', style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              // Uber-like external nav button
              ElevatedButton(
                onPressed: _launchExternalMap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: CommutasColors.primaryNavy,
                  side: const BorderSide(color: CommutasColors.lineBorder, width: 1),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                child: const Icon(Icons.map_rounded, color: CommutasColors.primaryNavy, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _toggleNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNavigating ? CommutasColors.danger : CommutasColors.emeraldGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                  child: Text(
                    _isNavigating ? 'STOP SIMULATION' : 'START NAVIGATION',
                    style: CommutasTextStyles.labelBold.copyWith(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Custom Vector Map Painter (Simulating roads, stops, and moving bus)
// ──────────────────────────────────────────────────────────
class _VectorMapPainter extends CustomPainter {
  final double progress;

  _VectorMapPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Land background
    final landPaint = Paint()..color = const Color(0xFFF0F2F5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // 2. Draw Secondary/Background Roads
    final roadBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFDCDFE4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    // Draw some grid roads
    final Path gridRoads = Path();
    // Horizontal crossroads
    gridRoads.moveTo(0, size.height * 0.25);
    gridRoads.lineTo(size.width, size.height * 0.25);
    gridRoads.moveTo(0, size.height * 0.7);
    gridRoads.lineTo(size.width, size.height * 0.7);
    // Vertical crossroads
    gridRoads.moveTo(size.width * 0.25, 0);
    gridRoads.lineTo(size.width * 0.25, size.height);
    gridRoads.moveTo(size.width * 0.75, 0);
    gridRoads.lineTo(size.width * 0.75, size.height);

    canvas.drawPath(gridRoads, roadBorderPaint);
    canvas.drawPath(gridRoads, roadBgPaint);

    // 3. Define the Primary Route Path (S-shape curve from top-left to bottom-right)
    final Path routePath = Path();
    final p0 = Offset(size.width * 0.15, size.height * 0.15);
    final p1 = Offset(size.width * 0.8, size.height * 0.3);
    final p2 = Offset(size.width * 0.2, size.height * 0.6);
    final p3 = Offset(size.width * 0.85, size.height * 0.85);

    routePath.moveTo(p0.dx, p0.dy);
    routePath.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

    // Draw active route path border & fill
    final activeRouteBorder = Paint()
      ..color = CommutasColors.accentCobalt.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    final activeRouteFill = Paint()
      ..color = CommutasColors.accentCobalt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(routePath, activeRouteBorder);
    canvas.drawPath(routePath, activeRouteFill);

    // 4. Draw Stops/Markers along the route
    _drawMarker(canvas, p0, 'Campus Terminal', true);
    _drawMarker(canvas, Offset(size.width * 0.45, size.height * 0.38), 'Mandian Stop', false);
    _drawMarker(canvas, Offset(size.width * 0.34, size.height * 0.54), 'Supply Stop', false);
    _drawMarker(canvas, p3, 'City Center', true);

    // 5. Draw the Moving Bus Location (Blue Dot / Pulse)
    // We compute the point along the cubic bezier curve based on progress
    final Offset busPos = _getPointOnCubicBezier(p0, p1, p2, p3, progress);

    // Pulse animation
    final double pulseRadius = 12 + (math.sin(DateTime.now().millisecondsSinceEpoch * 0.005) * 4);
    final pulsePaint = Paint()
      ..color = CommutasColors.accentCobalt.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(busPos, pulseRadius, pulsePaint);

    // Inner marker
    final busMarkerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final busMarkerBorder = Paint()
      ..color = CommutasColors.accentCobalt
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas.drawCircle(busPos, 8.0, busMarkerPaint);
    canvas.drawCircle(busPos, 8.0, busMarkerBorder);

    // Small center dot
    final centerDot = Paint()
      ..color = CommutasColors.accentCobalt
      ..style = PaintingStyle.fill;
    canvas.drawCircle(busPos, 4.0, centerDot);
  }

  void _drawMarker(Canvas canvas, Offset pos, String name, bool isTerminal) {
    final pinPaint = Paint()
      ..color = isTerminal ? CommutasColors.primaryNavy : CommutasColors.emeraldGreen
      ..style = PaintingStyle.fill;

    // Draw a small square marker to fit the blocky retro theme
    canvas.drawRect(Rect.fromCenter(center: pos, width: 10, height: 10), pinPaint);
    
    // Draw white inner square for terminals
    if (isTerminal) {
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromCenter(center: pos, width: 4, height: 4), innerPaint);
    }

    // Label text
    final textPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: GoogleFonts.inter(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: CommutasColors.primaryNavy,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(pos.dx - textPainter.width / 2, pos.dy - 16));
  }

  // Cubic Bezier interpolation
  Offset _getPointOnCubicBezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final double u = 1 - t;
    final double tt = t * t;
    final double uu = u * u;
    final double uuu = uu * u;
    final double ttt = tt * t;

    final double x = uuu * p0.dx + 3 * uu * t * p1.dx + 3 * u * tt * p2.dx + ttt * p3.dx;
    final double y = uuu * p0.dy + 3 * uu * t * p1.dy + 3 * u * tt * p2.dy + ttt * p3.dy;

    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _VectorMapPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
