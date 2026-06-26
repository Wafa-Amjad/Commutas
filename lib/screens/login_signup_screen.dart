import 'services/auth_service.dart';
import 'services/biometric_service.dart';
import 'package:dio/dio.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'verification_screen.dart';
import 'main_screen.dart';
import 'package:flutter_biometric_change_detector/flutter_biometric_change_detector.dart';
import 'package:flutter_biometric_change_detector/status_enum.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'reset_password_screen.dart';
import 'package:flutter/gestures.dart'; // RichText tracking k liyen
import 'package:url_launcher/url_launcher.dart'; // Live link open krne k liyen
// ignore: unused_import
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

enum UserRole { student, vehicle }

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  // Tabs
  bool _isRegisterTab = false;

  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  bool _isServerLoading = false;

  // Active Role (Sign In only)
  UserRole _activeRole = UserRole.student;

  // Shared inputs for Student Reg No construction
  String _selectedSession = 'FA23';
  String _selectedDept = 'BCS';
  final TextEditingController _rollNoController = TextEditingController();

  // Sign In inputs
  final TextEditingController _signInVehicleController = TextEditingController();
  final TextEditingController _signInPasswordController = TextEditingController();
  bool _obscureSignInPassword = true;

  // Sign Up inputs
  final TextEditingController _portalPasswordController = TextEditingController();
  final TextEditingController _createPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePortalPassword = true;
  bool _obscureCreatePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;

  // Loading and Error states
  String? _errorMessage;

  // Lockout simulation for Sign In
  int _failedAttempts = 0;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;

  // Lists extracted from HTML
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
    _createPasswordController.addListener(_onInputChanged);
    _confirmPasswordController.addListener(_onInputChanged);
    _portalPasswordController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _rollNoController.dispose();
    _createPasswordController.dispose();
    _confirmPasswordController.dispose();
    _portalPasswordController.dispose();
    _signInVehicleController.dispose();
    _signInPasswordController.dispose();
    _lockoutTimer?.cancel();
    _errorDismissTimer?.cancel();
    super.dispose();
  }

  Timer? _errorDismissTimer;

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


  // Dynamic preview displaySession-Program-Roll
  // ignore: unused_element
  String get _registrationPreviewText {
    final rollNo = _rollNoController.text.trim();
    return '$_selectedSession-$_selectedDept-$rollNo';
  }

  // Validate values for signup checklist
  bool get _hasEightChars => _createPasswordController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[a-zA-Z]').hasMatch(_createPasswordController.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_createPasswordController.text);
  bool get _hasValidMaxLength => _createPasswordController.text.length <= 32;
  bool get _passwordsMatch =>
      _createPasswordController.text.isNotEmpty &&
      _createPasswordController.text == _confirmPasswordController.text;

  bool get _isSignUpValid {
    final rollNo = _rollNoController.text.trim();
    if (rollNo.isEmpty || !RegExp(r'^\d{1,3}$').hasMatch(rollNo)) return false;
    if (_portalPasswordController.text.isEmpty) return false;
    if (!_hasEightChars || !_hasLetter || !_hasDigit || !_hasValidMaxLength) return false;
    if (!_passwordsMatch) return false;
    if (!_agreedToTerms) return false;
    return true;
  }

  // Helper to format countdown timer (MM:SS)
  String _formatLockoutTime() {
    final minutes = (_lockoutSecondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_lockoutSecondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startLockoutTimer(int durationSeconds) {
    setState(() {
      _lockoutSecondsLeft = durationSeconds;
    });
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_lockoutSecondsLeft > 1) {
          _lockoutSecondsLeft--;
        } else {
          _lockoutSecondsLeft = 0;
          _lockoutTimer?.cancel();
        }
      });
    });
  }

  // Handle student validation checks
  void _handleSignIn() async {
    if (_lockoutSecondsLeft > 0) return;

    setState(() {
      _errorMessage = null;
    });

    final password = _signInPasswordController.text;

    // Validation checks
    if (_activeRole == UserRole.student) {
      final rollNo = _rollNoController.text.trim();
      if (rollNo.isEmpty) {
        _setError("Enter a valid registration number, e.g., FA23-BCS-065");
        return;
      }
      if (password.isEmpty) {
        _setError("Enter your password");
        return;
      }
    } else if (_activeRole == UserRole.vehicle) {
      final vehicleReg = _signInVehicleController.text.trim();
      if (vehicleReg.isEmpty || !RegExp(r'^[A-Z]{3}-\d{4}$').hasMatch(vehicleReg)) {
        _setError("Enter a valid vehicle registration number, e.g., ABT-4471");
        return;
      }
      if (password.isEmpty) {
        _setError("Enter your password");
        return;
      }
    }

    setState(() {
      _isServerLoading = true;
    });

    try {
      if (_activeRole == UserRole.student) {
        String fullRegNo = "$_selectedSession-$_selectedDept-${_rollNoController.text.trim().padLeft(3, '0')}";
        final plainPassword = _signInPasswordController.text.trim();
        final response = await _authService.loginStudent(
          regNo: fullRegNo, 
          appPassword: plainPassword
        );
        final fullName = response?['student']?['full_name'];
        final regNo = response?['student']?['reg_no'];
        if (response != null && fullName != null && regNo != null) {
          // If biometric is enabled for a different account, clear it.
          if (await _biometricService.isBiometricsEnabled()) {
            final savedCreds = await _biometricService.getSavedCredentials();
            if (savedCreds != null && savedCreds['reg_no'] != regNo) {
              await _biometricService.disableBiometrics();
            }
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('session_active', true);
          await prefs.setString('session_name', fullName);
          await prefs.setString('session_reg_no', regNo);
          await prefs.setString('session_role', 'student');
          final token = response['access_token'];
          if (token != null) {
            await prefs.setString('session_token', token);
          }
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainScreen(
                  studentName: fullName,
                  studentRegNo: regNo,
                  lastEnteredPassword: plainPassword,
                ),
              ),
            );
          }
        } else {
          _setError("Authentication failed. Invalid response from server.");
        }
      } else if (_activeRole == UserRole.vehicle) {
        await Future.delayed(const Duration(seconds: 2));
        if (password == 'vehicle123') {
          final name = 'Vehicle Bus #3';
          final regNo = _signInVehicleController.text.toUpperCase();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('session_active', true);
          await prefs.setString('session_name', name);
          await prefs.setString('session_reg_no', regNo);
          await prefs.setString('session_role', 'vehicle');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MainScreen(
                  studentName: name,
                  studentRegNo: regNo,
                ),
              ),
            );
          }
        } else {
           _failedAttempts++;
           if (_failedAttempts >= 5) {
             _startLockoutTimer(60);
             _setError("Too many attempts. Try again in 01:00.");
           } else {
             _setError("Incorrect identifier or password");
           }
        }
      }
    } catch (e) {
      String errorMsg = "Login failed. Check connection or credentials.";
      if (e is DioException) {
        final detail = e.response?.data?['detail'];
        if (detail != null) {
          errorMsg = detail.toString();
        } else if (e.message != null) {
          errorMsg = e.message!;
        }
      } else {
        errorMsg = e.toString();
      }
      _setError(errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isServerLoading = false;
        });
      }
    }
  }

  void _handleBiometricLogin() async {
    final hasBiometrics = await _biometricService.isBiometricsAvailable();
    if (!hasBiometrics) {
      _setError("Biometrics not supported or not configured on this device");
      return;
    }

    try {
      final status = await FlutterBiometricChangeDetector.checkBiometric();
      if (status == AuthChangeStatus.CHANGED) {
        await _biometricService.disableBiometrics();
        _setError("Biometrics changed on this device. Sign in with your password to re-enable.");
        return;
      }
    } catch (_) {}

    final credentials = await _biometricService.getSavedCredentials();
    if (credentials == null) {
      _setError("Biometrics not setup. Sign in with password first to enable it.");
      return;
    }

    final authenticated = await _biometricService.authenticate();
    if (authenticated) {
      final regNo = credentials['reg_no']!;
      final password = credentials['password']!;
      _performBiometricAutoLogin(regNo, password);
    } else {
      _setError("Biometric authentication cancelled or failed");
    }
  }

  void _performBiometricAutoLogin(String regNo, String password) async {
    setState(() {
      _isServerLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.loginStudent(
        regNo: regNo, 
        appPassword: password
      );
      
      final fullName = response?['student']?['full_name'];
      final regNoFromApi = response?['student']?['reg_no'];
      if (response != null && fullName != null && regNoFromApi != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('session_active', true);
        await prefs.setString('session_name', fullName);
        await prefs.setString('session_reg_no', regNoFromApi);
        await prefs.setString('session_role', 'student');
        final token = response['access_token'];
        if (token != null) {
          await prefs.setString('session_token', token);
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(
                studentName: fullName,
                studentRegNo: regNoFromApi,
                lastEnteredPassword: password,
              ),
            ),
          );
        }
      } else {
        _setError("Biometric sign-in failed. Use app password.");
      }
    } catch (e) {
      String errorMsg = "Login failed. Check connection or credentials.";
      if (e is DioException) {
        final detail = e.response?.data?['detail'];
        if (detail != null) {
          errorMsg = detail.toString();
        } else if (e.message != null) {
          errorMsg = e.message!;
        }
      } else {
        errorMsg = e.toString();
      }
      _setError(errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isServerLoading = false;
        });
      }
    }
  }

  void _handleSignUp() async {
    if (!_isSignUpValid) return;

    final String fullRegNo = "$_selectedSession-$_selectedDept-${_rollNoController.text.trim().padLeft(3, '0')}";
    final String portalPassword = _portalPasswordController.text.trim();
    final String appPassword = _createPasswordController.text.trim();

    // Navigate to full-screen standalone verification page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationScreen(
          regNo: fullRegNo,
          portalPassword: portalPassword,
          appPassword: appPassword,
        ),
      ),
    );

    if (mounted) {
      if (result == true) {
        // Success
        await _biometricService.disableBiometrics();
        setState(() {
          _portalPasswordController.clear();
          _createPasswordController.clear();
          _confirmPasswordController.clear();
          _agreedToTerms = false;
          _isRegisterTab = false; // Transition back to Sign In
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {

    return Stack(
      children: [
        Scaffold(
          backgroundColor: CommutasColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Main Content Card area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 24.0, left: 20.0, right: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Header: Logo and loopable catchphrase outside the card on top
                        _AnimatedHeader(isRegisterTab: _isRegisterTab),
                        const SizedBox(height: 16.0),
                        
                        // Main Card containing switcher and input fields
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
                              // Switcher Tabs inside the white card at the top
                              _buildTabBar(),
                              const SizedBox(height: 24.0),
                              _isRegisterTab ? _buildRegisterView() : _buildSignInView(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Bottom Identity Bar (Fixed branding structure)
                _buildIdentityBar(),
              ],
            ),
          ),
        ),
        if (_isServerLoading)
          Positioned.fill(
            child: Container(
              color: CommutasColors.primaryNavy.withValues(alpha: 0.40),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                child: Center(
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: CommutasColors.white,
                      border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'Authenticating...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: CommutasColors.slateMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Tab switcher ("SIGN IN" / "REGISTER")
  Widget _buildTabBar() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _isRegisterTab = false;
                _errorMessage = null;
              });
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: !_isRegisterTab ? CommutasColors.primaryNavy : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                'SIGN IN',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: !_isRegisterTab ? CommutasColors.primaryNavy : CommutasColors.slateMuted,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _isRegisterTab = true;
                _errorMessage = null;
              });
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _isRegisterTab ? CommutasColors.primaryNavy : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                'REGISTER',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isRegisterTab ? CommutasColors.primaryNavy : CommutasColors.slateMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Render Role Indicator Row and dynamic inputs for Login
  Widget _buildSignInView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Role indicators
        Row(
          children: [
            _buildRoleChip(UserRole.student, 'Student'),
            _buildRoleChip(UserRole.vehicle, 'Vehicle'),
          ],
        ),
        const SizedBox(height: 24.0),

        Text(
          'Sign in to your account',
          style: CommutasTextStyles.cardTitle,
        ),
        const SizedBox(height: 20.0),

        // Input forms depending on Role
        if (_activeRole == UserRole.student) _buildStudentRegForm(),
        if (_activeRole == UserRole.vehicle) ...[
          _buildTextField(
            label: 'Vehicle Registration No.',
            controller: _signInVehicleController,
            placeholder: 'ABT-4471',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 16.0),
        ],

        // Password Text Field
        Text(
          'Password',
          style: CommutasTextStyles.fieldLabel,
        ),
        const SizedBox(height: 6.0),
        TextFormField(
          controller: _signInPasswordController,
          obscureText: _obscureSignInPassword,
          style: CommutasTextStyles.fieldValue,
          decoration: InputDecoration(
            hintText: 'Enter password',
            hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
            filled: true,
            fillColor: CommutasColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            enabledBorder: CommutasShapes.inputBorder,
            focusedBorder: CommutasShapes.inputFocusBorder,
            errorBorder: CommutasShapes.inputErrorBorder,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignInPassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscureSignInPassword = !_obscureSignInPassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16.0),

        // Helper text + action link row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            if (_activeRole == UserRole.student)
              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResetPasswordScreen(),
                    ),
                  );
                },
                child: Text(
                  'Forgot password?',
                  style: CommutasTextStyles.bodySmall.copyWith(
                    color: CommutasColors.primaryNavy,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            else
              Text(
                'Contact your administrator',
                style: CommutasTextStyles.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 24.0),

        // Submit button + Biometrics option (Student only)
        if (_activeRole == UserRole.student)
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _buildPrimaryButton(
                  label: 'SIGN IN',
                  onPressed: _handleSignIn,
                ),
              ),
              const SizedBox(width: 12.0),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: CommutasColors.white,
                  border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
                  borderRadius: BorderRadius.zero,
                ),
                child: IconButton(
                  icon: const Icon(Icons.fingerprint, color: CommutasColors.primaryNavy, size: 28.0),
                  onPressed: _handleBiometricLogin,
                ),
              ),
            ],
          )
        else
          _buildPrimaryButton(
            label: 'SIGN IN',
            onPressed: _handleSignIn,
          ),
        const SizedBox(height: 20.0),

        // OR Redirect
        Row(
          children: [
            const Expanded(child: Divider(color: CommutasColors.lineBorder, thickness: 1.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('OR', style: GoogleFonts.jetBrainsMono(color: CommutasColors.slateMuted, fontSize: 12)),
            ),
            const Expanded(child: Divider(color: CommutasColors.lineBorder, thickness: 1.5)),
          ],
        ),
        const SizedBox(height: 16.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New student? ', style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.inkText)),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isRegisterTab = true;
                  _errorMessage = null;
                });
              },
              child: Text(
                'Create account',
                style: CommutasTextStyles.bodySmall.copyWith(
                  color: CommutasColors.primaryNavy,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleChip(UserRole role, String label) {
    final isActive = _activeRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeRole = role;
            _errorMessage = null;
          });
        },
        child: Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? CommutasColors.primaryNavy : CommutasColors.white,
            border: Border.fromBorderSide(
              BorderSide(
                color: isActive ? CommutasColors.primaryNavy : CommutasColors.lineBorder,
                width: isActive ? 2.0 : 1.5,
              ),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive ? CommutasColors.white : CommutasColors.slateMuted,
            ),
          ),
        ),
      ),
    );
  }

  // Student specific inputs
  Widget _buildStudentRegForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Registration number',
          style: CommutasTextStyles.fieldLabel,
        ),
        const SizedBox(height: 6.0),
        // Dropdowns and Roll no input
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
      ],
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    required TextInputType keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: CommutasTextStyles.fieldLabel,
        ),
        const SizedBox(height: 6.0),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: CommutasTextStyles.fieldValue,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
            filled: true,
            fillColor: CommutasColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            enabledBorder: CommutasShapes.inputBorder,
            focusedBorder: CommutasShapes.inputFocusBorder,
            errorBorder: CommutasShapes.inputErrorBorder,
          ),
        ),
      ],
    );
  }

  // Submit button
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    bool disabled = false,
  }) {
    final isTimerActive = _lockoutSecondsLeft > 0;
    
    // Build background and style config
    Color buttonColor = CommutasColors.primaryNavy;
    Widget buttonContent = Text(
      isTimerActive ? 'TRY AGAIN IN ${_formatLockoutTime()}' : label.toUpperCase(),
      style: CommutasTextStyles.buttonLabel,
    );

    if (disabled || isTimerActive) {
      buttonColor = CommutasColors.sageTint;
      buttonContent = Text(
        isTimerActive ? 'TRY AGAIN IN ${_formatLockoutTime()}' : label.toUpperCase(),
        style: CommutasTextStyles.buttonLabel.copyWith(color: CommutasColors.slateMuted),
      );
    } else if (_isServerLoading) {
      buttonContent = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.0,
          valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.white),
        ),
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
        onPressed: (disabled || _isServerLoading || isTimerActive) ? null : onPressed,
        child: buttonContent,
      ),
    );
  }

  // Render Register Card Content
  Widget _buildRegisterView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'STUDENT VERIFICATION',
          style: CommutasTextStyles.sectionEyebrow,
        ),
        const SizedBox(height: 8.0),
        Text(
          'Create student account',
          style: CommutasTextStyles.cardTitle,
        ),
        const SizedBox(height: 20.0),

        // Registration details
        _buildStudentRegForm(),

        // Portal Password Field
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
            errorBorder: CommutasShapes.inputErrorBorder,
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

        // Create Luma Password Field
        Text(
          'Create App password',
          style: CommutasTextStyles.fieldLabel,
        ),
        const SizedBox(height: 6.0),
        TextFormField(
          controller: _createPasswordController,
          obscureText: _obscureCreatePassword,
          maxLength: 32,
          buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
          style: CommutasTextStyles.fieldValue,
          decoration: InputDecoration(
            hintText: 'Enter new password',
            hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
            filled: true,
            fillColor: CommutasColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            enabledBorder: CommutasShapes.inputBorder,
            focusedBorder: CommutasShapes.inputFocusBorder,
            errorBorder: CommutasShapes.inputErrorBorder,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureCreatePassword ? Icons.visibility : Icons.visibility_off,
                color: CommutasColors.slateMuted,
              ),
              onPressed: () {
                setState(() {
                  _obscureCreatePassword = !_obscureCreatePassword;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 16.0),

        // Confirm Luma Password Field
        Text(
          'Confirm App password',
          style: CommutasTextStyles.fieldLabel,
        ),
        const SizedBox(height: 6.0),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          maxLength: 32,
          buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
          style: CommutasTextStyles.fieldValue,
          decoration: InputDecoration(
            hintText: 'Re-enter new password',
            hintStyle: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
            filled: true,
            fillColor: CommutasColors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            enabledBorder: CommutasShapes.inputBorder,
            focusedBorder: CommutasShapes.inputFocusBorder,
            errorBorder: CommutasShapes.inputErrorBorder,
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
        if (_createPasswordController.text.isNotEmpty || _confirmPasswordController.text.isNotEmpty) ...[
          const SizedBox(height: 16.0),
          _buildChecklistItem('8+ characters', _hasEightChars),
          _buildChecklistItem('Maximum 32 characters', _hasValidMaxLength),
          _buildChecklistItem('At least one letter', _hasLetter),
          _buildChecklistItem('At least one digit', _hasDigit),
          _buildChecklistItem('Passwords match', _passwordsMatch),
        ],
        const SizedBox(height: 16.0),

        // Terms and conditions
        // Checkbox aur Text spans wala block jise replace krna hai:
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    SizedBox(
      height: 24,
      width: 24,
      child: Checkbox(
        value: _agreedToTerms,
        activeColor: CommutasColors.primaryNavy, // theme.dart k mutabiq primaryNavy use ho rha hai
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Strict 0px sharp edges
        onChanged: (bool? val) {
          setState(() {
            _agreedToTerms = val ?? false;
          });
        },
      ),
    ),
    const SizedBox(width: 8.0),
    Expanded(
      child: RichText(
        text: TextSpan(
          text: 'I agree to the ',
          style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.inkText), // theme.dart k input rules mapping
          children: [
            TextSpan(
              text: 'Terms and Conditions',
              style: CommutasTextStyles.bodySmall.copyWith(
                color: CommutasColors.primaryNavy, // Link color matches your dark navy token style
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.bold,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  final url = Uri.parse('https://commutas-app.netlify.app/');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
            ),
            TextSpan(
              text: '.',
              style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.inkText),
            ),
          ],
        ),
      ),
    ),
  ],
),
        const SizedBox(height: 20.0),

        // Redirect back to login
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ', style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.inkText)),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isRegisterTab = false;
                  _errorMessage = null;
                });
              },
              child: Text(
                'Log in',
                style: CommutasTextStyles.bodySmall.copyWith(
                  color: CommutasColors.primaryNavy,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
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

  // Footer fixed Identity Bar
  Widget _buildIdentityBar() {
    final hasFeedback = _errorMessage != null;
    final isSuccessFeedback = hasFeedback && 
        (_errorMessage!.toLowerCase().contains('success') || 
         _errorMessage!.toLowerCase().contains('instructions') || 
         _errorMessage!.toLowerCase().contains('sent'));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 56,
      decoration: BoxDecoration(
        color: hasFeedback 
            ? (isSuccessFeedback ? CommutasColors.success : CommutasColors.danger)
            : CommutasColors.white,
        border: Border(
          top: BorderSide(
            color: hasFeedback ? Colors.transparent : CommutasColors.lineBorder,
            width: 1.5,
          ),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: hasFeedback
            ? KeyedSubtree(
                key: ValueKey<String>(_errorMessage!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        isSuccessFeedback 
                            ? Icons.check_circle_outline 
                            : Icons.warning_amber_rounded,
                        color: CommutasColors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _MarqueeText(
                          text: _errorMessage!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: CommutasColors.white,
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
                ),
              )
            : KeyedSubtree(
                key: const ValueKey<String>('brand_status_strip'),
                child: Center(
                  child: Row(
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
              ),
      ),
    );
  }
}

// Animated Header Logo widget with vertically aligned logo (top) and catchphrases (bottom) looping
class _AnimatedHeader extends StatefulWidget {
  final bool isRegisterTab;

  const _AnimatedHeader({required this.isRegisterTab});

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

  static const List<String> _signInPhrases = [
    'Verify, pay, and ride instantly',
    'Seamless HCE NFC-based fare collection',
    'Your ticket to a smarter COMSATS commute',
  ];

  static const List<String> _signUpPhrases = [
    'Create your digital transport wallet',
    'Link COMSATS portal for quick verification',
    'Secure campus transit at your fingertips',
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

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    ));

    _controller.forward();

    // Loop catchphrases every 3 seconds
    _phraseTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _phraseIndex = (_phraseIndex + 1) % 3;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant _AnimatedHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRegisterTab != widget.isRegisterTab) {
      setState(() {
        _phraseIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phrases = widget.isRegisterTab ? _signUpPhrases : _signInPhrases;
    final catchphrase = phrases[_phraseIndex];

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
                // Sliding and fading Logo on load
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
                // Looping catchphrases below the logo
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

// Marquee Text Widget for horizontal scrolling text headline in bottom bar
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  late final ScrollController _scrollController;
  bool _scrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndScroll();
    });
  }

  void _checkAndScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0 && !_scrolling) {
      _scrolling = true;
      // Delay initial scroll by 600 ms
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _scroll();
        }
      });
    }
  }

  void _scroll() async {
    if (!mounted || !_scrollController.hasClients) {
      _scrolling = false;
      return;
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      _scrolling = false;
      return;
    }

    // Scroll speed: ~40 pixels per second
    final duration = Duration(milliseconds: (maxScroll * 25).toInt());

    try {
      await _scrollController.animateTo(
        maxScroll,
        duration: duration,
        curve: Curves.linear,
      );
      if (!mounted) return;
      // Pause at the end for 1 second
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0.0);
      // Delay before restarting the scroll by 600 ms
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _scroll();
    } catch (_) {
      _scrolling = false;
    }
  }

  @override
  void didUpdateWidget(covariant _MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _scrolling = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndScroll();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}


