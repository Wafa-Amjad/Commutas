import 'package:flutter/material.dart';

import '../../theme.dart';

/// Displays a short-lived vehicle error notification at the bottom of the screen.
///
/// The optional retry action keeps the existing retry behavior available without
/// leaving a persistent error card in the page content.
void showVehicleErrorSnackBar(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
}) {
  void show() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    // Clear both the visible and queued snackbars. Repeated connection
    // callbacks must never leave old messages to appear after the trip ends.
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: CommutasColors.danger,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 4),
          elevation: 0,
          action: onRetry == null
              ? null
              : SnackBarAction(
                  label: 'RETRY NOW',
                  textColor: Colors.white,
                  onPressed: onRetry,
                ),
        ),
      );
  }

  if (ScaffoldMessenger.maybeOf(context) == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) show();
    });
  } else {
    show();
  }
}

void hideVehicleErrorSnackBar(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
}
