import 'package:flutter/material.dart';
import '../theme.dart';

class CommutasErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String? secondaryText;

  const CommutasErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        border: Border.all(color: CommutasColors.danger.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: CommutasColors.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: CommutasTextStyles.bodySmall.copyWith(
                    color: CommutasColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (secondaryText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    secondaryText!,
                    style: CommutasTextStyles.bodySmall.copyWith(
                      color: CommutasColors.slateMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: CommutasColors.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

class CommutasErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  const CommutasErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: CommutasColors.slateMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommutasTextStyles.bodyMedium.copyWith(
                color: CommutasColors.primaryNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: CommutasColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
