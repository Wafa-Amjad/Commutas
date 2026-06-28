import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'nfc_pay_screen.dart';
import 'vehicle/vehicle_home_screen.dart';
import 'vehicle/vehicle_payment_check_screen.dart';
import 'vehicle/vehicle_history_screen.dart';
import 'vehicle/vehicle_profile_screen.dart';
import 'vehicle/vehicle_map_screen.dart';

class MainScreen extends StatefulWidget {
  final String studentName;
  final String studentRegNo;
  final String? lastEnteredPassword;
  final String role;

  const MainScreen({
    super.key,
    required this.studentName,
    required this.studentRegNo,
    this.lastEnteredPassword,
    this.role = 'student',
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? _avatarPath;
  String _avatarType = 'emoji';

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onAvatarChanged(String? path, String avatarType) {
    setState(() {
      _avatarPath = path;
      _avatarType = avatarType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = widget.role == 'vehicle'
        ? [
            VehicleHomeScreen(
              vehicleName: widget.studentName,
              vehicleRegNo: widget.studentRegNo,
            ),
            const VehicleMapScreen(),
            const VehiclePaymentCheckScreen(),
            const VehicleHistoryScreen(),
            VehicleProfileScreen(
              vehicleName: widget.studentName,
              vehicleRegNo: widget.studentRegNo,
            ),
          ]
        : [
            HomeScreen(
              studentName: widget.studentName,
              studentRegNo: widget.studentRegNo,
              password: widget.lastEnteredPassword,
              avatarPath: _avatarPath,
              avatarType: _avatarType,
            ),
            const ScheduleScreen(),
            const NFCPayScreen(),
            WalletScreen(studentRegNo: widget.studentRegNo),
            ProfileScreen(
              studentName: widget.studentName,
              studentRegNo: widget.studentRegNo,
              initialAvatarPath: _avatarPath,
              initialAvatarType: _avatarType,
              onAvatarChanged: _onAvatarChanged,
              password: widget.lastEnteredPassword,
            ),
          ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: CommutasColors.lineBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                _buildNavItem(1, widget.role == 'vehicle' ? Icons.navigation_rounded : Icons.commute_rounded, widget.role == 'vehicle' ? 'GPS' : 'Schedule'),
                _buildNfcNavItem(),
                _buildNavItem(3, widget.role == 'vehicle' ? Icons.history_rounded : Icons.wallet_rounded, widget.role == 'vehicle' ? 'History' : 'Wallet'),
                _buildNavItem(4, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? CommutasColors.accentCobalt : CommutasColors.primaryNavy.withOpacity(0.4),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? CommutasColors.accentCobalt : CommutasColors.primaryNavy.withOpacity(0.4),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 10,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 12,
              decoration: const BoxDecoration(
                color: CommutasColors.accentCobalt,
                borderRadius: BorderRadius.zero,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNfcNavItem() {
    final isSelected = _selectedIndex == 2;
    return GestureDetector(
      onTap: () => _onItemTapped(2),
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          color: CommutasColors.primaryNavy,
          borderRadius: BorderRadius.zero, // Rectangular feel
          boxShadow: [
            BoxShadow(
              color: CommutasColors.accentCobalt.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.nfc_rounded,
              color: isSelected ? CommutasColors.accentCobalt : Colors.white,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              widget.role == 'vehicle' ? 'COLLECT' : 'PAY',
              style: TextStyle(
                color: isSelected ? CommutasColors.accentCobalt : Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
