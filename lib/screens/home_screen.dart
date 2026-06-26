import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import '../theme.dart';
import 'services/biometric_service.dart';
import 'services/wallet_service.dart';
import 'services/notification_service.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final BiometricService _biometricService = BiometricService();
  final WalletService _walletService = WalletService();
  bool _isBiometricEnabled = false;
  double _walletBalance = 0.0;
  bool _isLoadingBalance = true;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricStatus();
    _loadTokenAndBalance();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingTransactions();
    }
  }

  Future<void> _checkPendingTransactions() async {
    if (_accessToken == null) return;
    final changed = await _walletService.checkPendingTransactions(_accessToken!, context);
    if (changed && mounted) {
      _fetchBalance();
    }
  }

  Future<void> _loadTokenAndBalance() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('session_token');
    if (_accessToken != null) {
      await _fetchBalance();
      // Proactively check status upon dashboard load in case a payment succeeded offline
      _checkPendingTransactions();
      
      // Auto-register device token for push notifications
      NotificationService().autoRegisterToken(_accessToken!);
    } else {
      if (mounted) {
        setState(() => _isLoadingBalance = false);
      }
    }
  }

  Future<void> _fetchBalance() async {
    if (_accessToken == null) return;
    final balance = await _walletService.fetchWalletBalance(token: _accessToken!);
    if (mounted) {
      setState(() {
        _walletBalance = balance;
        _isLoadingBalance = false;
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
      if (mounted && success) {
        setState(() => _isBiometricEnabled = true);
      }
    }
  }

  void _showAddFundsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddFundsSheet(
        studentRegNo: widget.studentRegNo,
        walletService: _walletService,
        onPaymentInitiated: () {
          // Refresh balance after returning from checkout
          _fetchBalance();
        },
      ),
    );
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
      automaticallyImplyLeading: false,
      titleSpacing: 20,
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
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: CommutasColors.primaryNavy),
          onPressed: () {
            // Notification action placeholder
          },
        ),
        const SizedBox(width: 8),
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

  Widget _buildWalletCard() {
    final balanceText = _isLoadingBalance
        ? 'Loading...'
        : 'Rs. ${_walletBalance.toStringAsFixed(2)}';

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
                  Text(balanceText, style: CommutasTextStyles.heading1.copyWith(fontSize: 32, color: CommutasColors.primaryNavy)),
                ],
              ),
              Icon(Icons.wallet, color: CommutasColors.emeraldGreen.withOpacity(0.8), size: 48),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _showAddFundsSheet,
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

// ──────────────────────────────────────────────────────────
// Add Funds Bottom Sheet
// ──────────────────────────────────────────────────────────
class _AddFundsSheet extends StatefulWidget {
  final String studentRegNo;
  final WalletService walletService;
  final VoidCallback onPaymentInitiated;

  const _AddFundsSheet({
    required this.studentRegNo,
    required this.walletService,
    required this.onPaymentInitiated,
  });

  @override
  State<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends State<_AddFundsSheet> with TickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  late final AnimationController _busController;

  final List<int> _quickAmounts = [100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _busController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _busController.dispose();
    super.dispose();
  }

  void _selectQuickAmount(int amount) {
    _amountController.text = amount.toString();
    setState(() => _error = null);
  }

