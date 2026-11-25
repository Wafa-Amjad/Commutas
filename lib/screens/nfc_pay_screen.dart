import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'services/auth_service.dart';
import 'services/wallet_service.dart';
import 'services/friendly_error_message.dart';
import '../theme.dart';
import '../widgets/commutas_error_state.dart';

/// Student payment screen with a 3-step flow:
/// Step 1: Balance & Fare Preview (fetch balance, show fare, check eligibility)
/// Step 2: Token Generation (user explicitly taps to generate)
/// Step 3: NFC/QR Broadcast (token active, countdown running)
class NFCPayScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  const NFCPayScreen({super.key, this.onNavigateToTab});

  @override
  State<NFCPayScreen> createState() => _NFCPayScreenState();
}

enum PayStep { balancePreview, generating, broadcasting, success, failure }

class _NFCPayScreenState extends State<NFCPayScreen> {
  final AuthService _authService = AuthService();
  final WalletService _walletService = WalletService();
  final _hcePlugin = FlutterNfcHce();
  // State
  PayStep _step = PayStep.balancePreview;
  bool _isLoading = true;
  String? _errorMsg;
  // Balance preview
  double? _walletBalance;
  bool _walletBalanceIsStale = false;
  static const double fareAmount = 100.0;
  // Token broadcast
  String? _tokenId;
  int _secondsRemaining = 300;
  Timer? _timer;
  bool _hceActive = false;
  bool _hceSupported = false;
  bool _isCheckingTokenStatus = false;
  String _statusMessage = '';
  String? _statusRefreshError;

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopHce();
    super.dispose();
  }

  // ─── STEP 1: Fetch wallet balance ─────────────────────────────────────

  Future<void> _fetchBalance() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _step = PayStep.balancePreview;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      if (token.isEmpty) {
        throw Exception('User is not authenticated. Please log in.');
      }
      final balance = await _walletService.fetchWalletBalance(token: token);
      if (mounted) {
        setState(() {
          _walletBalance = balance;
          _walletBalanceIsStale = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = friendlyErrorMessage(
            e,
            fallback:
                'We couldn\'t load your wallet balance. Check your connection and try again.',
          );
          _walletBalanceIsStale = _walletBalance != null;
          _isLoading = false;
        });
      }
    }
  }

  // ─── STEP 2: Generate payment token ───────────────────────────────────

  Future<void> _generateToken() async {
    setState(() {
      _step = PayStep.generating;
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      if (token.isEmpty) {
        throw Exception('User is not authenticated. Please log in.');
      }
      final res = await _authService.generatePaymentToken(token: token);
      if (res != null && res['token_id'] != null) {
        _tokenId = res['token_id'];
        _secondsRemaining = 300;
        // Transition to broadcast step
        setState(() {
          _step = PayStep.broadcasting;
          _isLoading = false;
        });
        _startTimer();
        await _checkAndStartHce();
      } else {
        throw Exception('Failed to generate secure payment token.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = friendlyErrorMessage(
            e,
            fallback:
                'We couldn\'t create your boarding ticket. Check your connection and try again.',
            connectionMessage:
                'We couldn\'t create your boarding ticket. Check your connection and try again.',
          );
          _isLoading = false;
          _step = PayStep.balancePreview;
        });
      }
    }
  }

  // ─── STEP 3: HCE broadcast ───────────────────────────────────────────

  Future<void> _checkAndStartHce() async {
    try {
      bool isSupported = await _hcePlugin.isNfcHceSupported();
      bool isEnabled = await _hcePlugin.isNfcEnabled();
      if (!mounted) return;
      if (!isSupported) {
        setState(() {
          _hceSupported = false;
          _statusMessage =
              'NFC is not available here. Show the QR code to the driver instead.';
        });
      } else if (!isEnabled) {
        setState(() {
          _hceSupported = true;
          _statusMessage =
              'NFC is off. Show the QR code to the driver instead.';
        });
      } else {
        await _hcePlugin.startNfcHce(
          _tokenId!,
          mimeType: 'text/plain',
          persistMessage: true,
        );
        setState(() {
          _hceSupported = true;
          _hceActive = true;
          _statusMessage = 'Ready — hold near the driver\'s phone.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hceSupported = false;
          _statusMessage =
              'NFC is not available here. Show the QR code to the driver instead.';
        });
      }
    }
  }

  Future<void> _stopHce() async {
    if (_hceActive) {
      try {
        await _hcePlugin.stopNfcHce();
      } catch (_) {}
      _hceActive = false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _stopHce();
          _statusMessage = 'Token expired.';
          _step = PayStep.failure;
          _errorMsg = 'Payment ticket expired. Please try again.';
          return;
        }
      });
      // Check once a second so payment confirmation feels immediate after a scan.
      if (_tokenId != null && _step == PayStep.broadcasting) {
        _checkTokenStatus();
      }
    });
  }

  Future<void> _checkTokenStatus() async {
    if (_tokenId == null || _isCheckingTokenStatus) return;
    _isCheckingTokenStatus = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      if (token.isEmpty) return;
      final res = await _authService.getPaymentTokenStatus(
        token: token,
        tokenId: _tokenId!,
      );
      if (res != null && mounted) {
        _statusRefreshError = null;
        final status = res['status'] as String?;
        if (status == 'USED') {
          _timer?.cancel();
          _stopHce();
          setState(() {
            _step = PayStep.success;
          });
        } else if (status == 'EXPIRED') {
          _timer?.cancel();
          _stopHce();
          setState(() {
            _step = PayStep.failure;
            _errorMsg = 'Payment ticket expired or rejected.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusRefreshError = friendlyErrorMessage(
            e,
            fallback:
                'We couldn\'t confirm your boarding ticket right now. Check your connection and try again.',
          );
        });
      }
    } finally {
      _isCheckingTokenStatus = false;
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  // UI only. Payment services, token lifecycle and navigation are unchanged.
  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_isLoading) {
      content = _buildLoadingView();
    } else if (_step == PayStep.success) {
      content = _buildSuccessView();
    } else if (_step == PayStep.failure) {
      content = _buildFailureView();
    } else if (_step == PayStep.broadcasting) {
      content = _buildBroadcastView();
    } else {
      content = _buildBalancePreview();
    }

    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: Text('Pay fare', style: CommutasTextStyles.heading2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: !_isLoading && _step == PayStep.balancePreview
          ? SafeArea(child: content)
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(width: double.infinity, child: content),
            ),
          ),
        ),
      ),
    );
  }

  String _money(double amount) => 'Rs. ${amount.toStringAsFixed(2)}';

  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommutasColors.lineBorder),
      ),
      child: child,
    );
  }

  Widget _primaryAction(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: CommutasColors.primaryNavy,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CommutasColors.primaryNavy.withOpacity(0.08),
          disabledForegroundColor: CommutasColors.slateMuted,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          elevation: 0,
          animationDuration: Duration.zero,
          splashFactory: NoSplash.splashFactory,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }

  // A compact, static fare header. The green rule retains the brand accent.
  Widget _buildTicketHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: CommutasColors.primaryNavy,
        border: Border(bottom: BorderSide(color: CommutasColors.sageGreen, width: 3)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Standard fare',
            style: CommutasTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 5),
          Text(
            _money(fareAmount),
            style: CommutasTextStyles.heading1.copyWith(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: CommutasTextStyles.bodyMedium.copyWith(
              color: color ?? CommutasColors.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBalancePreview() {
    final hasVerifiedBalance = _walletBalance != null;
    final canPay = hasVerifiedBalance && _walletBalance! >= fareAmount;
    final amountNeeded = hasVerifiedBalance ? fareAmount - _walletBalance! : fareAmount;

    // Keep the main action in reach, independently of the scrollable summary.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      decoration: const BoxDecoration(
                        color: CommutasColors.primaryNavy,
                        border: Border(
                          bottom: BorderSide(color: CommutasColors.sageGreen, width: 3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Standard fare',
                            style: CommutasTextStyles.bodyMedium.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _money(fareAmount),
                            style: CommutasTextStyles.heading1.copyWith(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _panel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildFareRow(
                            _walletBalanceIsStale ? 'Last known wallet balance' : 'Wallet balance',
                            hasVerifiedBalance ? _money(_walletBalance!) : 'Unavailable',
                          ),
                          const Divider(height: 28, thickness: 1, color: CommutasColors.lineBorder),
                          _buildFareRow(
                            'Balance after payment',
                            !hasVerifiedBalance ? '—' : canPay ? _money(_walletBalance! - fareAmount) : 'Insufficient balance',
                            color: hasVerifiedBalance && !canPay ? CommutasColors.danger : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_errorMsg != null) ...[
                      CommutasErrorBanner(
                        message: _errorMsg!,
                        onRetry: _fetchBalance,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (canPay) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('How to board', style: CommutasTextStyles.labelBold),
                            const SizedBox(height: 14),
                            _buildBoardingInstruction(
                              Icons.nfc_rounded,
                              'Tap to pay',
                              'Hold your phone near the driver’s phone.',
                            ),
                            const SizedBox(height: 14),
                            _buildBoardingInstruction(
                              Icons.qr_code_2,
                              'Or show your QR code',
                              'Present your boarding ticket to the driver.',
                            ),
                          ],
                        ),
                      ),
                    ] else if (hasVerifiedBalance) ...[
                      _buildNotice('Add ${_money(amountNeeded)} to your wallet to continue.', warning: true),
                    ] else if (_errorMsg == null) ...[
                      CommutasErrorBanner(message: 'Balance is unavailable right now.', onRetry: _fetchBalance),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasVerifiedBalance)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: CommutasColors.lineBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canPay) ...[
                      Text(
                        'Your fare is deducted upon confirmation.',
                        textAlign: TextAlign.center,
                        style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                      ),
                      const SizedBox(height: 10),
                      _primaryAction('Generate boarding ticket', _generateToken),
                    ] else
                      _primaryAction('Add funds', () => widget.onNavigateToTab?.call(3)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBoardingInstruction(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: CommutasColors.primaryNavy, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(description, style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    final generating = _step == PayStep.generating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTicketHero(),
        _panel(
          child: Row(
            children: [
              const Icon(Icons.hourglass_empty, size: 20, color: CommutasColors.primaryNavy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  generating ? 'Creating your boarding ticket…' : 'Checking wallet balance…',
                  style: CommutasTextStyles.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _primaryAction(generating ? 'Generating ticket…' : 'Loading balance…', null),
      ],
    );
  }

  Widget _buildNotice(String message, {bool warning = false}) {
    final color = warning ? CommutasColors.warning : CommutasColors.emeraldGreen;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: const BorderSide(color: CommutasColors.lineBorder),
          right: const BorderSide(color: CommutasColors.lineBorder),
          bottom: const BorderSide(color: CommutasColors.lineBorder),
        ),
      ),
      child: Text(
        message,
        style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.primaryNavy),
      ),
    );
  }

  Widget _buildBroadcastView() {
    final active = _hceActive && _hceSupported;
    final hasNfcStatus = _statusMessage.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: CommutasColors.primaryNavy,
            border: Border(bottom: BorderSide(color: CommutasColors.sageGreen, width: 3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Boarding ticket', style: CommutasTextStyles.heading2.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(_money(fareAmount), style: CommutasTextStyles.bodyMedium.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Expires in', style: CommutasTextStyles.bodySmall.copyWith(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    _formatDuration(_secondsRemaining),
                    style: CommutasTextStyles.heading2.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    active ? Icons.nfc_rounded : Icons.qr_code_2,
                    color: active ? CommutasColors.emeraldGreen : CommutasColors.primaryNavy,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active ? 'Tap to pay' : 'Show QR to pay',
                          style: CommutasTextStyles.heading2,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          active ? 'Hold the back of your phone near the driver’s phone.' : 'Present the QR code to the driver for fare collection.',
                          style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 26, thickness: 1, color: CommutasColors.lineBorder),
              if (_tokenId != null) ...[
                Text(
                  active ? 'Or show this QR code' : 'Boarding QR code',
                  style: CommutasTextStyles.labelBold,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Center(
                  child: QrImageView(
                    data: _tokenId!,
                    version: QrVersions.auto,
                    size: 208,
                    padding: const EdgeInsets.all(12),
                    gapless: false,
                    backgroundColor: Colors.white,
                    foregroundColor: CommutasColors.primaryNavy,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Waiting for payment confirmation',
                textAlign: TextAlign.center,
                style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (hasNfcStatus && !active) ...[
          _buildNotice(_statusMessage, warning: true),
          const SizedBox(height: 8),
        ],
        if (_statusRefreshError != null)
          _buildNotice(_statusRefreshError!, warning: true),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: CommutasColors.emeraldGreen, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Payment confirmed', style: CommutasTextStyles.heading2)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Your fare has been paid and recorded. You’re ready to ride.',
                style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
              ),
              const Divider(height: 26, thickness: 1, color: CommutasColors.lineBorder),
              _buildFareRow('Fare paid', _money(fareAmount)),
              const SizedBox(height: 12),
              _buildFareRow('Boarding status', 'Confirmed', color: CommutasColors.emeraldGreen),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _primaryAction('Done', _fetchBalance),
      ],
    );
  }

  Widget _buildFailureView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: CommutasColors.danger, size: 30),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Payment failed', style: CommutasTextStyles.heading2)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _errorMsg ?? 'Fare collection failed or ticket expired.',
                style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _primaryAction('Try again', _fetchBalance),
      ],
    );
  }
}
