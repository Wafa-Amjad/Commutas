import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../theme.dart';
import 'package:image_picker/image_picker.dart';
import 'services/biometric_service.dart';
import 'reset_password_screen.dart';
import 'login_signup_screen.dart';
import 'services/route_service.dart';

class ProfileScreen extends StatefulWidget {
  final String studentName;
  final String studentRegNo;
  final String? initialAvatarPath;
  final String initialAvatarType; // 'emoji', 'file'
  final Function(String?, String) onAvatarChanged;
  final String? password;

  const ProfileScreen({
    super.key,
    required this.studentName,
    required this.studentRegNo,
    this.initialAvatarPath,
    this.initialAvatarType = 'emoji',
    required this.onAvatarChanged,
    this.password,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String? _avatarPath;
  late String _avatarType;

  final BiometricService _biometricService = BiometricService();
  bool _isBiometricEnabled = false;

  String? _accessToken;
  String? _preferredRouteId;
  String? _preferredRouteName;
  List<Map<String, dynamic>> _availableRoutes = [];

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.initialAvatarPath;
    _avatarType = widget.initialAvatarType;
    _loadBiometricStatus();
    _loadPreferences().then((_) {
      _fetchRoutesAndResolve();
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('session_token') ?? '';
    final preferredRouteId = prefs.getString('session_preferred_route_id');
    
    if (mounted) {
      setState(() {
        _accessToken = token;
        _preferredRouteId = preferredRouteId;
      });
    }
  }

  Future<void> _fetchRoutesAndResolve() async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    final routeService = RouteService();
    final routes = await routeService.fetchRoutes(token: _accessToken!);
    if (routes.isNotEmpty && mounted) {
      setState(() {
        _availableRoutes = routes;
      });
      _resolveRouteName();
    }
  }

  void _resolveRouteName() {
    if (_preferredRouteId == null || _availableRoutes.isEmpty) return;
    final match = _availableRoutes.firstWhere(
      (r) => r['id'] == _preferredRouteId,
      orElse: () => {},
    );
    if (match.isNotEmpty && mounted) {
      setState(() {
        _preferredRouteName = match['name'];
      });
    }
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await _biometricService.isBiometricsEnabled();
    if (mounted) {
      setState(() => _isBiometricEnabled = enabled);
    }
  }

  Future<void> _toggleBiometrics() async {
    final authenticated = await _biometricService.authenticate();
    if (!authenticated) return;

    if (_isBiometricEnabled) {
      await _biometricService.disableBiometrics();
      setState(() => _isBiometricEnabled = false);
    } else {
      final success = await _biometricService.enableBiometrics(
        regNo: widget.studentRegNo,
        password: widget.password ?? '',
        name: widget.studentName,
      );
      if (success && mounted) {
        setState(() => _isBiometricEnabled = true);
      }
    }
  }

  Future<void> _changeAvatar(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() {
        _avatarType = 'file';
        _avatarPath = image.path;
      });
      widget.onAvatarChanged(_avatarPath, _avatarType);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _buildDigitalTransitCard(context),
            const SizedBox(height: 24),
            _buildTransitPreferencesSection(),
            _buildRoadDivider(),
            _buildSecuritySection(),
            _buildRoadDivider(),
            _buildActionButtons(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 12,
        width: double.infinity,
        child: const CustomPaint(
          painter: _RoadDividerPainter(),
        ),
      ),
    );
  }

