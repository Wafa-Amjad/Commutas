import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_hce/flutter_nfc_hce.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'services/auth_service.dart';
import 'services/wallet_service.dart';
import '../theme.dart';

/// Student payment screen with a 3-step flow:
/// Step 1: Balance & Fare Preview (fetch balance, show fare, check eligibility)
/// Step 2: Token Generation (user explicitly taps to generate)
/// Step 3: NFC/QR Broadcast (token active, countdown running)
class NFCPayScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const NFCPayScreen({
    super.key,
    this.onNavigateToTab,
  });

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
  double _walletBalance = 0.0;
  static const double fareAmount = 100.0;

  // Token broadcast
  String? _tokenId;
  int _secondsRemaining = 300;
  Timer? _timer;
  bool _hceActive = false;
  bool _hceSupported = false;
  String _statusMessage = '';

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString().replaceAll('Exception:', '').trim();
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
        String msg = e.toString().replaceAll('Exception:', '').trim();
        // Extract server detail message from DioException
        if (e is dynamic && e.toString().contains('detail')) {
          try {
            msg = e.toString();
          } catch (_) {}
        }
        setState(() {
          _errorMsg = msg;
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
          _statusMessage = 'NFC HCE is not supported on this device. Use QR Code instead.';
        });
      } else if (!isEnabled) {
        setState(() {
          _hceSupported = true;
          _statusMessage = 'NFC is disabled. Please enable it in Settings.';
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
          _statusMessage = 'READY — HOLD NEAR DRIVER\'S PHONE';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hceSupported = false;
          _statusMessage = 'Contactless sensor error. Use QR code instead.';
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

      // Poll status every 2 seconds
      if (_secondsRemaining % 2 == 0 && _tokenId != null && _step == PayStep.broadcasting) {
        _checkTokenStatus();
      }
    });
  }

  Future<void> _checkTokenStatus() async {
    if (_tokenId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';
      if (token.isEmpty) return;

      final res = await _authService.getPaymentTokenStatus(token: token, tokenId: _tokenId!);
      if (res != null && mounted) {
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
    } catch (_) {}
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
              ),
            )
          : _step == PayStep.success
              ? _buildSuccessView()
              : _step == PayStep.failure
                  ? _buildFailureView()
                  : _step == PayStep.broadcasting
                      ? _buildBroadcastView()
                      : _buildBalancePreview(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: CommutasColors.lightGreenBg,
                shape: BoxShape.rectangle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: CommutasColors.emeraldGreen,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'PAYMENT SUCCESSFUL',
              style: CommutasTextStyles.heading2.copyWith(color: CommutasColors.emeraldGreen, letterSpacing: 1.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Fare of Rs. 100.00 has been collected and logged.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: CommutasColors.primaryNavy,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                _fetchBalance(); // refresh wallet balance and go back
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CommutasColors.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: const Text(
                'DONE',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF3F3),
                shape: BoxShape.rectangle,
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: CommutasColors.danger,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'PAYMENT FAILED',
              style: CommutasTextStyles.heading2.copyWith(color: CommutasColors.danger, letterSpacing: 1.0),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMsg ?? 'Fare collection failed or ticket expired.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: CommutasColors.primaryNavy,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                _fetchBalance(); // try again
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CommutasColors.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: const Text(
                'TRY AGAIN',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── STEP 1 UI: Balance & Fare Preview ────────────────────────────────
  Widget _buildBalancePreview() {
    final bool hasSufficientBalance = _walletBalance >= fareAmount;
    final double remainingBalance = _walletBalance - fareAmount;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(Icons.contactless_outlined, size: 48, color: CommutasColors.primaryNavy),
            const SizedBox(height: 16),
            Text(
              'BOARDING TICKET',
              style: CommutasTextStyles.heading2.copyWith(letterSpacing: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a secure NFC boarding ticket to pay your fare when boarding.',
              style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Fare summary card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
              ),
              child: Column(
                children: [
                  _buildFareRow('Wallet Balance', 'Rs. ${_walletBalance.toStringAsFixed(2)}',
                      color: hasSufficientBalance ? CommutasColors.emeraldGreen : CommutasColors.danger),
                  const Divider(height: 24, color: CommutasColors.lineBorder),
                  _buildFareRow('Standard Fare', 'Rs. ${fareAmount.toStringAsFixed(2)}',
                      color: CommutasColors.primaryNavy),
                  const Divider(height: 24, color: CommutasColors.lineBorder),
                  _buildFareRow(
                    'Balance After Deduction',
                    hasSufficientBalance
                        ? 'Rs. ${remainingBalance.toStringAsFixed(2)}'
                        : '— Insufficient —',
                    color: hasSufficientBalance ? CommutasColors.slateMuted : CommutasColors.danger,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error message (from previous failed attempt)
            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  border: Border.all(color: CommutasColors.danger, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: CommutasColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action button
            if (hasSufficientBalance)
              ElevatedButton(
                onPressed: _generateToken,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text(
                  'GENERATE BOARDING TICKET',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              )
            else ...[
              // Insufficient balance warning
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  border: Border.all(color: const Color(0xFFFFB300), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFB78103), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A minimum balance of Rs. ${fareAmount.toStringAsFixed(0)} is required to generate a boarding ticket.',
                        style: CommutasTextStyles.bodySmall.copyWith(
                          color: const Color(0xFFB78103),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  widget.onNavigateToTab?.call(3); // Switch to Wallet tab
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text(
                  'GO TO WALLET & TOP UP',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Refresh balance button
            OutlinedButton(
              onPressed: _fetchBalance,
              style: OutlinedButton.styleFrom(
                foregroundColor: CommutasColors.primaryNavy,
                side: const BorderSide(color: CommutasColors.primaryNavy, width: 1.5),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('REFRESH BALANCE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: CommutasTextStyles.bodyMedium.copyWith(
            color: CommutasColors.slateMuted,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: CommutasTextStyles.bodyMedium.copyWith(
            color: color ?? CommutasColors.primaryNavy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ─── STEP 3 UI: NFC/QR Broadcast ─────────────────────────────────────
  Widget _buildBroadcastView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            _buildHceVisual(),
            const SizedBox(height: 32),
            Text(
              _hceActive ? 'Hold Near Driver\'s Phone' : 'Present QR Code to Driver',
              style: CommutasTextStyles.heading2,
            ),
            const SizedBox(height: 8),
            Text(
              _hceActive
                  ? 'Bring the back of your device close to the driver\'s phone to authorize fare deduction.'
                  : 'Show this QR code to the driver for manual fare collection.',
              textAlign: TextAlign.center,
              style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
            ),
            const SizedBox(height: 24),
            _buildBackupQrCard(),
            const SizedBox(height: 24),
            _buildStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHceVisual() {
    final bool active = _hceActive && _hceSupported;

    return Stack(
      alignment: Alignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            width: 140.0 + (i * 30),
            height: 140.0 + (i * 30),
            decoration: BoxDecoration(
              color: active
                  ? CommutasColors.emeraldGreen.withOpacity(0.05 / (i + 1))
                  : CommutasColors.slateMuted.withOpacity(0.03 / (i + 1)),
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: active
                    ? CommutasColors.emeraldGreen.withOpacity(0.12)
                    : CommutasColors.slateMuted.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: CommutasColors.primaryNavy,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: CommutasColors.lineBorder),
            boxShadow: [
              BoxShadow(
                color: (active ? CommutasColors.emeraldGreen : CommutasColors.slateMuted).withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.nfc_rounded : Icons.nfc_outlined,
                color: active ? CommutasColors.emeraldGreen : Colors.white60,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                active ? 'SENSOR ACTIVE' : 'NFC OFFLINE',
                style: TextStyle(
                  color: active ? CommutasColors.emeraldGreen : Colors.white60,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDuration(_secondsRemaining),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackupQrCard() {
    if (_tokenId == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2, color: CommutasColors.primaryNavy, size: 16),
              const SizedBox(width: 8),
              Text(
                'BACKUP TICKET QR CODE',
                style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, color: CommutasColors.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: _tokenId!,
            version: QrVersions.auto,
            size: 160.0,
            gapless: false,
            foregroundColor: CommutasColors.primaryNavy,
          ),
          const SizedBox(height: 12),
          Text(
            'Expires in: ${_formatDuration(_secondsRemaining)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: CommutasColors.slateMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final bool active = _hceActive && _hceSupported;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active ? CommutasColors.lightGreenBg : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: active ? CommutasColors.emeraldGreen : const Color(0xFFFFB300),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: active ? CommutasColors.emeraldGreen : const Color(0xFFFFB300),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: active ? CommutasColors.emeraldGreen : const Color(0xFFB78103),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
