import 'package:flutter/material.dart';
import '../theme.dart';

class NFCPayScreen extends StatelessWidget {
  const NFCPayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: const Text('NFC Contactless Pay'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              _buildNfcVisual(),
              const SizedBox(height: 48),
              Text('Hold Near Reader', style: CommutasTextStyles.heading1),
              const SizedBox(height: 12),
              Text(
                'Bring the back of your device close to the transport terminal to authorize Fare Deduction.',
                textAlign: TextAlign.center,
                style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
              ),
              const SizedBox(height: 60),
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildRecentPaymentCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNfcVisual() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing squares instead of circles for rectangular feel
        for (int i = 0; i < 3; i++)
          Container(
            width: 150.0 + (i * 30),
            height: 150.0 + (i * 30),
            decoration: BoxDecoration(
              color: CommutasColors.emeraldGreen.withOpacity(0.05 / (i + 1)),
              borderRadius: BorderRadius.zero,
              border: Border.all(color: CommutasColors.emeraldGreen.withOpacity(0.1), width: 1),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: CommutasColors.primaryNavy,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: CommutasColors.emeraldGreen.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.nfc_rounded, color: Colors.white, size: 64),
              SizedBox(height: 8),
              Text('READY', style: TextStyle(color: CommutasColors.emeraldGreen, fontWeight: FontWeight.bold, letterSpacing: 2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CommutasShapes.cardDecoration.copyWith(
        color: CommutasColors.emeraldGreen,
        border: Border.all(color: Colors.transparent),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 20),
          SizedBox(width: 12),
          Text('Sensor active & connection stable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildRecentPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: CommutasShapes.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT TRANSACTION', style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, color: CommutasColors.slateMuted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CommutasColors.lightGreenBg,
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(Icons.payment, color: CommutasColors.emeraldGreen),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Route 01 Fare', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Today, 08:24 AM', style: TextStyle(color: CommutasColors.slateMuted, fontSize: 12)),
                  ],
                ),
              ),
              const Text('Rs. 40.00', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CommutasColors.primaryNavy)),
            ],
          ),
        ],
      ),
    );
  }
}

extension on BoxDecoration {
  BoxDecoration copyWith({Color? color, Border? border, BorderRadius? borderRadius, List<BoxShadow>? boxShadow}) {
    return BoxDecoration(
      color: color ?? this.color,
      border: border ?? this.border,
      borderRadius: borderRadius ?? this.borderRadius,
      boxShadow: boxShadow ?? this.boxShadow,
    );
  }
}
