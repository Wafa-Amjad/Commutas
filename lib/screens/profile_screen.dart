import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/biometric_service.dart';
import 'reset_password_screen.dart';
import 'login_signup_screen.dart';
import 'services/route_service.dart';
import 'services/auth_service.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';

class ProfileScreen extends StatefulWidget {
  final String studentName;
  final String studentRegNo;
  final String? initialAvatarPath;
  final String initialAvatarType; // 'emoji', 'file'
  final Function(String?, String) onAvatarChanged;
  final String? password;
  final Function(bool, String?, String?)? onLoadingChanged;

  const ProfileScreen({
    super.key,
    required this.studentName,
    required this.studentRegNo,
    this.initialAvatarPath,
    this.initialAvatarType = 'emoji',
    required this.onAvatarChanged,
    this.password,
    this.onLoadingChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String? _avatarPath;
  late String _avatarType;
  String _avatarCacheBuster = '';

  final BiometricService _biometricService = BiometricService();
  bool _isBiometricEnabled = false;

  String? _accessToken;
  String? _preferredRouteId;
  String? _preferredRouteName;
  List<Map<String, dynamic>> _availableRoutes = [];

  @override
  void initState() {
    super.initState();
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
        _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      });
    }

    if (token.isNotEmpty) {
      _fetchProfileData(token);
    }
  }

  Future<void> _fetchProfileData(String token) async {
    try {
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
        widget.onAvatarChanged(_avatarPath, _avatarType);
      }
    } catch (_) {}
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
      final bytes = await image.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image size must be less than 2MB.')),
          );
        }
        return;
      }

      widget.onLoadingChanged?.call(true, 'UPLOADING PICTURE', 'Updating your profile pass photo...');

      try {
        final authService = AuthService();
        final avatarUrl = await authService.uploadAvatar(
          token: _accessToken ?? '',
          imageBytes: bytes,
          fileName: image.name,
        );

        if (avatarUrl != null && mounted) {
          setState(() {
            _avatarType = 'url';
            _avatarPath = avatarUrl;
            _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
          });
          widget.onAvatarChanged(_avatarPath, _avatarType);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture uploaded successfully.')),
            );
          }
        } else {
          throw Exception('Upload returned empty URL');
        }
      } catch (e) {
        developer.log('Profile image upload failed: $e', name: 'ProfileScreen');
        String errorMsg = 'Failed to upload profile picture. Please try again.';
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout || 
              e.type == DioExceptionType.receiveTimeout || 
              e.type == DioExceptionType.connectionError) {
            errorMsg = 'No internet connection. Please check your network and try again.';
          } else if (e.response?.data?['detail'] != null) {
            errorMsg = e.response!.data['detail'].toString();
          }
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
      } finally {
        widget.onLoadingChanged?.call(false, null, null);
      }
    }
  }

  Future<void> _deleteAvatar(BuildContext context) async {
    widget.onLoadingChanged?.call(true, 'REMOVING PICTURE', 'Clearing your profile pass photo...');

    try {
      final authService = AuthService();
      final success = await authService.deleteAvatar(token: _accessToken ?? '');

      if (success && mounted) {
        setState(() {
          _avatarType = 'emoji';
          _avatarPath = null;
          _avatarCacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
        });
        widget.onAvatarChanged(_avatarPath, _avatarType);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture removed successfully.')),
          );
        }
      } else {
        throw Exception('Delete failed on server');
      }
    } catch (e) {
      developer.log('Profile image deletion failed: $e', name: 'ProfileScreen');
      String errorMsg = 'Failed to remove profile picture. Please try again.';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout || 
            e.type == DioExceptionType.receiveTimeout || 
            e.type == DioExceptionType.connectionError) {
          errorMsg = 'No internet connection. Please check your network and try again.';
        } else if (e.response?.data?['detail'] != null) {
          errorMsg = e.response!.data['detail'].toString();
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } finally {
      widget.onLoadingChanged?.call(false, null, null);
    }
  }

  void _showAvatarOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (context) {
        final hasPhoto = _avatarPath != null && _avatarType == 'url';
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: CommutasColors.primaryNavy),
                title: Text('Upload Photo', style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _changeAvatar(context);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: CommutasColors.danger),
                  title: Text('Remove Photo', style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.danger, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteAvatar(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: CommutasColors.slateMuted),
                title: Text('Cancel', style: CommutasTextStyles.bodyMedium),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
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
    } else if (_avatarType == 'url') {
      avatarChild = Image.network(
        '$_avatarPath?t=$_avatarCacheBuster',
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: CommutasColors.emeraldGreen, strokeWidth: 2),
          );
        },
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 64, color: CommutasColors.primaryNavy),
      );
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
                      onTap: () => _showAvatarOptions(context),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
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
                                bottom: -4,
                                right: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: CommutasColors.accentCobalt,
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Edit Photo',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
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


// ──────────────────────────────────────────────────────────
// Custom Uploading Dialog with Bouncing Bus animation
// ──────────────────────────────────────────────────────────
class BusUploadLoadingDialog extends StatefulWidget {
  final String title;
  final String message;

  const BusUploadLoadingDialog({
    this.title = 'UPLOADING PICTURE',
    this.message = 'Updating your profile pass photo...',
  });

  @override
  State<BusUploadLoadingDialog> createState() => _BusUploadLoadingDialogState();
}

