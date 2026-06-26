import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../theme.dart';
import 'avatar_selection_screen.dart';
import 'login_signup_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String studentName;
  final String studentRegNo;
  final String? initialAvatarPath;
  final bool initialIsAsset;
  final Function(String?, bool) onAvatarChanged;

  const ProfileScreen({
    super.key,
    required this.studentName,
    required this.studentRegNo,
    this.initialAvatarPath,
    this.initialIsAsset = true,
    required this.onAvatarChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String? _avatarPath;
  late bool _isAsset;

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.initialAvatarPath;
    _isAsset = widget.initialIsAsset;
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarSelectionScreen(currentAvatarPath: _isAsset ? _avatarPath : null),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _isAsset = result['type'] == 'asset';
        _avatarPath = result['path'];
      });
      widget.onAvatarChanged(_avatarPath, _isAsset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String email = "${widget.studentRegNo}@cuiatd.edu.pk";

    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 24),
            _buildInfoSection('Academic Records', [
              _buildInfoRow(Icons.school, 'Department', 'Computer Science'),
              _buildInfoRow(Icons.calendar_view_day, 'Semester', '4th Semester'),
              _buildInfoRow(Icons.email, 'Email (Portal)', email),
            ]),
            const SizedBox(height: 20),
            _buildInfoSection('Identification', [
              _buildInfoRow(Icons.account_box, 'Reg No', widget.studentRegNo),
              _buildInfoRow(Icons.person, 'Gender', 'Fetching...'),
            ]),
            const SizedBox(height: 32),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    Widget avatarChild;
    if (_avatarPath == null) {
      avatarChild = const Icon(Icons.person, size: 60, color: CommutasColors.primaryNavy);
    } else if (_isAsset) {
      avatarChild = Image.asset(_avatarPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60));
    } else {
      avatarChild = Image.file(File(_avatarPath!), fit: BoxFit.cover);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: CommutasShapes.cardDecoration,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: CommutasColors.cobaltTint,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(color: CommutasColors.accentCobalt, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: avatarChild,
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () => _changeAvatar(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: CommutasColors.accentCobalt,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.studentName, style: CommutasTextStyles.heading1.copyWith(fontSize: 22)),
              const SizedBox(width: 8),
              const Icon(Icons.verified, color: Colors.blue, size: 20),
            ],
          ),
          Text(widget.studentRegNo, style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.accentCobalt)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(title.toUpperCase(), style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, color: CommutasColors.slateMuted)),
        ),
        Container(
          decoration: CommutasShapes.cardDecoration,
          child: Column(
            children: List.generate(items.length, (index) {
              return Column(
                children: [
                  items[index],
                  if (index != items.length - 1)
                    const Divider(height: 1, color: CommutasColors.lineBorder, indent: 50),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: CommutasColors.primaryNavy.withOpacity(0.5), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CommutasTextStyles.bodySmall),
                const SizedBox(height: 2),
                Text(value, style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: CommutasColors.lineBorder, size: 20),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: CommutasColors.primaryNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
            child: const Text('Edit Profile'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('session_active', false);
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginSignupScreen()),
                  (route) => false,
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: CommutasColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Logout Session'),
          ),
        ),
      ],
    );
  }
}
