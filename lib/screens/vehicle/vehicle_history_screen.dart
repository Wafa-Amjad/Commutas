import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../theme.dart';

class VehicleTransaction {
  final String studentName;
  final String studentRegNo;
  final double amount;
  final DateTime timestamp;
  final String status;

  VehicleTransaction({
    required this.studentName,
    required this.studentRegNo,
    required this.amount,
    required this.timestamp,
    required this.status,
  });
}

class VehicleHistoryScreen extends StatefulWidget {
  const VehicleHistoryScreen({super.key});

  // Share transaction history globally in-memory for session interactivity
  static final List<VehicleTransaction> dummyTransactions = [
    VehicleTransaction(
      studentName: 'Mubashir Shahzaib',
      studentRegNo: 'FA23-BCS-065',
      amount: 40.0,
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      status: 'SUCCESS',
    ),
    VehicleTransaction(
      studentName: 'Wafa Amjad',
      studentRegNo: 'FA23-BCS-133',
      amount: 40.0,
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      status: 'SUCCESS',
    ),
    VehicleTransaction(
      studentName: 'Roonaq Imtiaz',
      studentRegNo: 'FA23-BCS-150',
      amount: 40.0,
      timestamp: DateTime.now().subtract(const Duration(minutes: 48)),
      status: 'SUCCESS',
    ),
    VehicleTransaction(
      studentName: 'Simran Dev',
      studentRegNo: 'FA23-BCS-002',
      amount: 0.0,
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
      status: 'FAILED',
    ),
    VehicleTransaction(
      studentName: 'Ali Khan',
      studentRegNo: 'FA23-BCS-088',
      amount: 40.0,
      timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
      status: 'SUCCESS',
    ),
  ];

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  double _calculateTotalCollected() {
    return VehicleHistoryScreen.dummyTransactions
        .where((tx) => tx.status == 'SUCCESS')
        .fold(0.0, (sum, tx) => sum + tx.amount);
  }

  int _calculateSuccessCount() {
    return VehicleHistoryScreen.dummyTransactions
        .where((tx) => tx.status == 'SUCCESS')
        .length;
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final formattedHour = dt.hour > 12 ? (dt.hour - 12).toString().padLeft(2, '0') : (dt.hour == 0 ? '12' : hour);
    return '$formattedHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final totalCollected = _calculateTotalCollected();
    final successCount = _calculateSuccessCount();

    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('Fare History'),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedFareCard(totalCollected),
            const SizedBox(height: 24),
            _buildTodaysOverview(totalCollected, successCount),
            const SizedBox(height: 32),
            Text(
              'Transaction History',
              style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.primaryNavy),
            ),
            const SizedBox(height: 16),
            VehicleHistoryScreen.dummyTransactions.isEmpty
                ? _buildEmptyState()
                : _buildTransactionList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedFareCard(double balance) {
    final Color baseColor = CommutasColors.primaryNavy;
    final Color glowColor = CommutasColors.emeraldGreen.withOpacity(0.24);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: CommutasColors.primaryNavy,
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        children: [
          // Subtle vertical lines pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _SubtleGridPainter(),
            ),
          ),
          // Glow animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                final double glowVal = 0.5 + (math.sin(_bgController.value * 2 * math.pi) * 0.3);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        glowColor.withOpacity(0.25 * glowVal),
                        Colors.transparent,
                      ],
                      radius: 1.5,
                      center: const Alignment(-0.3, -0.2),
                    ),
                  ),
                );
              },
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card chip
                Container(
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24, width: 1.5),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.white24, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      Expanded(flex: 3, child: Container()),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'TOTAL FARES COLLECTED',
                  style: CommutasTextStyles.labelBold.copyWith(color: Colors.white70, letterSpacing: 2),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Rs. ',
                          style: GoogleFonts.spaceGrotesk(
                            color: CommutasColors.emeraldGreen,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: balance.toStringAsFixed(2),
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysOverview(double totalCollected, int successCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Overview',
          style: CommutasTextStyles.labelBold.copyWith(color: CommutasColors.slateMuted, fontSize: 11),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: CommutasShapes.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          color: CommutasColors.lightGreenBg,
                          child: const Icon(Icons.payments_rounded, color: CommutasColors.emeraldGreen, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text('Total Fares', style: CommutasTextStyles.bodySmall.copyWith(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rs. ${totalCollected.toInt()}',
                      style: CommutasTextStyles.heading1.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: CommutasShapes.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          color: CommutasColors.cobaltTint,
                          child: const Icon(Icons.people_alt_rounded, color: CommutasColors.accentCobalt, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text('Total Taps', style: CommutasTextStyles.bodySmall.copyWith(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$successCount Taps',
                      style: CommutasTextStyles.heading1.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 48, color: CommutasColors.slateMuted.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(
              'No transactions recorded today',
              style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return Container(
      decoration: CommutasShapes.cardDecoration,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: VehicleHistoryScreen.dummyTransactions.length,
        itemBuilder: (context, index) {
          final tx = VehicleHistoryScreen.dummyTransactions[index];
          final isSuccess = tx.status == 'SUCCESS';
          final isLast = index == VehicleHistoryScreen.dummyTransactions.length - 1;

          final Color statusColor = isSuccess ? CommutasColors.emeraldGreen : CommutasColors.danger;
          final IconData statusIcon = isSuccess ? Icons.directions_bus_rounded : Icons.warning_amber_rounded;
          final String displayStatus = isSuccess ? 'COLLECTED' : 'FAILED';
          final String displayTitle = isSuccess ? 'Fare Collected' : 'Collection Failed';

          final formattedDate = '${tx.timestamp.day}/${tx.timestamp.month}/${tx.timestamp.year} ${_formatTime(tx.timestamp)}';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
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
                          Text(displayTitle, style: CommutasTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(formattedDate, style: CommutasTextStyles.bodySmall.copyWith(fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(
                            '${tx.studentName} (${tx.studentRegNo})',
                            style: CommutasTextStyles.labelBold.copyWith(fontSize: 9, color: CommutasColors.slateMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isSuccess ? "+" : ""} Rs. ${tx.amount.toStringAsFixed(0)}',
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
                            displayStatus,
                            style: CommutasTextStyles.labelBold.copyWith(fontSize: 8, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: CommutasColors.lineBorder),
            ],
          );
        },
      ),
    );
  }
}

class _SubtleGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 8) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SubtleGridPainter oldDelegate) => false;
}
