import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/route_service.dart';
import '../theme.dart';
import 'active_bus_map_screen.dart';

class ActiveBusesScreen extends StatefulWidget {
  const ActiveBusesScreen({super.key});

  @override
  State<ActiveBusesScreen> createState() => _ActiveBusesScreenState();
}

class _ActiveBusesScreenState extends State<ActiveBusesScreen> with SingleTickerProviderStateMixin {
  final RouteService _routeService = RouteService();
  List<Map<String, dynamic>> _activeBuses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveBuses();
  }

  Future<void> _loadActiveBuses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      if (token.isEmpty) {
        throw Exception('User is not authenticated. Please log in again.');
      }

      final buses = await _routeService.fetchActiveBuses(token: token);
      
      if (mounted) {
        setState(() {
          _activeBuses = buses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  Color _getOccupancyColor(double ratio) {
    if (ratio <= 0.5) {
      return CommutasColors.emeraldGreen;
    } else if (ratio <= 0.85) {
      return CommutasColors.warning;
    } else {
      return CommutasColors.danger;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_bus_outlined,
              size: 80,
              color: CommutasColors.slateMuted,
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Buses',
              style: CommutasTextStyles.heading2.copyWith(color: CommutasColors.primaryNavy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'There are no buses running on active trips at the moment. Please check back later during transit hours.',
              style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadActiveBuses,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                'Refresh List',
                style: CommutasTextStyles.buttonLabel,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CommutasColors.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: CommutasColors.danger,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Active Buses',
              style: CommutasTextStyles.heading2.copyWith(color: CommutasColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred. Please try again.',
              style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadActiveBuses,
              style: ElevatedButton.styleFrom(
                backgroundColor: CommutasColors.primaryNavy,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Retry', style: CommutasTextStyles.buttonLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('TRACK ACTIVE BUSES'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActiveBuses,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadActiveBuses,
        color: CommutasColors.primaryNavy,
        child: _isLoading
            ? _buildLoadingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _activeBuses.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _activeBuses.length,
                        itemBuilder: (context, index) {
                          final bus = _activeBuses[index];
                          final int maxCap = bus['max_capacity'] ?? 40;
                          final int boarded = bus['passengers_boarded'] ?? 0;
                          final int remaining = bus['capacity_remaining'] ?? (maxCap - boarded);
                          final double ratio = maxCap > 0 ? (boarded / maxCap) : 0.0;
                          final String routeId = bus['route_id'] ?? '';
                          final String routeName = bus['route_name'] ?? 'Unknown Route';
                          final String vehicleNo = bus['vehicle_no'] ?? 'Unknown';
                          final String start = bus['start_location'] ?? '';
                          final String end = bus['end_location'] ?? '';
                          final String via = bus['via'] ?? '';
                          final String departureTime = bus['departure_time'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            decoration: CommutasShapes.cardDecoration,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Route Info & Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  color: CommutasColors.primaryNavy,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              routeId.toUpperCase(),
                                              style: CommutasTextStyles.heading2.copyWith(
                                                color: Colors.white,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              routeName,
                                              style: CommutasTextStyles.bodySmall.copyWith(
                                                color: Colors.white70,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: CommutasColors.emeraldGreen.withOpacity(0.2),
                                          border: Border.all(color: CommutasColors.emeraldGreen, width: 1.5),
                                        ),
                                        child: Text(
                                          'IN TRANSIT',
                                          style: CommutasTextStyles.labelCaption.copyWith(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Body: Path & Details
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Path detail row
                                      Row(
                                        children: [
                                          const Icon(Icons.route_outlined, size: 20, color: CommutasColors.primaryNavy),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: '$start ',
                                                    style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                  TextSpan(
                                                    text: '→ ',
                                                    style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
                                                  ),
                                                  if (via.isNotEmpty) ...[
                                                    TextSpan(
                                                      text: '($via) ',
                                                      style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted, fontSize: 13),
                                                    ),
                                                    TextSpan(
                                                      text: '→ ',
                                                      style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
                                                    ),
                                                  ],
                                                  TextSpan(
                                                    text: end,
                                                    style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Bus Info / Departure Time
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.directions_bus, size: 18, color: CommutasColors.slateMuted),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Bus No: $vehicleNo',
                                                style: CommutasTextStyles.bodyMedium.copyWith(
                                                  color: CommutasColors.inkText,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time_filled, size: 16, color: CommutasColors.slateMuted),
                                              const SizedBox(width: 6),
                                              Text(
                                                departureTime,
                                                style: CommutasTextStyles.bodyMedium.copyWith(
                                                  color: CommutasColors.primaryNavy,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Divider
                                      Container(height: 1, color: CommutasColors.lineBorder),
                                      const SizedBox(height: 16),

                                      // Occupancy Meter
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Occupancy Status',
                                            style: CommutasTextStyles.labelBold.copyWith(fontSize: 11),
                                          ),
                                          Text(
                                            '$boarded / $maxCap Boarded',
                                            style: CommutasTextStyles.bodyMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: _getOccupancyColor(ratio),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        child: LinearProgressIndicator(
                                          value: ratio,
                                          minHeight: 8,
                                          backgroundColor: CommutasColors.lineBorder,
                                          valueColor: AlwaysStoppedAnimation<Color>(_getOccupancyColor(ratio)),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$remaining seats available',
                                        style: CommutasTextStyles.bodySmall.copyWith(
                                          color: remaining == 0
                                              ? CommutasColors.danger
                                              : CommutasColors.slateMuted,
                                          fontWeight: remaining == 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 20),

                                      // Track Bus CTA Button
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ActiveBusMapScreen(
                                                  routeId: routeId,
                                                  routeName: routeName,
                                                  vehicleNo: vehicleNo,
                                                  initialLatitude: bus['latitude'] != null ? (bus['latitude'] as num).toDouble() : null,
                                                  initialLongitude: bus['longitude'] != null ? (bus['longitude'] as num).toDouble() : null,
                                                  maxCapacity: maxCap,
                                                  passengersBoarded: boarded,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
                                          label: Text(
                                            'LIVE MAP TRACKING',
                                            style: CommutasTextStyles.buttonLabel.copyWith(letterSpacing: 0.5),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: CommutasColors.primaryNavy,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
