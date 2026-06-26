import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'dart:math' as math;
import '../theme.dart';
import 'services/wallet_service.dart';
import 'services/notification_service.dart';

class WalletScreen extends StatefulWidget {
  final String? studentRegNo;

  const WalletScreen({super.key, this.studentRegNo});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  final WalletService _walletService = WalletService();
  double _balance = 0.0;
  bool _isLoadingBalance = true;
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _transactions = [];
  String? _accessToken;
  String? _regNo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessionData();
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
      _refreshAll();
    }
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('session_token');
    _regNo = widget.studentRegNo ?? prefs.getString('session_reg_no');
    await _refreshAll();
    
    // Proactively check status on load
    if (_accessToken != null) {
      _checkPendingTransactions();
      
      // Auto-register device token for push notifications
      NotificationService().autoRegisterToken(_accessToken!);
    }
  }

  Future<void> _refreshAll() async {
    if (_accessToken == null) {
      if (mounted) {
        setState(() {
          _isLoadingBalance = false;
          _isLoadingHistory = false;
        });
      }
      return;
    }
    await Future.wait([_fetchBalance(), _fetchTransactions()]);
  }

  Future<void> _fetchBalance() async {
    if (_accessToken == null) return;
    final balance = await _walletService.fetchWalletBalance(token: _accessToken!);
    if (mounted) {
      setState(() {
        _balance = balance;
        _isLoadingBalance = false;
      });
    }
  }

  Future<void> _fetchTransactions() async {
    if (_accessToken == null) return;
    final transactions = await _walletService.fetchTransactionHistory(token: _accessToken!);
    if (mounted) {
      setState(() {
        _transactions = transactions;
        _isLoadingHistory = false;
      });
    }
  }

  void _showTopUpSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TopUpSheet(
        studentRegNo: _regNo ?? '',
        walletService: _walletService,
        onPaymentInitiated: () {
          // Refresh after returning from Safepay checkout
          _refreshAll();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.background,
      appBar: AppBar(
        title: Text('My Wallet', style: CommutasTextStyles.heading2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: CommutasColors.primaryNavy),
            onPressed: () {
              setState(() {
                _isLoadingBalance = true;
                _isLoadingHistory = true;
              });
              _refreshAll();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CommutasColors.accentCobalt,
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 32),
              Text(
                'Transaction History', 
                style: CommutasTextStyles.labelBold,
              ),
              const SizedBox(height: 16),
              _isLoadingHistory
                  ? _buildLoadingState()
                  : _transactions.isEmpty
                      ? _buildEmptyState()
                      : _buildTransactionList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final balanceText = _isLoadingBalance
        ? '---'
        : 'Rs. ${_balance.toStringAsFixed(2)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: CommutasColors.primaryNavy,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: CommutasColors.primaryNavy.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Current Balance',
            style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _isLoadingBalance
              ? const SizedBox(
                  height: 36,
                  width: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                  ),
                )
              : Text(
                  balanceText,
                  style: CommutasTextStyles.heading1.copyWith(
                    color: Colors.white,
                    fontSize: 36,
                  ),
                ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickAction(Icons.add, 'TOP UP', _showTopUpSheet),
              const SizedBox(width: 40),
              _buildQuickAction(Icons.file_download_outlined, 'REPORT', () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: CommutasTextStyles.labelCaption.copyWith(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.accentCobalt),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: CommutasColors.lineBorder,
            ),
            const SizedBox(height: 16),
            Text(
              'No Transactions Yet',
              style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.slateMuted),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment history will appear here\nafter your first top-up.',
              textAlign: TextAlign.center,
              style: CommutasTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return Column(
      children: _transactions.map((tx) => _buildTransactionItem(tx)).toList(),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final String status = tx['status'] ?? 'UNKNOWN';
    final double amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
    final String createdAt = tx['created_at'] ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'SUCCESS':
        statusColor = CommutasColors.success;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'PENDING':
        statusColor = CommutasColors.warning;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = CommutasColors.danger;
        statusIcon = Icons.error_outline;
    }

    // Parse and format date
    String formattedDate = createdAt;
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      formattedDate = '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: CommutasShapes.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.zero,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet Top-Up', style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(formattedDate, style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+ Rs. ${amount.toStringAsFixed(0)}',
                style: CommutasTextStyles.labelBold.copyWith(color: statusColor, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.zero,
                ),
                child: Text(
                  status,
                  style: CommutasTextStyles.labelBold.copyWith(fontSize: 8, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Top-Up Bottom Sheet
// ──────────────────────────────────────────────────────────
class _TopUpSheet extends StatefulWidget {
  final String studentRegNo;
  final WalletService walletService;
  final VoidCallback onPaymentInitiated;

  const _TopUpSheet({
    required this.studentRegNo,
    required this.walletService,
    required this.onPaymentInitiated,
  });

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> with TickerProviderStateMixin {
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
          // Track this transaction ID for status updates
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
                'TOP UP WALLET',
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
            'Enter an amount to add to your transit wallet',
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
// Sketchy bouncing bus painter for top-up loading state
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
