import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import 'services/biometric_service.dart';
import 'login_signup_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String studentName;
  final String studentRegNo;
  final String? lastEnteredPassword;

  const DashboardScreen({
    super.key,
    required this.studentName,
    required this.studentRegNo,
    this.lastEnteredPassword,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isBiometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricsStatus();
  }

  void _checkBiometricsStatus() async {
    final enabled = await _biometricService.isBiometricsEnabled();
    if (mounted) {
      setState(() {
        _isBiometricsEnabled = enabled;
      });
    }
  }

  void _setupBiometrics() async {
    final isAvailable = await _biometricService.isBiometricsAvailable();
    if (!isAvailable) {
      _setErrorDialog("Biometric authentication (fingerprint/face) is not supported or not enrolled on this device.");
      setState(() {
        _isBiometricsEnabled = false;
      });
      return;
    }

    String? password = widget.lastEnteredPassword;
    if (password == null || password.isEmpty) {
      password = await _promptForPasswordConfirmation();
      if (password == null || password.isEmpty) {
        setState(() {
          _isBiometricsEnabled = false;
        });
        return;
      }
    }

    final authenticated = await _biometricService.authenticate();
    if (authenticated) {
      await _biometricService.enableBiometrics(
        regNo: widget.studentRegNo,
        password: password,
        name: widget.studentName,
      );
      setState(() {
        _isBiometricsEnabled = true;
      });
      _showSuccessSnackBar("Biometric authentication enabled successfully!");
    } else {
      setState(() {
        _isBiometricsEnabled = false;
      });
      _showErrorSnackBar("Authentication failed. Biometrics not configured.");
    }
  }

  void _disableBiometrics() async {
    await _biometricService.disableBiometrics();
    setState(() {
      _isBiometricsEnabled = false;
    });
    _showSuccessSnackBar("Biometric authentication disabled.");
  }

  Future<String?> _promptForPasswordConfirmation() async {
    final TextEditingController confirmController = TextEditingController();
    bool obscureConfirm = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              backgroundColor: CommutasColors.white,
              title: Text(
                'Confirm App Password',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: CommutasColors.navyInk),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Enter your Commutas app password to enable biometric login.',
                    style: GoogleFonts.inter(color: CommutasColors.slateMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    style: CommutasTextStyles.fieldValue,
                    decoration: InputDecoration(
                      hintText: 'App password',
                      hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                      filled: true,
                      fillColor: CommutasColors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                      enabledBorder: CommutasShapes.inputBorder,
                      focusedBorder: CommutasShapes.inputFocusBorder,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility : Icons.visibility_off,
                          color: CommutasColors.slateMuted,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            obscureConfirm = !obscureConfirm;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                  child: Text('CANCEL', style: GoogleFonts.inter(color: CommutasColors.danger, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(context, null),
                ),
                TextButton(
                  style: TextButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
                  child: Text('CONFIRM', style: GoogleFonts.inter(color: CommutasColors.accentCobalt, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final pass = confirmController.text.trim();
                    Navigator.pop(context, pass.isEmpty ? null : pass);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _setErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text('Error', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: CommutasColors.danger)),
        content: Text(message, style: GoogleFonts.inter(color: CommutasColors.navyInk)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
            child: Text('OK', style: GoogleFonts.inter(color: CommutasColors.accentCobalt, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: CommutasColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: CommutasColors.danger,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('session_active', false);
    await prefs.remove('session_name');
    await prefs.remove('session_reg_no');
    await prefs.remove('session_role');
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginSignupScreen()),
      );
    }
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: CommutasColors.navyInk,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: EdgeInsets.zero,
        ),
        onPressed: onPressed,
        child: Text(
          label.toUpperCase(),
          style: CommutasTextStyles.buttonLabel,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'ST';
    final parts = name.split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Container(
          decoration: const BoxDecoration(
            color: CommutasColors.white,
            border: Border(
              bottom: BorderSide(
                color: CommutasColors.lineBorder,
                width: 1.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          alignment: Alignment.center,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/logo_theme_cropped.png',
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      'COMMUTAS',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: CommutasColors.navyInk,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: CommutasColors.success.withValues(alpha: 0.1),
                    border: Border.all(color: CommutasColors.success, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: CommutasColors.success,
                        size: 12,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'SECURE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: CommutasColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile details block
                    Container(
                      decoration: const BoxDecoration(
                        color: CommutasColors.white,
                        border: Border.fromBorderSide(
                          BorderSide(color: CommutasColors.lineBorder, width: 1.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Custom initials box avatar
                          Container(
                            height: 60,
                            width: 60,
                            decoration: BoxDecoration(
                              color: CommutasColors.navyInk,
                              border: Border.all(color: CommutasColors.accentCobalt, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _getInitials(widget.studentName),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: CommutasColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STUDENT PROFILE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: CommutasColors.slateMuted,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  widget.studentName,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: CommutasColors.navyInk,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  widget.studentRegNo,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: CommutasColors.accentCobalt,
                                  ),
                                ),
                                const SizedBox(height: 8.0),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_user_outlined,
                                      color: CommutasColors.success,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      'VERIFIED STUDENT',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: CommutasColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Biometrics setup card
                    Container(
                      decoration: const BoxDecoration(
                        color: CommutasColors.white,
                        border: Border.fromBorderSide(
                          BorderSide(color: CommutasColors.lineBorder, width: 1.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BIOMETRIC SETTINGS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: CommutasColors.slateMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          Row(
                            children: [
                              const Icon(
                                Icons.fingerprint_rounded,
                                size: 32,
                                color: CommutasColors.navyInk,
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Biometric Login',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: CommutasColors.navyInk,
                                      ),
                                    ),
                                    const SizedBox(height: 2.0),
                                    Text(
                                      'Enable fingerprint scan on startup for quick account validation.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: CommutasColors.slateMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isBiometricsEnabled,
                                activeThumbColor: CommutasColors.accentCobalt,
                                activeTrackColor: CommutasColors.accentCobalt.withValues(alpha: 0.3),
                                inactiveThumbColor: CommutasColors.slateMuted,
                                inactiveTrackColor: CommutasColors.lineBorder,
                                onChanged: (bool value) {
                                  if (value) {
                                    _setupBiometrics();
                                  } else {
                                    _disableBiometrics();
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: _isBiometricsEnabled 
                                  ? CommutasColors.success.withValues(alpha: 0.1)
                                  : CommutasColors.slateMuted.withValues(alpha: 0.1),
                              border: Border.all(
                                color: _isBiometricsEnabled ? CommutasColors.success : CommutasColors.lineBorder,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              _isBiometricsEnabled 
                                  ? 'BIOMETRIC RECOGNITION ACTIVE'
                                  : 'PASSWORD VALIDATION REQUIRED',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isBiometricsEnabled ? CommutasColors.success : CommutasColors.slateMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    // Log out actions
                    _buildPrimaryButton(
                      label: 'TERMINATE SESSION',
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom bar
            Container(
              height: 56,
              decoration: const BoxDecoration(
                color: CommutasColors.white,
                border: Border(
                  top: BorderSide(
                    color: CommutasColors.lineBorder,
                    width: 1.5,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.studentName}   ${widget.studentRegNo}',
                style: CommutasTextStyles.identityBar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
