import 'package:flutter/material.dart';
import 'dart:io';
import '../theme.dart';
import 'services/biometric_service.dart';

class HomeScreen extends StatefulWidget {
  final String studentName;
  final String studentRegNo;
  final String? password;
  final String? avatarPath;
  final bool isAsset;

  const HomeScreen({
    super.key,
    required this.studentName,
    required this.studentRegNo,
    this.password,
    this.avatarPath,
    this.isAsset = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricStatus();
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await _biometricService.isBiometricsEnabled();
    if (mounted) {
      setState(() => _isBiometricEnabled = enabled);
    }
  }

  Future<void> _toggleBiometrics() async {
    if (_isBiometricEnabled) {
      await _biometricService.disableBiometrics();
      setState(() => _isBiometricEnabled = false);
    } else {
      final success = await _biometricService.enableBiometrics(
        regNo: widget.studentRegNo,
        password: widget.password ?? '',
        name: widget.studentName,
      );
      if (mounted && success) {
        setState(() => _isBiometricEnabled = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStudentInfoCard(),
            const SizedBox(height: 16),
            _buildWalletCard(),
            const SizedBox(height: 16),
            _buildNfcPaymentCard(),
            const SizedBox(height: 16),
            _buildQuickStatsSection(),
            const SizedBox(height: 16),
            _buildBiometricControl(),
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
      leading: const Icon(Icons.menu, color: CommutasColors.primaryNavy),
      titleSpacing: 0,
      title: Row(
        children: [
          Image.asset(
            'assets/logo_theme_cropped.png',
            height: 24,
            errorBuilder: (_, __, ___) => const Icon(Icons.bus_alert, color: CommutasColors.emeraldGreen, size: 20),
          ),
          const SizedBox(width: 8),
          Text(
            'COMMUTAS',
            style: CommutasTextStyles.labelBold.copyWith(fontSize: 14, letterSpacing: 1),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: CommutasColors.lightGreenBg,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: CommutasColors.emeraldGreen.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: CommutasColors.emeraldGreen, size: 14),
              const SizedBox(width: 4),
              Text(
                'SECURE',
                style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, color: CommutasColors.emeraldGreen),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentInfoCard() {
    Widget avatarWidget;
    if (widget.avatarPath == null) {
      avatarWidget = const Icon(Icons.person, size: 40, color: CommutasColors.primaryNavy);
    } else if (widget.isAsset) {
      avatarWidget = Image.asset(widget.avatarPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person));
    } else {
      avatarWidget = Image.file(File(widget.avatarPath!), fit: BoxFit.cover);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: CommutasColors.backgroundGray,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: CommutasColors.lineBorder, width: 1),
            ),
            child: avatarWidget,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Good Morning 👋", style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted)),
                const SizedBox(height: 4),
                Text(widget.studentName, style: CommutasTextStyles.heading1.copyWith(fontSize: 24)),
                Text(widget.studentRegNo, style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.slateMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: CommutasColors.slateMuted),
          const SizedBox(width: 4),
          Text(text, style: CommutasTextStyles.bodySmall),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CommutasColors.lightGreenBg,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: CommutasColors.emeraldGreen.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wallet Balance', style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted)),
                  const SizedBox(height: 8),
                  Text('Rs. 620.00', style: CommutasTextStyles.heading1.copyWith(fontSize: 32, color: CommutasColors.primaryNavy)),
                ],
              ),
              Icon(Icons.wallet, color: CommutasColors.emeraldGreen.withOpacity(0.8), size: 48),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Funds'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: CommutasColors.primaryNavy,
                  side: const BorderSide(color: CommutasColors.primaryNavy),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: const Text('View Wallet'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNfcPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CommutasColors.primaryNavy,
        borderRadius: CommutasShapes.cardRadius,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tap To Pay', style: CommutasTextStyles.heading2.copyWith(color: Colors.white)),
                  Text('Hold phone near reader', style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white70)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CommutasColors.emeraldGreen,
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(Icons.contactless, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Wave pattern animation simulator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 4,
                height: 16 + (index * 8.0),
                decoration: BoxDecoration(
                  color: CommutasColors.emeraldGreen.withOpacity(0.3 + (index * 0.2)),
                  borderRadius: BorderRadius.zero,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NFC Status', style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white60)),
                Text('READY', style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.emeraldGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection() {
    return Row(
      children: [
        _buildSmallStat('Last Trip', 'Today, 8:05 AM', Icons.directions_bus),
        const SizedBox(width: 8),
        _buildSmallStat('Trips Taken', '12', Icons.confirmation_number),
        const SizedBox(width: 8),
        _buildSmallStat('Total Spent', 'Rs. 600', Icons.payments),
        const SizedBox(width: 8),
        _buildSmallStat('Savings', 'Rs. 120', Icons.eco),
      ],
    );
  }

  Widget _buildSmallStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: CommutasShapes.cardDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: CommutasColors.primaryNavy, size: 20),
            const SizedBox(height: 10),
            Text(
              label, 
              textAlign: TextAlign.center,
              style: CommutasTextStyles.labelBold.copyWith(fontSize: 9, color: CommutasColors.slateMuted)
            ),
            const SizedBox(height: 4),
            Text(
              value, 
              textAlign: TextAlign.center,
              style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricControl() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CommutasShapes.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CommutasColors.lightGreenBg,
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(Icons.fingerprint, color: CommutasColors.emeraldGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Biometric Auth', style: CommutasTextStyles.labelBold),
                Text('Secure checkout enabled', style: CommutasTextStyles.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isBiometricEnabled,
            activeColor: CommutasColors.emeraldGreen,
            onChanged: (val) => _toggleBiometrics(),
          ),
        ],
      ),
    );
  }
}
