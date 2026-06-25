import 'package:flutter/material.dart';
import '../theme.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.background,
      appBar: AppBar(
        title: Text('My Wallet', style: CommutasTextStyles.heading2),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 32),
            Text('Transaction History', style: CommutasTextStyles.labelBold),
            const SizedBox(height: 16),
            _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
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
          Text(
            'Rs. 0.00',
            style: CommutasTextStyles.heading1.copyWith(color: Colors.white, fontSize: 36),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildQuickAction(Icons.add, 'TOP UP'),
              const SizedBox(width: 40),
              _buildQuickAction(Icons.file_download_outlined, 'REPORT'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Column(
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
          style: CommutasTextStyles.labelCaption.copyWith(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
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
              'Your payment history will appear here\nafter your first trip.',
              textAlign: TextAlign.center,
              style: CommutasTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
