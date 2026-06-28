import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';
import '../login_signup_screen.dart';

class VehicleProfileScreen extends StatelessWidget {
  final String vehicleName;
  final String vehicleRegNo;

  const VehicleProfileScreen({
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 24),
            _buildInfoSection(
              title: 'VEHICLE INFORMATION',
              icon: Icons.local_shipping_rounded,
              items: [
                _buildInfoRow('Bus Name', vehicleName),
                _buildInfoRow('Registration No', vehicleRegNo),
                _buildInfoRow('Model', 'Toyota Coaster (2022)'),
                _buildInfoRow('Fuel Type', 'Diesel'),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoSection(
              title: 'OPERATIONAL DETAILS',
              icon: Icons.settings_rounded,
              items: [
                _buildInfoRow('Assigned Route', 'Dynamic (Admin Managed)'),
                _buildInfoRow('Active Schedule', '07:30 AM - 04:30 PM'),
                _buildInfoRow('Assigned Driver', 'Muhammad Tariq'),
                _buildInfoRow('Terminal Point', 'COMSATS Main Gate'),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoSection(
              title: 'SECURITY',
              icon: Icons.security_rounded,
              items: [
                _buildPasswordResetRow(context),
              ],
            ),
            const SizedBox(height: 32),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: CommutasColors.primaryNavy,
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        children: [
          // Flat rectangular avatar container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CommutasColors.emeraldGreen.withOpacity(0.15),
              border: Border.all(color: CommutasColors.emeraldGreen, width: 2),
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              color: CommutasColors.emeraldGreen,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vehicleName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            vehicleRegNo,
            style: const TextStyle(
              color: CommutasColors.emeraldGreen,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> items,
  }) {
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
                Icon(icon, size: 16, color: CommutasColors.primaryNavy),
                const SizedBox(width: 8),
                Text(
                  title,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: items,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: CommutasTextStyles.bodyMedium.copyWith(
              color: CommutasColors.slateMuted,
            ),
          ),
          Text(
            value,
            style: CommutasTextStyles.labelBold.copyWith(
              fontSize: 13,
              color: CommutasColors.primaryNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordResetRow(BuildContext context) {
    return GestureDetector(
      onTap: () => _showResetPasswordBottomSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Reset Password',
              style: CommutasTextStyles.bodyMedium.copyWith(
                color: CommutasColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(
              Icons.lock_reset_rounded,
              color: CommutasColors.danger,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordBottomSheet(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RESET PASSWORD',
                style: CommutasTextStyles.heading2,
              ),
              const SizedBox(height: 8),
              Text(
                'Ensure your new password is secure.',
                style: CommutasTextStyles.bodySmall,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: CommutasColors.emeraldGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: CommutasColors.emeraldGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: CommutasColors.emeraldGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CommutasColors.primaryNavy,
                        side: const BorderSide(color: CommutasColors.lineBorder),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (newPasswordController.text != confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('New passwords do not match!')),
                          );
                          return;
                        }
                        if (newPasswordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password cannot be empty!')),
                          );
                          return;
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password reset successfully!'),
                            backgroundColor: CommutasColors.success,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CommutasColors.primaryNavy,
                        foregroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('RESET PASSWORD'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