  Future<void> _initiatePayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Enter an amount');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount < 10) {
      setState(() => _error = 'Minimum top-up amount is Rs. 10');
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });
    _busController.repeat();

    try {
      final response = await widget.walletService.initiateTopUp(
        regNo: widget.studentRegNo,
        amount: amount,
      );

      if (response != null && response['checkout_url'] != null) {
        final url = Uri.parse(response['checkout_url']);
        bool launched = false;
        try {
          launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('launchUrl externalApplication error: $e');
        }

        if (!launched) {
          try {
            launched = await launchUrl(url, mode: LaunchMode.platformDefault);
          } catch (e) {
            debugPrint('launchUrl platformDefault error: $e');
          }
        }

        if (launched) {
          // Track this transaction ID for status updates in background/app resume
          if (response['transaction_id'] != null) {
            await widget.walletService.trackPendingTransaction(
              response['transaction_id'].toString(),
              amount,
            );
          }
          widget.onPaymentInitiated();
          if (mounted) Navigator.pop(context);
        } else {
          setState(() {
            _isProcessing = false;
            _error = 'Could not open payment browser. Direct checkout URL: ${response['checkout_url']}';
          });
          _busController.stop();
        }
      } else {
        setState(() {
          _isProcessing = false;
          _error = 'Failed to initialize payment. Try again.';
        });
        _busController.stop();
      }
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      setState(() {
        _isProcessing = false;
        _error = detail?.toString() ?? 'Payment initiation failed. Check your connection.';
      });
      _busController.stop();
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _error = 'An unexpected error occurred.';
      });
      _busController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CommutasColors.lineBorder, width: 1)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _isProcessing ? _buildProcessingView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADD FUNDS',
                style: CommutasTextStyles.labelBold.copyWith(fontSize: 13, letterSpacing: 1.5),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: CommutasColors.slateMuted, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Top up your transit wallet via Safepay',
            style: CommutasTextStyles.bodySmall,
          ),
          const SizedBox(height: 24),

          // Amount Input
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: CommutasTextStyles.heading1.copyWith(fontSize: 28),
            decoration: InputDecoration(
              prefixText: 'Rs. ',
              prefixStyle: CommutasTextStyles.heading1.copyWith(fontSize: 28, color: CommutasColors.slateMuted),
              hintText: '0',
              hintStyle: CommutasTextStyles.heading1.copyWith(fontSize: 28, color: CommutasColors.lineBorder),
              border: CommutasShapes.inputBorder,
              enabledBorder: CommutasShapes.inputBorder,
              focusedBorder: CommutasShapes.inputFocusBorder,
              errorBorder: CommutasShapes.inputErrorBorder,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),

          // Quick Select Buttons
          Row(
            children: _quickAmounts.map((amount) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: amount != _quickAmounts.last ? 8.0 : 0),
                  child: OutlinedButton(
                    onPressed: () => _selectQuickAmount(amount),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CommutasColors.primaryNavy,
                      side: const BorderSide(color: CommutasColors.lineBorder),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Rs. $amount', style: CommutasTextStyles.labelBold.copyWith(fontSize: 11)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CommutasColors.danger.withOpacity(0.08),
                border: Border.all(color: CommutasColors.danger.withOpacity(0.3)),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: CommutasColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.danger),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Proceed Button
          SizedBox(
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: CommutasColors.primaryNavy,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: EdgeInsets.zero,
              ),
              onPressed: _initiatePayment,
              child: Text(
                'PROCEED TO PAYMENT',
                style: CommutasTextStyles.buttonLabel,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 12, color: CommutasColors.slateMuted),
                const SizedBox(width: 4),
                Text(
                  'Secured by Safepay',
                  style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        // Animated bouncing bus
        SizedBox(
          width: 120,
          height: 80,
          child: AnimatedBuilder(
            animation: _busController,
            builder: (context, child) {
              return CustomPaint(
                painter: _TopUpBusPainter(animationValue: _busController.value),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'INITIALIZING PAYMENT',
          style: CommutasTextStyles.labelBold.copyWith(letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          'Connecting to Safepay gateway...',
          style: CommutasTextStyles.bodySmall,
        ),
        const SizedBox(height: 24),
        // Linear progress indicator
        Container(
          height: 3,
          color: CommutasColors.cobaltTint,
          child: const LinearProgressIndicator(
            backgroundColor: Color(0xFFEEF0FC),
            valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.accentCobalt),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Sketchy bouncing bus painter for the top-up loading state
// ──────────────────────────────────────────────────────────
class _TopUpBusPainter extends CustomPainter {
  final double animationValue;

  _TopUpBusPainter({required this.animationValue});

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

    // Body
    canvas.drawLine(Offset(left, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);

    // Front windshield
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 24, top + 6), paint);
    canvas.drawLine(Offset(left + 24, top + 6), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 18), Offset(left + 24, top + 18), paint);
    canvas.drawLine(Offset(left + 8, top + 6), Offset(left + 8, top + 18), paint);

    // Windows
    for (int i = 0; i < 3; i++) {
      final double wx = left + 32.0 + i * 20.0;
      canvas.drawRect(Rect.fromLTWH(wx, top + 6, 14, 12), paint);
    }

    // Headlights
    canvas.drawLine(Offset(left, bottom - 10), Offset(left - 4, bottom - 10), paint);
    final rayPaint = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 14), rayPaint);
    canvas.drawLine(Offset(left - 4, bottom - 10), Offset(left - 20, bottom - 6), rayPaint);

    // Bumper
    canvas.drawLine(Offset(left - 4, bottom - 2), Offset(left + 4, bottom - 2), paint);
    canvas.drawLine(Offset(right - 4, bottom - 2), Offset(right + 4, bottom - 2), paint);

    // Wheels
    final double wheelRadius = 8.0;
    final double leftWheelX = left + 20.0;
    final double rightWheelX = right - 20.0;
    final double wheelY = bottom + 8.0 - bounce;

    canvas.drawCircle(Offset(leftWheelX, wheelY), wheelRadius, paint);
    final angle = animationValue * 2 * math.pi;
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      paint,
    );
    canvas.drawLine(
      Offset(leftWheelX, wheelY),
      Offset(leftWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      paint,
    );

    canvas.drawCircle(Offset(rightWheelX, wheelY), wheelRadius, paint);
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle), wheelY + wheelRadius * math.sin(angle)),
      paint,
    );
    canvas.drawLine(
      Offset(rightWheelX, wheelY),
      Offset(rightWheelX + wheelRadius * math.cos(angle + math.pi), wheelY + wheelRadius * math.sin(angle + math.pi)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TopUpBusPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
