import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/route_service.dart';
import '../theme.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RouteService _routeService = RouteService();
  
  List<Map<String, dynamic>> _morningSchedules = [];
  List<Map<String, dynamic>> _eveningSchedules = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _preferredRouteId;

  final TextEditingController _morningSearchCtrl = TextEditingController();
  final TextEditingController _eveningSearchCtrl = TextEditingController();
  String _morningSearchQuery = '';
  String _eveningSearchQuery = '';
  String? _morningTimeFilter;
  String? _eveningTimeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _morningSearchCtrl.dispose();
    _eveningSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      final preferredRouteId = prefs.getString('session_preferred_route_id');

      if (mounted) {
        setState(() {
          _preferredRouteId = preferredRouteId;
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final schedules = await _routeService.fetchSchedules(token: token);
      
      final List<Map<String, dynamic>> morning = [];
      final List<Map<String, dynamic>> evening = [];

      for (var item in schedules) {
        final depTime = item['departure_time'] as String? ?? '00:00:00';
        final hour = int.tryParse(depTime.split(':')[0]) ?? 0;
        if (hour < 12) {
          morning.add(item);
        } else {
          evening.add(item);
        }
      }

      // Sort by departure time
      morning.sort((a, b) => (a['departure_time'] as String).compareTo(b['departure_time'] as String));
      evening.sort((a, b) => (a['departure_time'] as String).compareTo(b['departure_time'] as String));

      if (mounted) {
        setState(() {
          _morningSchedules = morning;
          _eveningSchedules = evening;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load schedules: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<String> _getUniqueTimes(List<Map<String, dynamic>> schedules) {
    final times = schedules
        .map((s) => _formatDepartureTime(s['departure_time'] as String? ?? '00:00:00'))
        .toSet()
        .toList();
    times.sort();
    return times;
  }

  String _calculateArrivalTime(String dep) {
    try {
      final parts = dep.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      
      minute += 40;
      if (minute >= 60) {
         hour += minute ~/ 60;
         minute = minute % 60;
      }
      hour = hour % 24;
      
      final isPm = hour >= 12;
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');
      final amPm = isPm ? 'PM' : 'AM';
      
      return '${displayHour.toString().padLeft(2, '0')}:$displayMinute $amPm';
    } catch (_) {
      return '--:--';
    }
  }

  String _formatDepartureTime(String dep) {
    try {
      final parts = dep.split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final isPm = hour >= 12;
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final displayMinute = minute.toString().padLeft(2, '0');
      final amPm = isPm ? 'PM' : 'AM';
      return '${displayHour.toString().padLeft(2, '0')}:$displayMinute $amPm';
    } catch (_) {
      return dep;
    }
  }

  Widget _buildFilterHeader({
    required bool isMorning,
    required List<Map<String, dynamic>> originalSchedules,
    required String searchQuery,
    required String? selectedTime,
    required TextEditingController controller,
    required ValueChanged<String> onSearchChanged,
    required ValueChanged<String?> onTimeFilterChanged,
  }) {
    final uniqueTimes = _getUniqueTimes(originalSchedules);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              controller: controller,
              onChanged: onSearchChanged,
              style: CommutasTextStyles.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search route or area...',
                hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                prefixIcon: const Icon(Icons.search_rounded, color: CommutasColors.slateMuted, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: CommutasColors.slateMuted, size: 18),
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
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
                    selected: selectedTime == null,
                    label: Text(
                      'All Times',
                      style: TextStyle(
                        color: selectedTime == null ? Colors.white : CommutasColors.primaryNavy,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: CommutasColors.backgroundGray,
                    selectedColor: CommutasColors.primaryNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: const RoundedRectangleBorder(
                      side: BorderSide(color: CommutasColors.lineBorder),
                      borderRadius: BorderRadius.zero,
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) onTimeFilterChanged(null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...uniqueTimes.map((time) {
                    final isSelected = selectedTime == time;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        selected: isSelected,
                        label: Text(
                          time,
                          style: TextStyle(
                            color: isSelected ? Colors.white : CommutasColors.primaryNavy,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: CommutasColors.backgroundGray,
                        selectedColor: CommutasColors.emeraldGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: const RoundedRectangleBorder(
                          side: BorderSide(color: CommutasColors.lineBorder),
                          borderRadius: BorderRadius.zero,
                        ),
                        showCheckmark: false,
                        onSelected: (selected) {
                          onTimeFilterChanged(selected ? time : null);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('Route Schedules'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CommutasColors.emeraldGreen,
          labelColor: CommutasColors.emeraldGreen,
          unselectedLabelColor: CommutasColors.primaryNavy.withOpacity(0.5),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Morning Sessions'),
            Tab(text: 'Evening Sessions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScheduleList(_morningSchedules, true),
          _buildScheduleList(_eveningSchedules, false),
        ],
      ),
    );
  }

  Widget _buildScheduleList(List<Map<String, dynamic>> schedules, bool isMorning) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: CommutasColors.emeraldGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.danger),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSchedules,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final query = isMorning ? _morningSearchQuery : _eveningSearchQuery;
    final selectedTime = isMorning ? _morningTimeFilter : _eveningTimeFilter;
    final ctrl = isMorning ? _morningSearchCtrl : _eveningSearchCtrl;

    final filteredSchedules = schedules.where((schedule) {
      final routeName = (schedule['route_name'] as String? ?? '').toLowerCase();
      final routeId = (schedule['route_id'] as String? ?? '').toLowerCase();
      final queryText = query.trim().toLowerCase();
      
      bool matchesSearch = true;
      if (queryText.isNotEmpty) {
        matchesSearch = routeName.contains(queryText) || routeId.contains(queryText);
      }

      bool matchesTime = true;
      if (selectedTime != null) {
        final formattedTime = _formatDepartureTime(schedule['departure_time'] as String? ?? '00:00:00');
        matchesTime = formattedTime == selectedTime;
      }

      return matchesSearch && matchesTime;
    }).toList();

    return Column(
      children: [
        _buildFilterHeader(
          isMorning: isMorning,
          originalSchedules: schedules,
          searchQuery: query,
          selectedTime: selectedTime,
          controller: ctrl,
          onSearchChanged: (val) {
            setState(() {
              if (isMorning) {
                _morningSearchQuery = val;
              } else {
                _eveningSearchQuery = val;
              }
            });
          },
          onTimeFilterChanged: (val) {
            setState(() {
              if (isMorning) {
                _morningTimeFilter = val;
              } else {
                _eveningTimeFilter = val;
              }
            });
          },
        ),
        const Divider(height: 1, color: CommutasColors.lineBorder),
        Expanded(
          child: filteredSchedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: CommutasColors.slateMuted.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No matching schedules found.',
                        style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredSchedules.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildScheduleCard(filteredSchedules[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final routeName = schedule['route_name'] as String? ?? 'Unknown Route';
    final depRaw = schedule['departure_time'] as String? ?? '00:00:00';
    final routeId = schedule['route_id'] as String? ?? '';
    
    final isRecommended = routeId == _preferredRouteId;

    final formattedDep = _formatDepartureTime(depRaw);
    final calculatedArr = _calculateArrivalTime(depRaw);
    
    // Clean Route tag label
    final String routeLabel = routeId.replaceAll('ROUTE-', '').replaceAll('-REV', '');

    return Container(
      decoration: CommutasShapes.cardDecoration.copyWith(
        border: Border.all(
          color: isRecommended ? CommutasColors.emeraldGreen.withOpacity(0.5) : CommutasColors.lineBorder,
          width: isRecommended ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isRecommended ? CommutasColors.lightGreenBg : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(CommutasShapes.borderRadius)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: CommutasColors.primaryNavy,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        routeLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.directions_bus_filled, color: CommutasColors.emeraldGreen, size: 18),
                  ],
                ),
                if (isRecommended)
                  const Text('RECOMMENDED', style: TextStyle(color: CommutasColors.emeraldGreen, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(height: 1, color: CommutasColors.lineBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routeName, style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTimeInfo('DEPARTURE', formattedDep),
                    _buildTimeInfo('ARRIVAL', calculatedArr),
                    _buildTimeInfo('DURATION', '40 Minutes'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CommutasTextStyles.labelBold.copyWith(fontSize: 8, color: CommutasColors.slateMuted)),
        const SizedBox(height: 4),
        Text(value, style: CommutasTextStyles.labelBold.copyWith(fontSize: 12, color: CommutasColors.primaryNavy)),
      ],
    );
  }
}
