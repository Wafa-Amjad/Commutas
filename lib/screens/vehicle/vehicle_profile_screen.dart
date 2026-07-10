import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';
import '../login_signup_screen.dart';
import 'vehicle_service.dart';

class VehicleProfileScreen extends StatelessWidget {
  final String vehicleName;
  final String vehicleRegNo;
  final VehicleService _vehicleService = VehicleService();

  VehicleProfileScreen({
    super.key,
    required this.vehicleName,
    required this.vehicleRegNo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('Vehicle Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _vehicleService.fetchVehicleDetails(vehicleRegNo),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load profile details',
                style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.danger),
              ),
            );
          } else if (!snapshot.hasData) {
            return Center(
              child: Text(
                'No profile details found',
                style: CommutasTextStyles.bodyMedium,
              ),
            );
          }

          final data = snapshot.data!;
          final busRegNo = data['bus_reg_no'] ?? vehicleRegNo;
          final driverName = data['driver_name'] ?? 'N/A';
          final seatCapacity = data['seat_capacity'] ?? 'N/A';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  InteractiveProfileHeader(
                    vehicleName: vehicleName,
                    busRegNo: busRegNo,
                  ),
                  const SizedBox(height: 24),
                  _buildAnimatedInfoCard(busRegNo, driverName, seatCapacity),
                  const SizedBox(height: 32),
                  _buildActionButtons(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedInfoCard(String busReg, String driver, String capacity) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: CommutasColors.primaryNavy.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with a subtle gradient and a pulsing indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CommutasColors.primaryNavy.withOpacity(0.03),
                  Colors.white,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: CommutasColors.primaryNavy,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'VEHICLE SPECIFICATIONS',
                      style: CommutasTextStyles.labelBold.copyWith(
                        fontSize: 11,
                        color: CommutasColors.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                // Pulsing Green Active badge
                Row(
                  children: [
                    const _PulsingDot(),
                    const SizedBox(width: 6),
                    Text(
                      'VERIFIED BY ADMIN',
                      style: TextStyle(
                        color: CommutasColors.emeraldGreen,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: CommutasColors.lineBorder),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _buildModernInfoRow(Icons.pin_rounded, 'Registration No', busReg),
                _buildDivider(),
                _buildModernInfoRow(Icons.person_rounded, 'Assigned Driver', driver),
                _buildDivider(),
                _buildModernInfoRow(Icons.event_seat_rounded, 'Seat Capacity', capacity),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CommutasColors.primaryNavy.withOpacity(0.04),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, size: 18, color: CommutasColors.primaryNavy),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: CommutasTextStyles.bodySmall.copyWith(
                    color: CommutasColors.slateMuted,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: CommutasTextStyles.labelBold.copyWith(
                    fontSize: 14,
                    color: CommutasColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: CommutasColors.lineBorder.withOpacity(0.5),
      indent: 48,
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('session_active', false);
          await prefs.remove('session_role');
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginSignupScreen()),
              (route) => false,
            );
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: CommutasColors.danger,
          side: BorderSide(color: CommutasColors.danger.withOpacity(0.8), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text(
          'LOGOUT VEHICLE',
          style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.danger),
        ),
      ),
    );
  }
}

class InteractiveProfileHeader extends StatefulWidget {
  final String vehicleName;
  final String busRegNo;

  const InteractiveProfileHeader({
    super.key,
    required this.vehicleName,
    required this.busRegNo,
  });

  @override
  State<InteractiveProfileHeader> createState() => _InteractiveProfileHeaderState();
}

class _InteractiveProfileHeaderState extends State<InteractiveProfileHeader> with SingleTickerProviderStateMixin {
  bool _isEngineOn = false;
  double _scale = 1.0;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _triggerAvatarAnimation() {
    if (!_spinController.isAnimating) {
      _spinController.forward(from: 0.0);
    }
    setState(() {
      _scale = 1.15;
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _scale = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isEngineOn = !_isEngineOn;
        });
        _triggerAvatarAnimation();
        
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEngineOn 
                  ? 'Engine Started! Simulated Speed: 40 km/h' 
                  : 'Engine Turned Off. Status: Parked',
            ),
            backgroundColor: _isEngineOn ? CommutasColors.emeraldGreen : CommutasColors.primaryNavy,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isEngineOn
                ? [const Color(0xFF0F1E19), const Color(0xFF142D23)]
                : [CommutasColors.primaryNavy, const Color(0xFF1E2638)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: _isEngineOn ? CommutasColors.emeraldGreen : Colors.white24,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isEngineOn ? CommutasColors.emeraldGreen : CommutasColors.primaryNavy).withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Interactive Animated Avatar
            AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 150),
              curve: Curves.bounceOut,
              child: RotationTransition(
                turns: _spinController,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isEngineOn 
                        ? CommutasColors.emeraldGreen.withOpacity(0.2) 
                        : Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: _isEngineOn ? CommutasColors.emeraldGreen : Colors.white54,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus_rounded,
                    color: _isEngineOn ? CommutasColors.emeraldGreen : Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.vehicleName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.busRegNo,
              style: TextStyle(
                color: _isEngineOn ? CommutasColors.emeraldGreen : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            
            // Sub-metrics row inside the header card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderMetric(
                  icon: Icons.power_settings_new_rounded,
                  label: 'ENGINE',
                  value: _isEngineOn ? 'ON (RUNNING)' : 'OFF (PARKED)',
                  color: _isEngineOn ? CommutasColors.emeraldGreen : Colors.white54,
                ),
                Container(width: 1, height: 24, color: Colors.white24),
                _buildHeaderMetric(
                  icon: Icons.speed_rounded,
                  label: 'SPEED',
                  value: _isEngineOn ? '40 km/h' : '0 km/h',
                  color: _isEngineOn ? CommutasColors.emeraldGreen : Colors.white54,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: CommutasColors.emeraldGreen.withOpacity(0.3 + (0.7 * _controller.value)),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: CommutasColors.emeraldGreen.withOpacity(0.5 * (1 - _controller.value)),
                blurRadius: 6,
                spreadRadius: 2 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
