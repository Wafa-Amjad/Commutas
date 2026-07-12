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
  String? _selectedRouteId; // Null means "All Routes"

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

          // Preserve or reset filter based on new list
          if (_selectedRouteId != null) {
            final exists = buses.any((b) => b['route_id'] == _selectedRouteId);
            if (!exists) {
              _selectedRouteId = null;
            }
          }
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
        physics: const AlwaysScrollableScrollPhysics(),
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

  List<Map<String, String>> _getRouteFilters() {
    final Map<String, String> routes = {};
    for (var bus in _activeBuses) {
      final id = bus['route_id'] as String?;
      final name = bus['route_name'] as String?;
      if (id != null && name != null) {
        routes[id] = name;
      }
    }
    return routes.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
  }

  Widget _buildFilterBar() {
    final filters = _getRouteFilters();
    if (filters.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.filter_list, size: 20, color: CommutasColors.primaryNavy),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRouteId,
                hint: Text(
                  'All Routes',
                  style: CommutasTextStyles.bodyMedium.copyWith(
                    color: CommutasColors.primaryNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'All Routes',
                      style: CommutasTextStyles.bodyMedium.copyWith(
                        color: CommutasColors.primaryNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...filters.map((f) {
                    return DropdownMenuItem<String>(
                      value: f['id'],
                      child: Text(
                        f['id']!,
                        style: CommutasTextStyles.bodyMedium.copyWith(
                          color: CommutasColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedRouteId = val;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.filter_list_off,
              size: 64,
              color: CommutasColors.slateMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No Matching Buses',
              style: CommutasTextStyles.heading2.copyWith(color: CommutasColors.primaryNavy),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'There are no active buses running on the selected route at the moment.',
              style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedRouteId = null;
                });
              },
              child: const Text(
                'Clear Filter',
                style: TextStyle(
                  color: CommutasColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredBuses = _selectedRouteId == null
        ? _activeBuses
        : _activeBuses.where((b) => b['route_id'] == _selectedRouteId).toList();

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
      body: Column(
        children: [
          if (!_isLoading && _errorMessage == null && _activeBuses.isNotEmpty)
            _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadActiveBuses,
              color: CommutasColors.primaryNavy,
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : _activeBuses.isEmpty
                          ? _buildEmptyState()
                          : filteredBuses.isEmpty
                              ? _buildEmptyFilteredState()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16.0),
                                  itemCount: filteredBuses.length,
                                  itemBuilder: (context, index) {
                                    final bus = filteredBuses[index];
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
                                      clipBehavior: Clip.hardEdge,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header
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
                                                        vehicleNo,
                                                        style: CommutasTextStyles.heading2.copyWith(
                                                          color: Colors.white,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        routeId.toUpperCase(),
                                                        style: CommutasTextStyles.bodySmall.copyWith(
                                                          color: Colors.white70,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
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

                                          // Body
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                 // Seat Availability indicator
                                                 Row(
                                                   children: [
                                                     const Icon(
                                                       Icons.event_seat_rounded,
                                                       size: 18,
                                                       color: CommutasColors.primaryNavy,
                                                     ),
                                                     const SizedBox(width: 8),
                                                     Text(
                                                       '$remaining Seats Free',
                                                       style: CommutasTextStyles.bodyMedium.copyWith(
                                                         color: CommutasColors.primaryNavy,
                                                         fontWeight: FontWeight.bold,
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                                 const SizedBox(height: 16),

                                                // Bottom Info Row: Departure Time & Occupancy Text
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
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

                                                // Occupancy Progress Indicator
                                                ClipRRect(
                                                  child: LinearProgressIndicator(
                                                    value: ratio,
                                                    minHeight: 6,
                                                    backgroundColor: CommutasColors.lineBorder,
                                                    valueColor: AlwaysStoppedAnimation<Color>(_getOccupancyColor(ratio)),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),

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
                                                            startLocation: start,
                                                            endLocation: end,
                                                            via: via,
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
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
          ),
        ],
      ),
    );
  }
}