class _BusUploadLoadingDialogState extends State<BusUploadLoadingDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CommutasColors.lineBorder, width: 1)),
      ),
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 40,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          SizedBox(
            width: 120,
            height: 80,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: UploadBusPainter(animationValue: _controller.value),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: CommutasTextStyles.labelBold.copyWith(letterSpacing: 1.5, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            style: CommutasTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            height: 3,
            color: CommutasColors.lightGreenBg,
            child: const LinearProgressIndicator(
              backgroundColor: CommutasColors.lightGreenBg,
              valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.emeraldGreen),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class UploadBusPainter extends CustomPainter {
  final double animationValue;

  UploadBusPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CommutasColors.navyInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bounce = math.sin(animationValue * 2 * math.pi) * 2.0;

    final double top = 10.0 + bounce;
    final double bottom = size.height - 20.0 + bounce;
    final double left = 10.0;
    final double right = size.width - 10.0;

    final bodyBasePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), bodyBasePaint);

    final fillPaint = Paint()
      ..color = CommutasColors.emeraldGreen.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), fillPaint);

    final stripePaint = Paint()
      ..color = CommutasColors.emeraldGreen
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left + 2, bottom - 14, right - 2, bottom - 8), stripePaint);

    final windowFillPaint = Paint()
      ..color = const Color(0xFFE8F5E9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left + 8, top + 6, left + 24, top + 18), windowFillPaint);

    for (int i = 0; i < 3; i++) {
      final double wx = left + 32.0 + i * 20.0;
      canvas.drawRect(Rect.fromLTWH(wx, top + 6, 14, 12), windowFillPaint);
    }

    final lightConePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(left, bottom - 10),
        Offset(left - 30, bottom - 10),
        [
          Colors.orangeAccent.withOpacity(0.45),
          Colors.orangeAccent.withOpacity(0.0),
        ],
      )
      ..style = PaintingStyle.fill;
    final lightPath = Path()
      ..moveTo(left, bottom - 10)
      ..lineTo(left - 30, bottom - 22)
      ..lineTo(left - 30, bottom + 2)
      ..close();
    canvas.drawPath(lightPath, lightConePaint);

    canvas.drawLine(Offset(left, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);

    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 24, top + 6), paint);
    canvas.drawLine(Offset(left + 24, top + 6), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 18), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 8, top + 18), paint);

    for (int i = 0; i < 3; i++) {
      final double wx = left + 32.0 + i * 20.0;
      canvas.drawRect(Rect.fromLTWH(wx, top + 6, 14, 12), paint);
    }

    canvas.drawLine(Offset(left, bottom - 10), Offset(left - 4, bottom - 10), paint);
    final rayPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 14), rayPaint);
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 6), rayPaint);

    canvas.drawLine(Offset(left - 4, bottom - 2), Offset(left + 4, bottom - 2), paint);
    canvas.drawLine(Offset(right - 4, bottom - 2), Offset(right + 4, bottom - 2), paint);

    final double wheelRadius = 8.0;
    final double leftWheelX = left + 20.0;
    final double rightWheelX = right - 20.0;
    final double wheelY = bottom + 8.0 - bounce;

    final wheelFill = Paint()
      ..color = CommutasColors.primaryNavy
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(leftWheelX, wheelY), wheelRadius - 1.0, wheelFill);
    canvas.drawCircle(Offset(leftWheelX, wheelY), wheelRadius, paint);
    
    final angle = animationValue * 2 * math.pi;
    final spokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      spokePaint,
    );
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      spokePaint,
    );

    canvas.drawCircle(Offset(rightWheelX, wheelY), wheelRadius - 1.0, wheelFill);
    canvas.drawCircle(Offset(rightWheelX, wheelY), wheelRadius, paint);
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      spokePaint,
    );
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      spokePaint,
    );

    final smokePaint = Paint()
      ..color = CommutasColors.slateMuted.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final smokeOutline = Paint()
      ..color = CommutasColors.slateMuted.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final double exhaustX = right + 2;
    final double exhaustY = bottom - 4 + bounce;

    final double p1X = exhaustX + 8.0 + math.sin(animationValue * 3 * math.pi) * 2.0;
    final double p1Y = exhaustY - 4.0 - (animationValue * 10.0);
    final double p1R = 4.0 + (animationValue * 3.0);
    canvas.drawCircle(Offset(p1X, p1Y), p1R, smokePaint);
    canvas.drawCircle(Offset(p1X, p1Y), p1R, smokeOutline);

    final double p2Val = (animationValue + 0.5) % 1.0;
    final double p2X = exhaustX + 16.0 + math.cos(p2Val * 2 * math.pi) * 3.0;
    final double p2Y = exhaustY - 8.0 - (p2Val * 14.0);
    final double p2R = 3.5 + (p2Val * 4.0);
    canvas.drawCircle(Offset(p2X, p2Y), p2R, smokePaint);
    canvas.drawCircle(Offset(p2X, p2Y), p2R, smokeOutline);

    final double p3Val = (animationValue + 0.25) % 1.0;
    final double p3X = exhaustX + 22.0 + math.sin(p3Val * 4 * math.pi) * 2.5;
    final double p3Y = exhaustY - 12.0 - (p3Val * 16.0);
    final double p3R = 3.0 + (p3Val * 5.0);
    final fadedSmoke = Paint()
      ..color = CommutasColors.slateMuted.withOpacity(0.12 * (1.0 - p3Val))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(p3X, p3Y), p3R, fadedSmoke);
  }

  @override
  bool shouldRepaint(covariant UploadBusPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

