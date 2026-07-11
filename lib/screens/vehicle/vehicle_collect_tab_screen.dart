import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'vehicle_session_screen.dart';
import '../services/auth_service.dart';
import '../../theme.dart';

class VehicleCollectTabScreen extends StatefulWidget {
  final Function(int) onNavigateToTab;

  const VehicleCollectTabScreen({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  State<VehicleCollectTabScreen> createState() => _VehicleCollectTabScreenState();
}

class _VehicleCollectTabScreenState extends State<VehicleCollectTabScreen> {
  final AuthService _authService = AuthService();
  
  bool _isLoading = true;
  String? _sessionId;
  String? _scheduleId;
  String? _routeName;
  String? _routePath;
  String? _timing;

  // Route schedules fetching state
  List<Map<String, String>> _schedules = [];
  String? _selectedScheduleId;
  String? _fetchError;
  bool _isInitializingSession = false;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkActiveSession();
  }

  /// Check if there's an active session stored in SharedPreferences.
  /// If found, verify it's still valid on the server before showing the session screen.
  Future<void> _checkActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sId = prefs.getString('active_session_id');

    if (!mounted) return;

    if (sId != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final token = prefs.getString('session_token') ?? '';
        final session = await _authService.getVehicleSession(token: token, sessionId: sId);

        if (session != null && (session['status'] == 'created' || session['status'] == 'active')) {
          if (mounted) {
            setState(() {
              _sessionId = sId;
              _scheduleId = prefs.getString('active_session_schedule_id');
              _routeName = prefs.getString('active_session_route_name');
              _routePath = prefs.getString('active_session_route_path');
              _timing = prefs.getString('active_session_timing');
              _isLoading = false;
            });
          }
        } else {
          // Session is completed, cancelled, or invalid on the server. Clear local cache.
          await _clearLocalSession();
        }
      } catch (e) {
        // If query fails (e.g. 404), assume session is invalid and clear it.
        developer.log('Active session verification failed: $e. Clearing local cache.', name: 'VehicleCollectTabScreen');
        await _clearLocalSession();
      }
    } else {
      setState(() {
        _sessionId = null;
        _scheduleId = null;
        _routeName = null;
        _routePath = null;
        _timing = null;
      });
      _fetchAssignedSchedules();
    }
  }

  Future<void> _clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_id');
    await prefs.remove('active_session_schedule_id');
    await prefs.remove('active_session_route_name');
    await prefs.remove('active_session_route_path');
    await prefs.remove('active_session_timing');
    
    if (mounted) {
      setState(() {
        _sessionId = null;
        _scheduleId = null;
        _routeName = null;
        _routePath = null;
        _timing = null;
      });
      _fetchAssignedSchedules();
    }
  }

  /// Fetch route schedules assigned to this vehicle from the server.
  Future<void> _fetchAssignedSchedules() async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
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
          'path': '${item['start_location']} → ${item['via']} → ${item['end_location']}',
          'timing': timing,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _schedules = list;
          if (_selectedScheduleId == null && list.isNotEmpty) {
            _selectedScheduleId = list.first['schedule_id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('Error fetching assigned schedules: $e', name: 'VehicleCollectTabScreen');
      if (mounted) {
        setState(() {
          _fetchError = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  /// Initialize a new boarding session via the server API.
  Future<void> _initializeSession() async {
    if (_selectedScheduleId == null) return;

    setState(() {
      _isInitializingSession = true;
      _fetchError = null;
    });

    final selected = _schedules.firstWhere((s) => s['schedule_id'] == _selectedScheduleId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      if (token.isEmpty) {
        throw Exception('Not authenticated. Please log in again.');
      }

      final res = await _authService.startVehicleSession(
        token: token,
        routeScheduleId: _selectedScheduleId!,
      );

      if (res == null || res['session_id'] == null) {
        throw Exception('Server returned an invalid session response.');
      }

      final sId = res['session_id'];

      await prefs.setString('active_session_id', sId);
      await prefs.setString('active_session_schedule_id', _selectedScheduleId!);
      await prefs.setString('active_session_route_name', selected['route']!);
      await prefs.setString('active_session_route_path', selected['path']!);
      await prefs.setString('active_session_timing', selected['timing']!);

      if (mounted) {
        setState(() {
          _sessionId = sId;
          _scheduleId = _selectedScheduleId;
          _routeName = selected['route'];
          _routePath = selected['path'];
          _timing = selected['timing'];
          _isInitializingSession = false;
        });
      }
    } catch (e) {
      developer.log('Session start failed: $e', name: 'VehicleCollectTabScreen');
      if (mounted) {
        setState(() {
          _fetchError = e.toString().replaceAll('Exception:', '').trim();
          _isInitializingSession = false;
        });
      }
    }
  }

  /// Called when the session screen signals that the session has ended.
  void _onSessionEnded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_session_id');
    await prefs.remove('active_session_schedule_id');
    await prefs.remove('active_session_route_name');
    await prefs.remove('active_session_route_path');
    await prefs.remove('active_session_timing');

    if (mounted) {
      setState(() {
        _sessionId = null;
        _scheduleId = null;
        _routeName = null;
        _routePath = null;
        _timing = null;
      });
      _fetchAssignedSchedules();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isInitializingSession) {
      return Scaffold(
        backgroundColor: CommutasColors.backgroundGray,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
              ),
              const SizedBox(height: 16),
              Text(
                _isInitializingSession ? 'Initializing session...' : 'Loading schedules...',
                style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
              ),
            ],
          ),
        ),
      );
    }

    // If active session exists, show the session dashboard
    if (_sessionId != null && _scheduleId != null && _routeName != null && _routePath != null && _timing != null) {
      return VehicleSessionScreen(
        sessionId: _sessionId!,
        scheduleId: _scheduleId!,
        routeName: _routeName!,
        routePath: _routePath!,
        timing: _timing!,
        onSessionEnded: _onSessionEnded,
      );
    }

    // Otherwise show schedule selection
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.directions_bus_rounded, size: 40, color: CommutasColors.primaryNavy),
              const SizedBox(height: 12),
              Text(
                'START TRANSIT RUN',
                style: CommutasTextStyles.heading2.copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a route schedule and initialize a boarding session to begin collecting fares.',
                style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
              ),
              const SizedBox(height: 24),

              // Error card
              if (_fetchError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: CommutasColors.danger, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline, color: CommutasColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ERROR',
                            style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, color: CommutasColors.danger),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fetchError!,
                        style: const TextStyle(fontSize: 11, color: CommutasColors.slateMuted),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchAssignedSchedules,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CommutasColors.primaryNavy,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 42),
                        ),
                        child: const Text('RETRY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              Text(
                'SELECT ROUTE SCHEDULE',
                style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, letterSpacing: 0.5),
              ),
              const SizedBox(height: 12),
              
              if (_schedules.isEmpty && _fetchError == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Icon(Icons.event_busy_rounded, color: CommutasColors.slateMuted, size: 32),
                      const SizedBox(height: 12),
                      const Text(
                        'No assigned routes found for this vehicle.',
                        style: TextStyle(color: CommutasColors.slateMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _fetchAssignedSchedules,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CommutasColors.primaryNavy,
                          side: const BorderSide(color: CommutasColors.primaryNavy),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        child: const Text('REFRESH'),
                      ),
                    ],
                  ),
                )
              else
                ..._schedules.map((run) {
                  final isSelected = run['schedule_id'] == _selectedScheduleId;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedScheduleId = run['schedule_id'];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: isSelected ? CommutasColors.emeraldGreen : CommutasColors.lineBorder,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      color: run['session'] == 'Morning' ? CommutasColors.lightGreenBg : CommutasColors.primaryNavy.withValues(alpha: 0.08),
                                      child: Text(
                                        run['session']!.toUpperCase(),
                                        style: TextStyle(
                                          color: run['session'] == 'Morning' ? CommutasColors.emeraldGreen : CommutasColors.primaryNavy,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      run['timing']!,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: CommutasColors.primaryNavy),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  run['route']!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: CommutasColors.primaryNavy),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  run['path']!,
                                  style: const TextStyle(fontSize: 10, color: CommutasColors.slateMuted),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: CommutasColors.emeraldGreen, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                
              const SizedBox(height: 20),
              
              if (_schedules.isNotEmpty)
                ElevatedButton(
                  onPressed: _selectedScheduleId != null ? _initializeSession : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CommutasColors.primaryNavy,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    minimumSize: const Size(double.infinity, 54),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                  child: const Text(
                    'INITIALIZE BOARDING SESSION',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