  Widget _buildDigitalTransitCard(BuildContext context) {
    Widget avatarChild;
    if (_avatarPath == null || _avatarType == 'emoji') {
      avatarChild = const Icon(Icons.person, size: 64, color: CommutasColors.primaryNavy);
    } else {
      avatarChild = Image.file(File(_avatarPath!), fit: BoxFit.cover);
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: CommutasColors.primaryNavy,
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        children: [
          // Subtle transport-themed pattern background
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(
                painter: _TransportPatternPainter(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // Profile Area
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => _changeAvatar(context),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: CommutasColors.white,
                              borderRadius: BorderRadius.zero,
                              border: Border.all(color: CommutasColors.emeraldGreen, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.zero,
                              child: avatarChild,
                            ),
                          ),
                          Positioned(
                            bottom: -6,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: CommutasColors.accentCobalt,
                                borderRadius: BorderRadius.zero,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _formatStudentName(widget.studentName),
                                  style: CommutasTextStyles.heading1.copyWith(
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Colors.blue, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.studentRegNo,
                            style: CommutasTextStyles.labelBold.copyWith(
                              color: Colors.white70,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Large NFC icon on right
                    const Icon(
                      Icons.contactless,
                      color: CommutasColors.emeraldGreen,
                      size: 40,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Bottom Label
                Center(
                  child: Column(
                    children: [
                      Text(
                        'STUDENT BUS PASS',
                        style: CommutasTextStyles.labelBold.copyWith(
                          color: CommutasColors.emeraldGreen,
                          letterSpacing: 2,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap & Travel with Ease',
                        style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white54, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatStudentName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0];
    final firstName = parts[0];
    final lastPart = parts[parts.length - 1];
    if (lastPart.isEmpty) return firstName;
    return '$firstName ${lastPart[0]}.';
  }

  void _showRouteSelectionDialog() {
    if (_availableRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading routes from server... Please wait.')),
      );
      _fetchRoutesAndResolve();
      return;
    }

    final morningRoutes = _availableRoutes.where((route) {
      final startLoc = route['start_location'] as String? ?? '';
      final rId = route['id'] as String? ?? '';
      return startLoc.toLowerCase().contains('main') && !rId.endsWith('-REV');
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Preferred Route',
                  style: CommutasTextStyles.heading2.copyWith(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: morningRoutes.length,
                  itemBuilder: (context, index) {
                    final route = morningRoutes[index];
                    final routeId = route['id'];
                    final routeName = route['name'];
                    final isSelected = routeId == _preferredRouteId;

                    return ListTile(
                      title: Text(
                        routeName,
                        style: CommutasTextStyles.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? CommutasColors.emeraldGreen : CommutasColors.primaryNavy,
                        ),
                      ),
                      leading: Icon(
                        Icons.directions_bus_filled,
                        color: isSelected ? CommutasColors.emeraldGreen : CommutasColors.slateMuted,
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: CommutasColors.emeraldGreen)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _updatePreferredRoute(routeId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updatePreferredRoute(String routeId) async {
    if (_accessToken == null || _accessToken!.isEmpty) return;

    final routeService = RouteService();
    final success = await routeService.savePreferredRoute(
      token: _accessToken!,
      routeId: routeId,
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_preferred_route_id', routeId);
      
      if (mounted) {
        setState(() {
          _preferredRouteId = routeId;
        });
      }
      _resolveRouteName();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferred route updated successfully.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update preferred route. Please try again.')),
        );
      }
    }
  }

  Widget _buildTransitPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Transit Preferences', style: CommutasTextStyles.heading2.copyWith(fontSize: 16)),
        ),
        Container(
          decoration: CommutasShapes.cardDecoration,
          child: Column(
            children: [
              _buildClickableRow(
                icon: Icons.directions_bus,
                title: 'Configure Preferred Route',
                subtitle: null,
                onTap: _showRouteSelectionDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('Security', style: CommutasTextStyles.heading2.copyWith(fontSize: 16)),
        ),
        Container(
          decoration: CommutasShapes.cardDecoration,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          Text('Biometric Login', style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Enable fingerprint for quick sign-in', style: CommutasTextStyles.bodySmall),
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
              ),
              const Divider(height: 1, color: CommutasColors.lineBorder, indent: 16),
              _buildClickableRow(
                icon: Icons.lock,
                title: 'Change App Password',
                subtitle: null,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResetPasswordScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClickableRow({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: CommutasColors.lightGreenBg,
                borderRadius: BorderRadius.zero,
              ),
              child: Icon(icon, color: CommutasColors.emeraldGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: CommutasTextStyles.bodySmall),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: CommutasColors.lineBorder, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
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
        style: OutlinedButton.styleFrom(
          foregroundColor: CommutasColors.danger,
          side: BorderSide(color: CommutasColors.danger.withOpacity(0.8), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: Text('LOGOUT SESSION', style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.danger)),
      ),
    );
  }
}

// Background pattern painter for the transit card
class _TransportPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double step = 20.0;
    
    // Draw diagonal grid lines
    for (double i = -size.height; i < size.width; i += step) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
    
    // Draw circles at intersections randomly to represent nodes/stops
    final fillPaint = Paint()..color = Colors.white;
    for (double x = 0; x < size.width; x += step * 2) {
      for (double y = 0; y < size.height; y += step * 2) {
        if ((x + y) % 3 == 0) { // arbitrary condition for sparsity
          canvas.drawCircle(Offset(x, y), 2, fillPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoadDividerPainter extends CustomPainter {
  const _RoadDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.lineBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final double y = size.height / 2;
    const double dashWidth = 14.0;
    const double gapWidth = 10.0;
    double x = 0;

    while (x < size.width) {
      // Slight vertical wobble for hand-drawn feel
      final double wobble = math.sin(x * 0.3) * 0.8;
      canvas.drawLine(
        Offset(x, y + wobble),
        Offset(math.min(x + dashWidth, size.width), y - wobble),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadDividerPainter oldDelegate) => false;
}

