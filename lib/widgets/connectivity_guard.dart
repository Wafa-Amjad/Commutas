import 'package:flutter/material.dart';

import '../screens/services/connectivity_service.dart';
import 'no_internet_screen.dart';
import 'offline_banner.dart';

enum ConnectivityPresentation {
  fullScreen,
  banner,
}

class ConnectivityGuard extends StatelessWidget {
  final ConnectivityPresentation presentation;
  final WidgetBuilder builder;
  final String bannerMessage;

  const ConnectivityGuard({
    super.key,
    required this.presentation,
    required this.builder,
    this.bannerMessage = "You're offline",
  });

  @override
  Widget build(BuildContext context) {
    final service = ConnectivityService.instance;

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (service.state == ConnectivityState.offline &&
            presentation == ConnectivityPresentation.fullScreen) {
          return const NoInternetScreen();
        }

        final content = builder(context);
        if (service.state != ConnectivityState.offline ||
            presentation != ConnectivityPresentation.banner) {
          return content;
        }

        return SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              OfflineBanner(message: bannerMessage),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}
