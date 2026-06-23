import 'dart:async';
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
  bool _isLoading = false;
  String? _errorMessage;


  // Lockout simulation for Sign In
  int _failedAttempts = 0;
  int _lockoutSecondsLeft = 0;
  Timer? _lockoutTimer;

  // Logged-in state
  bool _isLoggedIn = false;
  String _loggedInName = '';
  String _loggedInRegNo = '';
  double _walletBalance = 500.0;
  final List<Map<String, dynamic>> _transactionHistory = [
    {'type': 'Fare Deduction', 'amount': -25.0, 'date': '2026-06-23 09:12 AM', 'bus': 'ABT-4471'},
    {'type': 'Wallet Top-up (JazzCash)', 'amount': 200.0, 'date': '2026-06-22 04:30 PM', 'bus': 'N/A'},
    {'type': 'Fare Deduction', 'amount': -25.0, 'date': '2026-06-22 08:05 AM', 'bus': 'ABT-4471'},
  ];

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
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      _errorMessage = null;
    });
  }

  // Dynamic preview display: CIIT/Session-Program-RollNo/ATD
  String get _registrationPreviewText {
    final rollNo = _rollNoController.text.trim();
    return 'CIIT/$_selectedSession-$_selectedDept-$rollNo/ATD';
  }

  // Validate values for signup checklist
  bool get _hasEightChars => _createPasswordController.text.length >= 8;
  bool get _hasLetter => RegExp(r'[a-zA-Z]').hasMatch(_createPasswordController.text);
  bool get _hasDigit => RegExp(r'\d').hasMatch(_createPasswordController.text);
  bool get _passwordsMatch =>
      _createPasswordController.text.isNotEmpty &&
      _createPasswordController.text == _confirmPasswordController.text;

  bool get _isSignUpValid {
    final rollNo = _rollNoController.text.trim();
    if (rollNo.isEmpty || !RegExp(r'^\d{1,3}$').hasMatch(rollNo)) return false;
    if (_portalPasswordController.text.isEmpty) return false;
    if (!_hasEightChars || !_hasLetter || !_hasDigit) return false;
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
        setState(() {
          _errorMessage = "Enter a valid registration number, e.g., FA23-BCS-065";
        });
        return;
      }
      if (password.isEmpty) {
        setState(() {
          _errorMessage = "Enter your password";
        });
        return;
      }
    } else if (_activeRole == UserRole.vehicle) {
      final vehicleReg = _signInVehicleController.text.trim();
      if (vehicleReg.isEmpty || !RegExp(r'^[A-Z]{3}-\d{4}$').hasMatch(vehicleReg)) {
        setState(() {
          _errorMessage = "Enter a valid vehicle registration number, e.g., ABT-4471";
        });
        return;
      }
      if (password.isEmpty) {
        setState(() {
          _errorMessage = "Enter your password";
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate backend roundtrip
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Simulation logic: mock authenticate
    bool isSuccess = false;
    if (_activeRole == UserRole.student) {
      // Mock validation success if password is "password123"
      if (password == 'password123') {
        isSuccess = true;
      }
    } else if (_activeRole == UserRole.vehicle) {
      if (password == 'vehicle123') {
        isSuccess = true;
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (isSuccess) {
      _failedAttempts = 0;
      setState(() {
        _isLoggedIn = true;
        if (_activeRole == UserRole.student) {
          _loggedInName = 'Mubashir Shahzaib';
          _loggedInRegNo = 'FA23-BCS-065';
        } else if (_activeRole == UserRole.vehicle) {
          _loggedInName = 'Vehicle Bus #3';
          _loggedInRegNo = _signInVehicleController.text.toUpperCase();
        }
      });
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        // Escalate lockouts: 5 attempts -> 1 minute lockout
        _startLockoutTimer(60);
        setState(() {
          _errorMessage = "Too many attempts. Try again in 01:00.";
        });
      } else {
        setState(() {
          // AUTH-FR-015: Generic error for security
          _errorMessage = "Incorrect identifier or password";
        });
      }
    }
  }

  void _handleSignUp() async {
    if (!_isSignUpValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      
    });

    // Simulate backend verification
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Success simulation
    setState(() {
      _isLoggedIn = true;
      _loggedInName = 'Wafa Amjad';
      _loggedInRegNo = 'FA23-BCS-133';
    });
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _loggedInName = '';
      _loggedInRegNo = '';
      _signInPasswordController.clear();
      _portalPasswordController.clear();
      _createPasswordController.clear();
      _confirmPasswordController.clear();
      _rollNoController.clear();
      _agreedToTerms = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return _buildDashboard();
    }

    return Scaffold(
      backgroundColor: CommutasColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Main Content Card area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8.0, bottom: 24.0, left: 20.0, right: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tabs
                    _buildTabBar(),
                    const SizedBox(height: 16.0),
                    
                    // Main Card containing fields
                    Container(
                      decoration: const BoxDecoration(
                        color: CommutasColors.white,
                        border: Border.fromBorderSide(
                          BorderSide(color: CommutasColors.lineBorder, width: 1.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(20.0),
                      child: _isRegisterTab ? _buildRegisterView() : _buildSignInView(),
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
                    color: !_isRegisterTab ? CommutasColors.accentCobalt : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                'SIGN IN',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: !_isRegisterTab ? CommutasColors.navyInk : CommutasColors.slateMuted,
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
                    color: _isRegisterTab ? CommutasColors.accentCobalt : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                'REGISTER',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isRegisterTab ? CommutasColors.navyInk : CommutasColors.slateMuted,
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
        // Brand Logo
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Image.asset(
              'assets/logo_theme_transparent.png',
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
        ),
        // Role indicators
        Row(
          children: [
            _buildRoleChip(UserRole.student, 'Student'),
            _buildRoleChip(UserRole.vehicle, 'Vehicle'),
          ],
        ),
        const SizedBox(height: 24.0),

        Text(
          'WELCOME BACK',
          style: CommutasTextStyles.sectionEyebrow,
        ),
        const SizedBox(height: 8.0),
        Text(
          'Sign in to your account',
          style: CommutasTextStyles.cardTitle,
        ),
        const SizedBox(height: 20.0),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: CommutasColors.danger.withValues(alpha: 0.1),
              border: Border.all(color: CommutasColors.danger, width: 1.5),
            ),
            child: Text(
              _errorMessage!,
              style: CommutasTextStyles.bodySmallDanger,
            ),
          ),
          const SizedBox(height: 16.0),
        ],

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
                color: CommutasColors.slateMuted,
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
            Text(
              'Trouble signing in?',
              style: CommutasTextStyles.bodySmall,
            ),
            if (_activeRole == UserRole.student)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _errorMessage = "Password reset instructions sent to student email.";
                  });
                },
                child: Text(
                  'Forgot password?',
                  style: CommutasTextStyles.bodySmall.copyWith(
                    color: CommutasColors.accentCobalt,
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

        // Submit button
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
                  color: CommutasColors.accentCobalt,
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
            color: isActive ? CommutasColors.navyInk : CommutasColors.white,
            border: Border.fromBorderSide(
              BorderSide(
                color: isActive ? CommutasColors.accentCobalt : CommutasColors.lineBorder,
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
        // Disabled preview box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
          decoration: const BoxDecoration(
            color: CommutasColors.sageTint,
            border: Border.fromBorderSide(
              BorderSide(color: CommutasColors.lineBorder, width: 1.5),
            ),
          ),
          child: Text(
            _registrationPreviewText,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: CommutasColors.slateMuted,
            ),
          ),
        ),
        const SizedBox(height: 12.0),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
                  enabledBorder: CommutasShapes.inputBorder,
                  focusedBorder: CommutasShapes.inputFocusBorder,
                  errorBorder: CommutasShapes.inputErrorBorder,
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
          style: CommutasTextStyles.fieldValue,
          onChanged: onChanged,
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val),
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
    Color buttonColor = CommutasColors.navyInk;
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
    } else if (_isLoading) {
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
        onPressed: (disabled || _isLoading || isTimerActive) ? null : onPressed,
        child: buttonContent,
      ),
    );
  }

  // Render Register Card Content
  Widget _buildRegisterView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Logo
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Image.asset(
              'assets/logo_theme_transparent.png',
              height: 70,
              fit: BoxFit.contain,
            ),
          ),
        ),
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

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: CommutasColors.danger.withValues(alpha: 0.1),
              border: Border.all(color: CommutasColors.danger, width: 1.5),
            ),
            child: Text(
              _errorMessage!,
              style: CommutasTextStyles.bodySmallDanger,
            ),
          ),
          const SizedBox(height: 16.0),
        ],

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
        const SizedBox(height: 16.0),

        // Password Checklist
        _buildChecklistItem('8+ characters', _hasEightChars),
        _buildChecklistItem('At least one letter', _hasLetter),
        _buildChecklistItem('At least one digit', _hasDigit),
        _buildChecklistItem('Passwords match', _passwordsMatch),
        const SizedBox(height: 16.0),

        // Terms and conditions
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _agreedToTerms,
                activeColor: CommutasColors.accentCobalt,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                onChanged: (bool? val) {
                  setState(() {
                    _agreedToTerms = val ?? false;
                  });
                },
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                'I have read and agree to the Terms and Conditions.',
                style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.inkText),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24.0),

        // Submit Button
        _buildPrimaryButton(
          label: 'CREATE ACCOUNT',
          onPressed: _handleSignUp,
          disabled: !_isSignUpValid,
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
                  color: CommutasColors.accentCobalt,
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
    String barText = '• COMMUTAS •';
    if (_isLoggedIn) {
      barText = '$_loggedInName   $_loggedInRegNo';
    }

    return Container(
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
        barText,
        style: CommutasTextStyles.identityBar,
      ),
    );
  }

  // Simple post-auth dashboard placeholder
  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: CommutasColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              height: 96,
              color: CommutasColors.navyInk,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('COMMUTAS', style: CommutasTextStyles.appTitle),
                  IconButton(
                    icon: const Icon(Icons.logout, color: CommutasColors.white),
                    onPressed: _handleLogout,
                  ),
                ],
              ),
            ),
            Container(
              height: 44,
              color: CommutasColors.navyDark,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Student Dashboard', style: CommutasTextStyles.contextStripLabel),
                  Text('ACTIVE SESSION', style: CommutasTextStyles.contextStripMeta),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'OVERVIEW',
                      style: CommutasTextStyles.sectionEyebrow,
                    ),
                    const SizedBox(height: 8.0),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Wallet Balance',
                                style: CommutasTextStyles.fieldLabel,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                decoration: BoxDecoration(
                                  color: CommutasColors.success.withValues(alpha: 0.1),
                                  border: Border.all(color: CommutasColors.success, width: 1.0),
                                ),
                                child: Text(
                                  '✓ VERIFIED',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: CommutasColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            'Rs. ${_walletBalance.toStringAsFixed(2)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: CommutasColors.inkText,
                            ),
                          ),
                          const SizedBox(height: 20.0),
                          _buildPrimaryButton(
                            label: 'Simulate Top-up (JazzCash Sandbox)',
                            onPressed: () {
                              setState(() {
                                _walletBalance += 100.0;
                                _transactionHistory.insert(0, {
                                  'type': 'Wallet Top-up (JazzCash)',
                                  'amount': 100.0,
                                  'date': 'Just now',
                                  'bus': 'N/A'
                                });
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24.0),

                    Text(
                      'TRANSACTION HISTORY',
                      style: CommutasTextStyles.sectionEyebrow,
                    ),
                    const SizedBox(height: 8.0),
                    Container(
                      decoration: const BoxDecoration(
                        color: CommutasColors.white,
                        border: Border.fromBorderSide(
                          BorderSide(color: CommutasColors.lineBorder, width: 1.5),
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _transactionHistory.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: CommutasColors.lineBorder,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final tx = _transactionHistory[index];
                          final isDeduction = tx['amount'] < 0;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            title: Text(
                              tx['type'],
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: CommutasColors.inkText,
                              ),
                            ),
                            subtitle: Text(
                              '${tx['date']}   ${tx['bus'] != 'N/A' ? "Bus: ${tx['bus']}" : ""}',
                              style: CommutasTextStyles.bodySmall,
                            ),
                            trailing: Text(
                              '${isDeduction ? "" : "+"}${tx['amount'].toStringAsFixed(2)}',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                color: isDeduction ? CommutasColors.danger : CommutasColors.success,
                                fontSize: 15,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom bar
            _buildIdentityBar(),
          ],
        ),
      ),
    );
  }
}
