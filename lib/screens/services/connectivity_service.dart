import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

enum ConnectivityState {
  checking,
  online,
  offline,
}

/// Owns device-level internet reachability for the whole application.
///
/// Connectivity_plus reports the state of a network interface only. The
/// InternetConnection checker independently verifies that the device can
/// reach the public internet, which avoids treating Wi-Fi-without-internet as
/// an online state or treating a Commutas API failure as proof of being offline.
class ConnectivityService extends ChangeNotifier with WidgetsBindingObserver {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _interfaceSubscription;
  StreamSubscription<InternetStatus>? _internetSubscription;
  InternetConnection? _internetConnection;
  Timer? _debounceTimer;

  ConnectivityState _state = ConnectivityState.checking;
  List<ConnectivityResult> _interfaces = const <ConnectivityResult>[];
  bool _started = false;
  bool _isChecking = false;
  bool _queuedCheck = false;

  ConnectivityState get state => _state;
  List<ConnectivityResult> get interfaces => List.unmodifiable(_interfaces);
  bool get isChecking => _isChecking;
  bool get isOffline => _state == ConnectivityState.offline;
  bool get isOnline => _state == ConnectivityState.online;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      _interfaces = await _connectivity.checkConnectivity();
    } catch (_) {
      _interfaces = const <ConnectivityResult>[];
    }

    _internetConnection = InternetConnection.createInstance(
      checkInterval: const Duration(seconds: 15),
      triggerStream: _connectivity.onConnectivityChanged,
    );

    _interfaceSubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _interfaces = results;
        _scheduleCheck();
      },
    );
    _internetSubscription = _internetConnection!.onStatusChange.listen(
      _handleInternetStatus,
    );

    await checkNow();
  }

  Future<bool> checkNow() async {
    if (!_started) await start();

    if (_isChecking) {
      _queuedCheck = true;
      return isOnline;
    }

    _isChecking = true;
    notifyListeners();

    try {
      final reachable = await _internetConnection!.hasInternetAccess;
      _setState(
        reachable ? ConnectivityState.online : ConnectivityState.offline,
      );
      return reachable;
    } finally {
      _isChecking = false;
      notifyListeners();

      if (_queuedCheck) {
        _queuedCheck = false;
        unawaited(checkNow());
      }
    }
  }

  void _handleInternetStatus(InternetStatus status) {
    _setState(
      status == InternetStatus.connected
          ? ConnectivityState.online
          : ConnectivityState.offline,
    );
  }

  void _scheduleCheck() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(checkNow());
    });
  }

  void _setState(ConnectivityState next) {
    if (_state == next) return;
    _state = next;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    unawaited(_interfaceSubscription?.cancel());
    unawaited(_internetSubscription?.cancel());
    final checker = _internetConnection;
    if (checker != null) unawaited(checker.dispose());
    super.dispose();
  }
}
