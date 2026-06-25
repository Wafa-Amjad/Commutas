import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import 'verification_screen.dart';
import 'services/biometric_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final BiometricService _biometricService = BiometricService();
  // Shared inputs for Student Reg No construction
  String _selectedSession = 'FA23';
  String _selectedDept = 'BCS';
  final TextEditingController _rollNoController = TextEditingController();

  // Reset inputs
  final TextEditingController _portalPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePortalPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Error message
  String? _errorMessage;
  Timer? _errorDismissTimer;

  static const List<String> _sessions = [
    'FA01', 'FA02', 'FA03', 'FA04', 'FA05', 'FA06', 'FA07', 'FA08', 'FA09', 'FA10',
    'FA11', 'FA12', 'FA13', 'FA14', 'FA15', 'FA16', 'FA17', 'FA18', 'FA19', 'FA20',
    'FA21', 'FA22', 'FA23', 'FA24', 'FA25', 'SP02', 'SP03', 'SP04', 'SP05', 'SP06',
    'SP07', 'SP08', 'SP09', 'SP10', 'SP11', 'SP12', 'SP13', 'SP14', 'SP15', 'SP16',
    'SP17', 'SP18', 'SP19', 'SP20', 'SP21', 'SP22', 'SP23', 'SP24', 'SP25', 'SP26',
    'WS26'
  ];

  static const List<String> _departments = [
    'BBA', 'BBS', 'BCE', 'BCS', 'BDA', 'BDS', 'BEC', 'BEE', 'BEN', 'BES', 'BIT', 'BMD',
    'BML', 'BMT', 'BPY', 'BS (CE)', 'BSE', 'BSM', 'BTN', 'BTY', 'CVE', 'EEE', 'EPE',
    'ERS', 'GEO', 'HUM', 'MBA', 'MCS', 'MDS', 'MIT', 'PBT', 'PCE', 'PCM', 'PCS', 'PCV',
    'PDS', 'PEE', 'PES', 'PGO', 'PGP', 'PHM', 'PMS', 'PMT', 'PPY', 'R05', 'RAI', 'RBA',
    'RBF', 'RBT', 'RCE', 'RCM', 'RCP', 'RCS', 'RCT', 'RCV', 'RDS', 'REC', 'REE', 'REN',
    'RER', 'RES', 'RMB', 'RMS', 'RMT', 'RPM', 'RPY', 'RSW'
  ];

  @override
  void initState() {
    super.initState();
    _rollNoController.addListener(_onInputChanged);
    _newPasswordController.addListener(_onInputChanged);
    _confirmPasswordController.addListener(_onInputChanged);
    _portalPasswordController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _rollNoController.dispose();
    _portalPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _errorDismissTimer?.cancel();
    super.dispose();
  }

  void _onInputChanged() {
    _errorDismissTimer?.cancel();
    setState(() {
      _errorMessage = null;
    });
  }

  void _setError(String message) {
    _errorDismissTimer?.cancel();
    setState(() {
      _errorMessage = message;
    });
    _errorDismissTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    });
  }

  // Validate values for reset checklist
  bool get _hasEightChars => _newPasswordController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[a-zA-Z]').hasMatch(_newPasswordController.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_newPasswordController.text);
  bool get _passwordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  bool get _isResetValid {
    final rollNo = _rollNoController.text.trim();
    if (rollNo.isEmpty || !RegExp(r'^\d{1,3}$').hasMatch(rollNo)) return false;
    if (_portalPasswordController.text.isEmpty) return false;
    if (!_hasEightChars || !_hasLetter || !_hasDigit) return false;
    if (!_passwordsMatch) return false;
    return true;
  }

  void _handleResetPassword() async {
    if (!_isResetValid) return;

    final String fullRegNo = "$_selectedSession-$_selectedDept-${_rollNoController.text.trim().padLeft(3, '0')}";
    final String portalPassword = _portalPasswordController.text.trim();
    final String newPassword = _newPasswordController.text.trim();

    // Navigate to verification screen in reset password mode
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(
          regNo: fullRegNo,
          portalPassword: portalPassword,
          appPassword: newPassword,
          isReset: true,
        ),
      ),
    );

    if (mounted) {
      if (result == true) {
        await _biometricService.disableBiometrics();
        if (mounted) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8.0, bottom: 24.0, left: 20.0, right: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand navigation header
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: CommutasColors.primaryNavy),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'PASSWORD RECOVERY',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: CommutasColors.primaryNavy,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Main card containing inputs
                    Container(
                      decoration: BoxDecoration(
                        color: CommutasColors.white,
                        border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/logo_theme_cropped.png',
                                height: 40,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'SECURITY RECOVERY',
                                      style: CommutasTextStyles.sectionEyebrow,
                                    ),
                                    const SizedBox(height: 4.0),
                                    Text(
                                      'Reset app password',
                                      style: CommutasTextStyles.cardTitle,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24.0),

                          // Reg No construction
                          Text(
                            'Registration number',
                            style: CommutasTextStyles.fieldLabel,
                          ),
                          const SizedBox(height: 6.0),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildDropdown(
                                  value: _selectedSession,
                                  items: _sessions,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedSession = val!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                flex: 3,
                                child: _buildDropdown(
                                  value: _selectedDept,
                                  items: _departments,
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedDept = val!;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Expanded(
                                flex: 4,
                                child: SizedBox(
                                  height: 48.0,
                                  child: TextFormField(
                                    controller: _rollNoController,
                                    maxLength: 3,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    style: CommutasTextStyles.fieldValue,
                                    decoration: InputDecoration(
                                      counterText: "",
                                      hintText: '000',
                                      hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                                      filled: true,
                                      fillColor: CommutasColors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 11.0),
                                      enabledBorder: CommutasShapes.inputBorder,
                                      focusedBorder: CommutasShapes.inputFocusBorder,
                                      errorBorder: CommutasShapes.inputErrorBorder,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),

                          // Portal password
                          Text(
                            'Portal password',
                            style: CommutasTextStyles.fieldLabel,
                          ),
                          const SizedBox(height: 6.0),
                          TextFormField(
                            controller: _portalPasswordController,
                            obscureText: _obscurePortalPassword,
                            style: CommutasTextStyles.fieldValue,
                            decoration: InputDecoration(
                              hintText: 'Enter university portal password',
                              hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                              filled: true,
                              fillColor: CommutasColors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                              enabledBorder: CommutasShapes.inputBorder,
                              focusedBorder: CommutasShapes.inputFocusBorder,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePortalPassword ? Icons.visibility : Icons.visibility_off,
                                  color: CommutasColors.slateMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePortalPassword = !_obscurePortalPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          // New App password
                          Text(
                            'New App password',
                            style: CommutasTextStyles.fieldLabel,
                          ),
                          const SizedBox(height: 6.0),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            style: CommutasTextStyles.fieldValue,
                            decoration: InputDecoration(
                              hintText: 'Enter new app password',
                              hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                              filled: true,
                              fillColor: CommutasColors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                              enabledBorder: CommutasShapes.inputBorder,
                              focusedBorder: CommutasShapes.inputFocusBorder,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                                  color: CommutasColors.slateMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),

                          // Confirm App password
                          Text(
                            'Confirm App password',
                            style: CommutasTextStyles.fieldLabel,
                          ),
                          const SizedBox(height: 6.0),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: CommutasTextStyles.fieldValue,
                            decoration: InputDecoration(
                              hintText: 'Re-enter new app password',
                              hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                              filled: true,
                              fillColor: CommutasColors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                              enabledBorder: CommutasShapes.inputBorder,
                              focusedBorder: CommutasShapes.inputFocusBorder,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                  color: CommutasColors.slateMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                          if (_newPasswordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) ...[
                            const SizedBox(height: 16.0),
                            _buildChecklistItem('8+ characters', _hasEightChars),
                            _buildChecklistItem('At least one letter', _hasLetter),
                            _buildChecklistItem('At least one digit', _hasDigit),
                            _buildChecklistItem('Passwords match', _passwordsMatch),
                          ],
                          const SizedBox(height: 24.0),

                          // Submit Button
                          _buildPrimaryButton(
                            label: 'RESET PASSWORD',
                            onPressed: _handleResetPassword,
                            disabled: !_isResetValid,
                          ),
                          const SizedBox(height: 20.0),

                          // Back to sign in link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Remember password? ', style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.inkText)),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  'Sign in',
                                  style: CommutasTextStyles.bodySmall.copyWith(
                                    color: CommutasColors.accentCobalt,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold,
                                  ),
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
            ),
            
            // Bottom Identity strip
            _buildIdentityBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 48.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: const BoxDecoration(
        color: CommutasColors.white,
        border: Border.fromBorderSide(
          BorderSide(color: CommutasColors.lineBorder, width: 1.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 400.0,
          dropdownColor: CommutasColors.white,
          borderRadius: BorderRadius.zero,
          icon: const Icon(
            Icons.arrow_drop_down,
            color: CommutasColors.slateMuted,
            size: 24,
          ),
          style: CommutasTextStyles.fieldValue,
          onChanged: onChanged,
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(
                val,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: CommutasTextStyles.fieldValue,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check : Icons.close,
            size: 16,
            color: isMet ? CommutasColors.success : CommutasColors.danger,
          ),
          const SizedBox(width: 6.0),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.normal,
              color: isMet ? CommutasColors.success : CommutasColors.slateMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    bool disabled = false,
  }) {
    Color buttonColor = CommutasColors.navyInk;
    Widget buttonContent = Text(
      label.toUpperCase(),
      style: CommutasTextStyles.buttonLabel,
    );

    if (disabled) {
      buttonColor = CommutasColors.sageTint;
      buttonContent = Text(
        label.toUpperCase(),
        style: CommutasTextStyles.buttonLabel.copyWith(color: CommutasColors.slateMuted),
      );
    }

    return SizedBox(
      height: 52,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: buttonColor,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: EdgeInsets.zero,
        ),
        onPressed: disabled ? null : onPressed,
        child: buttonContent,
      ),
    );
  }

  Widget _buildIdentityBar() {
    final hasFeedback = _errorMessage != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      decoration: BoxDecoration(
        color: hasFeedback ? CommutasColors.danger : CommutasColors.white,
        border: Border(
          top: BorderSide(
            color: hasFeedback ? Colors.transparent : CommutasColors.lineBorder,
            width: 1.5,
          ),
        ),
      ),
      child: Center(
        child: hasFeedback
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: CommutasColors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: CommutasColors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      icon: const Icon(Icons.close, color: CommutasColors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo_theme_cropped.png',
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Smart Transit Mobility',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CommutasColors.slateMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AnimatedHeader extends StatefulWidget {
  const _AnimatedHeader();

  @override
  State<_AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<_AnimatedHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoOffset;
  late final Animation<double> _textOpacity;
  Timer? _phraseTimer;
  int _phraseIndex = 0;

  static const List<String> _resetPhrases = [
    'Secure your transport wallet keys',
    'Reset password with portal validation',
    'Recover your smart transit profile',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _logoOffset = Tween<Offset>(begin: const Offset(0.0, -0.15), end: Offset.zero).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));

    _controller.forward();

    _phraseTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _phraseIndex = (_phraseIndex + 1) % 3;
        });
      }
    });
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catchphrase = _resetPhrases[_phraseIndex];

    return Container(
      height: 125,
      padding: const EdgeInsets.only(bottom: 8.0),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SlideTransition(
                  position: _logoOffset,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Image.asset(
                      'assets/logo_theme_cropped.png',
                      height: 75,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                Opacity(
                  opacity: _textOpacity.value,
                  child: SizedBox(
                    height: 20,
                    width: double.infinity,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: Align(
                        key: ValueKey<String>(catchphrase),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          catchphrase,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: CommutasColors.slateMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
