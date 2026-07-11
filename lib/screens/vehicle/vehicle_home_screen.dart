import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import '../../theme.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'vehicle_history_screen.dart';

class VehicleHomeScreen extends StatefulWidget {
  final String vehicleName;
  final String vehicleRegNo;
  final Function(int)? onNavigateToTab;

  const VehicleHomeScreen({
    super.key,
    required this.vehicleName,
    required this.vehicleRegNo,
    this.onNavigateToTab,
  });

  @override
  State<VehicleHomeScreen> createState() => _VehicleHomeScreenState();
}

class _VehicleHomeScreenState extends State<VehicleHomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  final bool _isGpsActive = true;
  bool _isBusActive = true;
  final AuthService _authService = AuthService();

  String _temp = '34°C';
  String _weatherEmoji = '☀️';

  List<Map<String, String>>? _allAssignedRoutes;
  bool _isLoadingRoutes = true;
  String? _routesError;
  
  final TextEditingController _vehicleSearchCtrl = TextEditingController();
  String _vehicleSearchQuery = '';
  String? _vehicleTimeFilter;
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _loadWeather();
    _loadRoutes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _vehicleSearchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';
    if (token.isEmpty) return null;
    return await _authService.getVehicleProfile(token: token);
  }

  Future<void> _loadRoutes() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRoutes = true;
      _routesError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      if (token.isEmpty) {
        throw Exception('Not authenticated. Please log in again.');
      }

      final items = await _authService.getAssignedSchedules(token: token);
      final list = items.map<Map<String, String>>((item) {
        final slotName = item['time_slot_name']?.toString() ?? 'Morning';
        final parts = slotName.split('-');
        final session = parts.first.trim();
        final timing = parts.length > 1 ? parts.last.trim() : slotName;

        return {
          'schedule_id': item['schedule_id']?.toString() ?? '',
          'session': session,
          'route': item['route_id']?.toString() ?? '',
          'path': '',
          'timing': timing,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allAssignedRoutes = list;
          _isLoadingRoutes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _routesError = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingRoutes = false;
        });
      }
    }
  }

  Future<void> _loadWeather() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': '34.19799725235686',
          'longitude': '73.24585572883572',
          'current_weather': 'true',
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final current = response.data['current_weather'];
        if (current != null) {
          final double tempVal = current['temperature'];
          final int code = current['weathercode'];
          if (mounted) {
            setState(() {
              _temp = '${tempVal.round()}°C';
              _weatherEmoji = _getWeatherEmoji(code);
            });
          }
        }
      }
    } catch (e) {
      // Keep default fallback
    }
  }

  String _getWeatherEmoji(int code) {
    if (code == 0) return '☀️'; // Clear sky
    if (code >= 1 && code <= 3) return '🌤️'; // Mainly clear, partly cloudy
    if (code >= 45 && code <= 48) return '🌫️'; // Fog
    if (code >= 51 && code <= 67) return '🌧️'; // Drizzle, rain
    if (code >= 71 && code <= 77) return '❄️'; // Snow
    if (code >= 80 && code <= 82) return '🌦️'; // Rain showers
    if (code >= 95 && code <= 99) return '⛈️'; // Thunderstorm
    return '☀️';
  }

  String _formatTodayDate() {
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final day = now.day;
    
    return '$weekday, $month $day';
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
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: _buildAppBar(),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
              ),
            );
          }
          final profile = snapshot.data;
          final driverName = profile?['current_driver'] ?? widget.vehicleName;
          final capacity = profile?['max_capacity'] ?? 40;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildGreetingsCard(driverName),
                const SizedBox(height: 16),
                _buildVehicleCard(capacity, driverName),
                const SizedBox(height: 16),
                _buildStationAnimationCard(),
                _buildRoadDivider(),
                _buildAssignedRoutesCard(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
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
    );
  }

  Widget _buildGreetingsCard(String driverName) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, _) {
                return ClipRect(
                  child: CustomPaint(
                    painter: _GreetingsBackgroundPainter(animationValue: _animationController.value),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CommutasColors.lightGreenBg.withOpacity(0.95),
                    Colors.white.withOpacity(0.20),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CommutasColors.lightGreenBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: CommutasColors.emeraldGreen, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.face_rounded,
                    color: CommutasColors.emeraldGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getGreeting().toUpperCase(),
                        style: GoogleFonts.inter(
                          color: CommutasColors.slateMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CAPTAIN',
                        style: GoogleFonts.inter(
                          color: CommutasColors.emeraldGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        driverName,
                        style: GoogleFonts.inter(
                          color: CommutasColors.primaryNavy,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _weatherEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _temp,
                          style: GoogleFonts.inter(
                            color: CommutasColors.primaryNavy,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, color: CommutasColors.emeraldGreen, size: 10),
                        const SizedBox(width: 2),
                        Text(
                          'ABBOTTABAD',
                          style: GoogleFonts.inter(
                            color: CommutasColors.primaryNavy,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTodayDate().toUpperCase(),
                      style: GoogleFonts.inter(
                        color: CommutasColors.slateMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(int maxCapacity, String driverName) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            CommutasColors.primaryNavy,
            Color(0xFF282A54),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.zero,
        border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: CommutasColors.primaryNavy.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.directions_bus_rounded,
              color: Colors.white.withOpacity(0.04),
              size: 150,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
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
                            widget.vehicleRegNo,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white12, height: 1, thickness: 1),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.event_seat_rounded, color: CommutasColors.sageGreen, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Max Capacity',
                                style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$maxCapacity Seats',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 48,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, color: CommutasColors.sageGreen, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Assigned Driver',
                                style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            driverName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationAnimationCard() {
    return GestureDetector(
      onTap: () {
        widget.onNavigateToTab?.call(1); // Switch to Collect Tab (index 1)
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
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
                          'START BOARDING SESSION',
                          style: CommutasTextStyles.labelBold.copyWith(
                            color: CommutasColors.primaryNavy,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap here to open route schedules',
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
                              Icon(Icons.play_arrow_rounded, color: CommutasColors.emeraldGreen, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'START SESSION',
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



  Widget _buildVehicleFilterHeader(List<Map<String, String>> originalRoutes) {
    final uniqueTimes = originalRoutes
        .map((run) => run['timing'] ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    uniqueTimes.sort();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: CommutasColors.backgroundGray,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: CommutasColors.lineBorder),
            ),
            child: TextField(
              controller: _vehicleSearchCtrl,
              onChanged: (val) {
                setState(() {
                  _vehicleSearchQuery = val;
                });
              },
              style: CommutasTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search routes or pathways...',
                hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: CommutasColors.slateMuted, size: 20),
                suffixIcon: _vehicleSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: CommutasColors.slateMuted, size: 18),
                        onPressed: () {
                          _vehicleSearchCtrl.clear();
                          setState(() {
                            _vehicleSearchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          if (uniqueTimes.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    selected: _vehicleTimeFilter == null,
                    label: Text(
                      'All Times',
                      style: TextStyle(
                        color: _vehicleTimeFilter == null ? Colors.white : CommutasColors.primaryNavy,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: CommutasColors.backgroundGray,
                    selectedColor: CommutasColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: const RoundedRectangleBorder(
                      side: BorderSide(color: CommutasColors.lineBorder),
                      borderRadius: BorderRadius.zero,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _vehicleTimeFilter = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ...uniqueTimes.map((time) {
                    final isSelected = _vehicleTimeFilter == time;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          time,
                          style: TextStyle(
                            color: isSelected ? Colors.white : CommutasColors.primaryNavy,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: CommutasColors.backgroundGray,
                        selectedColor: CommutasColors.emeraldGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: const RoundedRectangleBorder(
                          side: BorderSide(color: CommutasColors.lineBorder),
                          borderRadius: BorderRadius.zero,
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          setState(() {
                            _vehicleTimeFilter = selected ? time : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedRoutesCard() {
    if (_isLoadingRoutes) {
      return Container(
        width: double.infinity,
        decoration: CommutasShapes.cardDecoration,
        padding: const EdgeInsets.all(24.0),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
          ),
        ),
      );
    }

    if (_routesError != null) {
      return Container(
        width: double.infinity,
        decoration: CommutasShapes.cardDecoration,
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error loading assigned runs: $_routesError',
          style: TextStyle(color: CommutasColors.danger, fontSize: 12),
        ),
      );
    }

    final routes = _allAssignedRoutes ?? [];
    
    // Apply filters
    final filtered = routes.where((run) {
      final route = (run['route'] ?? '').toLowerCase();
      final path = (run['path'] ?? '').toLowerCase();
      final queryText = _vehicleSearchQuery.trim().toLowerCase();
      
      bool matchesSearch = queryText.isEmpty || route.contains(queryText) || path.contains(queryText);
      bool matchesTime = _vehicleTimeFilter == null || run['timing'] == _vehicleTimeFilter;
      
      return matchesSearch && matchesTime;
    }).toList();

    return Container(
      width: double.infinity,
      decoration: CommutasShapes.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[50],
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in_rounded, size: 16, color: CommutasColors.primaryNavy),
                const SizedBox(width: 8),
                Text(
                  'Relevant Routes',
                  style: CommutasTextStyles.labelBold.copyWith(
                    fontSize: 10,
                    color: CommutasColors.primaryNavy,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CommutasColors.lineBorder),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off_rounded, size: 36, color: CommutasColors.slateMuted.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'No matching assigned runs.',
                      style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2.8),
                  2: FlexColumnWidth(1.5),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: CommutasColors.lineBorder.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                children: [
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text('SESSION', style: CommutasTextStyles.labelBold.copyWith(fontSize: 9, color: CommutasColors.slateMuted)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 24.0),
                        child: Text('ROUTE ID', style: CommutasTextStyles.labelBold.copyWith(fontSize: 9, color: CommutasColors.slateMuted)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text('TIMINGS', style: CommutasTextStyles.labelBold.copyWith(fontSize: 9, color: CommutasColors.slateMuted)),
                        ),
                      ),
                    ],
                  ),
                  ...filtered.map((run) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                color: run['session'] == 'Morning' ? CommutasColors.lightGreenBg : CommutasColors.primaryNavy.withOpacity(0.08),
                                child: Text(
                                  run['session']!.toUpperCase(),
                                  style: TextStyle(
                                    color: run['session'] == 'Morning' ? CommutasColors.emeraldGreen : CommutasColors.primaryNavy,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0).copyWith(left: 24.0),
                          child: Text(
                            run['route']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: CommutasColors.primaryNavy),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              run['timing']!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: CommutasColors.primaryNavy),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
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

class _GreetingsBackgroundPainter extends CustomPainter {
  final double animationValue;

  _GreetingsBackgroundPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = CommutasColors.primaryNavy.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final double horizonY = size.height * 0.15;
    final double centerX = size.width / 2;

    // Perspective lines radiating outwards
    const int linesCount = 8;
    for (int i = 0; i <= linesCount; i++) {
      final double x = (i / linesCount) * size.width;
      canvas.drawLine(
        Offset(x, horizonY),
        Offset(centerX + (x - centerX) * 2.2, size.height),
        gridPaint,
      );
    }

    // Moving horizontal grid lines
    const int horizLines = 4;
    for (int i = 0; i < horizLines; i++) {
      final double progress = (i + (animationValue * 0.20)) / horizLines;
      final double y = horizonY + (size.height - horizonY) * progress;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Animated emeraldGreen particles rising up
    final sparkPaint = Paint()
      ..color = CommutasColors.emeraldGreen.withOpacity(0.28)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final double pProgress = (animationValue + (i * 0.25)) % 1.0;
      final double px = (centerX - 100) + (i * 65) + (math.sin(pProgress * 4 * math.pi) * 8);
      final double py = size.height - (size.height * 0.85 * pProgress);
      final double radius = 3.0 + (3.0 * (1 - pProgress));

      if (py > horizonY) {
        canvas.drawCircle(Offset(px, py), radius, sparkPaint);
        
        final sparkOutline = Paint()
          ..color = CommutasColors.emeraldGreen.withOpacity(0.45 * (1 - pProgress))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset(px, py), radius + 2.0, sparkOutline);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GreetingsBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
