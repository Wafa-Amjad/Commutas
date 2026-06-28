import 'package:flutter/material.dart';
import '../../theme.dart';
import 'vehicle_history_screen.dart';
import 'dart:math' as math;

class VehiclePaymentCheckScreen extends StatefulWidget {
  const VehiclePaymentCheckScreen({super.key});

  @override
  State<VehiclePaymentCheckScreen> createState() => _VehiclePaymentCheckScreenState();
}

class _VehiclePaymentCheckScreenState extends State<VehiclePaymentCheckScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isProcessing = false;
  Map<String, dynamic>? _lastScanResult;

  // List of mock student devices to simulate tapping
  final List<Map<String, dynamic>> _mockStudents = [
    {
      'name': 'Mubashir Shahzaib',
      'regNo': 'FA23-BCS-065',
      'balance': 480.00,
      'status': 'SUCCESS',
    },
    {
      'name': 'Wafa Amjad',
      'regNo': 'FA23-BCS-133',
      'balance': 180.00,
      'status': 'SUCCESS',
    },
    {
      'name': 'Roonaq Imtiaz',
      'regNo': 'FA23-BCS-150',
      'balance': 620.00,
      'status': 'SUCCESS',
    },
    {
      'name': 'Simran Dev',
      'regNo': 'FA23-BCS-002',
      'balance': 15.00, // Insufficient funds
      'status': 'INSUFFICIENT_BALANCE',
    },
    {
      'name': 'Unknown Device',
      'regNo': 'N/A',
      'balance': 0.0,
      'status': 'UNREGISTERED_DEVICE',
    },
  ];

  int _mockIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _simulateStudentTap() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _lastScanResult = null;
    });

    // Simulate 1.5 second HCE handshaking & network validation
    await Future.delayed(const Duration(milliseconds: 1500));

    final mock = _mockStudents[_mockIndex];
    _mockIndex = (_mockIndex + 1) % _mockStudents.length;

    final double fare = 40.0;
    Map<String, dynamic> result;

    if (mock['status'] == 'SUCCESS') {
      final double newBalance = mock['balance'] - fare;
      result = {
        'success': true,
        'name': mock['name'],
        'regNo': mock['regNo'],
        'fare': fare,
        'balance': newBalance,
        'message': 'FARE DEDUCTION SUCCESSFUL',
      };

      // Add to transaction history
      VehicleHistoryScreen.dummyTransactions.insert(
        0,
        VehicleTransaction(
          studentName: mock['name'],
          studentRegNo: mock['regNo'],
          amount: fare,
          timestamp: DateTime.now(),
          status: 'SUCCESS',
        ),
      );
    } else if (mock['status'] == 'INSUFFICIENT_BALANCE') {
      result = {
        'success': false,
        'name': mock['name'],
        'regNo': mock['regNo'],
        'fare': 0.0,
        'balance': mock['balance'],
        'message': 'TRANSACTION DENIED: INSUFFICIENT BALANCE',
      };
      // Add failed to history
      VehicleHistoryScreen.dummyTransactions.insert(
        0,
        VehicleTransaction(
          studentName: mock['name'],
          studentRegNo: mock['regNo'],
          amount: 0.0,
          timestamp: DateTime.now(),
          status: 'FAILED',
        ),
      );
    } else {
      result = {
        'success': false,
        'name': 'Unknown NFC Device',
        'regNo': 'UNKNOWN_UID',
        'fare': 0.0,
        'balance': 0.0,
        'message': 'TRANSACTION DENIED: UNREGISTERED DEVICE',
      };
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _lastScanResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('NFC Fare Collector'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              _buildNfcReaderVisual(),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _simulateStudentTap,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.touch_app_rounded, color: Colors.white),
                label: Text(
                  _isProcessing ? 'SCANNING DEVICE...' : 'SIMULATE STUDENT TAP',
                  style: CommutasTextStyles.labelBold.copyWith(color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
              const SizedBox(height: 24),
              if (_lastScanResult != null) _buildPaymentCheckCard(),
              if (_lastScanResult == null && !_isProcessing) _buildInstructionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNfcReaderVisual() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing squares to match flat retro/rectangular feel
        for (int i = 0; i < 3; i++)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final double value = (_pulseController.value + (i * 0.33)) % 1.0;
              return Container(
                width: 140.0 + (value * 80),
                height: 140.0 + (value * 80),
                decoration: BoxDecoration(
                  color: _isProcessing
                      ? CommutasColors.accentCobalt.withOpacity(0.05 * (1.0 - value))
                      : CommutasColors.emeraldGreen.withOpacity(0.05 * (1.0 - value)),
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: _isProcessing
                        ? CommutasColors.accentCobalt.withOpacity(0.15 * (1.0 - value))
                        : CommutasColors.emeraldGreen.withOpacity(0.15 * (1.0 - value)),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: CommutasColors.primaryNavy,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: _isProcessing
                    ? CommutasColors.accentCobalt.withOpacity(0.3)
                    : CommutasColors.emeraldGreen.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.nfc_rounded,
                color: _isProcessing ? CommutasColors.accentCobalt : Colors.white,
                size: 64,
              ),
              const SizedBox(height: 10),
              Text(
                _isProcessing ? 'READING HCE' : 'READY TO SCAN',
                style: TextStyle(
                  color: _isProcessing ? CommutasColors.accentCobalt : CommutasColors.emeraldGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: CommutasShapes.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: CommutasTextStyles.labelBold.copyWith(
              fontSize: 10,
              color: CommutasColors.slateMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildInstructionRow(Icons.phone_android_rounded, 'Student opens Commutas and selects PAY'),
          const SizedBox(height: 10),
          _buildInstructionRow(Icons.nfc_rounded, 'Student holds their device near the bus terminal'),
          const SizedBox(height: 10),
          _buildInstructionRow(Icons.check_circle_rounded, 'Fare is automatically validated and deducted'),
        ],
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: CommutasColors.primaryNavy),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: CommutasTextStyles.bodySmall.copyWith(
              color: CommutasColors.inkText,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCheckCard() {
    final success = _lastScanResult!['success'] as bool;
    final name = _lastScanResult!['name'] as String;
    final regNo = _lastScanResult!['regNo'] as String;
    final fare = _lastScanResult!['fare'] as double;
    final balance = _lastScanResult!['balance'] as double;
    final message = _lastScanResult!['message'] as String;

    return Container(
      width: double.infinity,
      decoration: CommutasShapes.cardDecoration,
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: success ? CommutasColors.emeraldGreen : CommutasColors.danger,
            child: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDENT ACCOUNT',
                          style: CommutasTextStyles.labelBold.copyWith(
                            fontSize: 9,
                            color: CommutasColors.slateMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: CommutasTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Reg No: $regNo',
                          style: CommutasTextStyles.bodySmall,
                        ),
                      ],
                    ),
                    if (success)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        color: CommutasColors.lightGreenBg,
                        child: Text(
                          '-Rs. ${fare.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: CommutasColors.emeraldGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24, color: CommutasColors.lineBorder),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CARD BALANCE',
                      style: CommutasTextStyles.bodyMedium.copyWith(
                        color: CommutasColors.slateMuted,
                      ),
                    ),
                    Text(
                      success
                          ? 'Rs. ${balance.toStringAsFixed(2)}'
                          : 'Rs. ${balance.toStringAsFixed(2)}',
                      style: CommutasTextStyles.labelBold.copyWith(
                        color: success ? CommutasColors.primaryNavy : CommutasColors.danger,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TRANSACTION TIME',
                      style: CommutasTextStyles.bodyMedium.copyWith(
                        color: CommutasColors.slateMuted,
                      ),
                    ),
                    Text(
                      'Just Now',
                      style: CommutasTextStyles.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
