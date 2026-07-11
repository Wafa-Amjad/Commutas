import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'schedule_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'nfc_pay_screen.dart';
import 'vehicle/vehicle_home_screen.dart';
import 'vehicle/vehicle_collect_tab_screen.dart';
import 'vehicle/vehicle_profile_screen.dart';

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
  bool _isProfileLoading = false;
  String _profileLoadingTitle = '';
  String _profileLoadingMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.role == 'student') {
      _loadProfileAndAvatar();
    }
  }

  Future<void> _loadProfileAndAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      if (token.isNotEmpty) {
        final authService = AuthService();
        final profile = await authService.getStudentProfile(token: token);
        if (profile != null && mounted) {
          final avatarUrl = profile['avatar_url'];
          setState(() {
            if (avatarUrl != null) {
              _avatarPath = avatarUrl;
              _avatarType = 'url';
            } else {
              _avatarPath = null;
              _avatarType = 'emoji';
            }
          });
        }
      }
    } catch (_) {}
  }

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

  void _onProfileLoadingChanged(bool isLoading, String? title, String? message) {
    setState(() {
      _isProfileLoading = isLoading;
      _profileLoadingTitle = title ?? '';
      _profileLoadingMessage = message ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = widget.role == 'vehicle'
        ? [
            VehicleHomeScreen(
              vehicleName: widget.studentName,
              vehicleRegNo: widget.studentRegNo,
              onNavigateToTab: _onItemTapped,
            ),
            VehicleCollectTabScreen(onNavigateToTab: _onItemTapped),
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
              onNavigateToTab: _onItemTapped,
              activeIndex: _selectedIndex,
            ),
            const ScheduleScreen(),
            NFCPayScreen(onNavigateToTab: _onItemTapped),
            WalletScreen(
              studentRegNo: widget.studentRegNo,
              activeIndex: _selectedIndex,
            ),
            ProfileScreen(
              studentName: widget.studentName,
              studentRegNo: widget.studentRegNo,
              initialAvatarPath: _avatarPath,
              initialAvatarType: _avatarType,
              onAvatarChanged: _onAvatarChanged,
              password: widget.lastEnteredPassword,
              onLoadingChanged: _onProfileLoadingChanged,
            ),
          ];

    return Stack(
      children: [
        Scaffold(
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
                  children: widget.role == 'vehicle'
                      ? [
                          _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                          _buildNfcNavItem(),
                          _buildNavItem(2, Icons.person_rounded, 'Profile'),
                        ]
                      : [
                          _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                          _buildNavItem(1, Icons.commute_rounded, 'Schedule'),
                          _buildNfcNavItem(),
                          _buildNavItem(3, Icons.wallet_rounded, 'Wallet'),
                          _buildNavItem(4, Icons.person_rounded, 'Profile'),
                        ],
                ),
              ),
            ),
          ),
        ),
        if (_isProfileLoading)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                color: CommutasColors.primaryNavy.withOpacity(0.40),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: BusUploadLoadingDialog(
                      title: _profileLoadingTitle,
                      message: _profileLoadingMessage,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
    final targetIndex = widget.role == 'vehicle' ? 1 : 2;
    final isSelected = _selectedIndex == targetIndex;
    return GestureDetector(
      onTap: () => _onItemTapped(targetIndex),
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
