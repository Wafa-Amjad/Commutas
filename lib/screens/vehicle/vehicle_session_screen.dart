import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../services/auth_service.dart';
import '../services/friendly_error_message.dart';
import '../../theme.dart';
import 'vehicle_error_snackbar.dart';
import '../../widgets/connectivity_guard.dart';
import '../services/connectivity_service.dart';

/// Vehicle Session Dashboard — embedded in the bottom nav (no AppBar back button).
///
/// Lifecycle: BOARDING → TRANSIT → COMPLETED
/// - BOARDING: NFC reader active, collecting student fares
/// - TRANSIT: GPS broadcasting via WebSocket, fare collection, expandable live map
/// - COMPLETED: Trip summary, return to schedule selection
class VehicleSessionScreen extends StatefulWidget {
  final String sessionId;
  final String scheduleId;
  final String routeName;
  final String routePath;
  final String timing;
  final String initialStatus;
  final VoidCallback? onSessionEnded;

  const VehicleSessionScreen({
    super.key,
    required this.sessionId,
    required this.scheduleId,
    required this.routeName,
    required this.routePath,
    required this.timing,
    this.initialStatus = 'created',
    this.onSessionEnded,
  });

  @override
  State<VehicleSessionScreen> createState() => _VehicleSessionScreenState();
}

class _VehicleSessionScreenState extends State<VehicleSessionScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late final AnimationController _pulseController;

  // Session state
  late String _sessionId;
  String _status = 'BOARDING'; // BOARDING, TRANSIT, COMPLETED
  bool _isLoading = false;

  // Boarding state
  final List<Map<String, dynamic>> _boardedStudents = [];
  bool _isProcessingNfc = false;
  String _nfcStatus = 'Initializing reader...';
  bool _isScanningQr = false;

  // Transit state (GPS & WebSocket)
  WebSocketChannel? _wsChannel;
  Timer? _gpsTimer;
  Timer? _reconnectTimer;
  bool _isConnectingWebSocket = false;
  bool _connectionNoticeShown = false;
  bool _wasOffline = false;
  bool _isSessionClosing = false;
  Position? _currentPosition;
  String _gpsStatus = 'GPS Idle';
  bool _isMapExpanded = false;
  Offset? _miniMapOffset;
  static const double _miniMapWidth = 164;
  static const double _miniMapHeight = 146;
  static const double _miniMapMargin = 12;

  // Feedback overlay state
  String? _feedbackType; // 'SUCCESS' or 'DENIED'
  String? _feedbackMessage;
  Timer? _feedbackTimer;

  void _showFeedback(String type, String message) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackType = type;
      _feedbackMessage = message;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _feedbackType = null;
          _feedbackMessage = null;
        });
      }
    });
  }

  void _showVehicleError(String message, {VoidCallback? onRetry}) {
    if (!mounted) return;
    showVehicleErrorSnackBar(context, message, onRetry: onRetry);
  }

  void _hideVehicleError() {
    if (!mounted) return;
    hideVehicleErrorSnackBar(context);
  }

  void _showConnectionIssue(String message, Duration retryDelay) {
    if (!mounted || _status != 'TRANSIT' || _isSessionClosing) return;

    if (ConnectivityService.instance.isOffline) {
      setState(() => _gpsStatus = 'Offline — location broadcasting paused');
      return;
    }

    setState(() => _gpsStatus = message);
    if (!_connectionNoticeShown) {
      _connectionNoticeShown = true;
      _showVehicleError(message);
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(retryDelay, () {
      _reconnectTimer = null;
      if (mounted && _status == 'TRANSIT' && !_isSessionClosing)
        _connectWebSocket();
    });
  }

  void _handleConnectionRestored() {
    _connectionNoticeShown = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (!mounted) return;

    _hideVehicleError();
    setState(() => _gpsStatus = 'Connected to server');
  }

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    _wasOffline = ConnectivityService.instance.isOffline;
    _status = widget.initialStatus.toLowerCase() == 'active'
        ? 'TRANSIT'
        : widget.initialStatus.toLowerCase() == 'completed'
        ? 'COMPLETED'
        : 'BOARDING';
    ConnectivityService.instance.addListener(_handleConnectivityChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startNfcReader();
    _fetchSessionDetails();
  }

  Future<void> _fetchSessionDetails() async {
    if (ConnectivityService.instance.isOffline) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      final session = await _authService.getVehicleSession(
        token: token,
        sessionId: _sessionId,
      );

      if (session != null) {
        final serverStatus = session['status'];
        final boardedList = session['boarded_students'] as List?;

        setState(() {
          // Map backend status to UI state
          if (serverStatus == 'active') {
            _status = 'TRANSIT';
            _connectWebSocket();
            _startLocationBroadcasting();
          } else if (serverStatus == 'completed') {
            _status = 'COMPLETED';
            _isSessionClosing = true;
            _reconnectTimer?.cancel();
            _closeWebSocket();
            _hideVehicleError();
          } else {
            _status = 'BOARDING';
          }

          if (boardedList != null) {
            _boardedStudents.clear();
            for (var item in boardedList) {
              _boardedStudents.add({
                'student_name': item['student_name'] ?? 'Student',
                'student_reg_no': item['student_reg_no'] ?? 'Verified',
              });
            }
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      final message = friendlyErrorMessage(
        e,
        fallback:
            'Session details are currently unavailable. Please try again shortly.',
      );
      setState(() {
        _isLoading = false;
      });
      _showVehicleError(message, onRetry: _fetchSessionDetails);
    }
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_handleConnectivityChanged);
    _pulseController.dispose();
    _gpsTimer?.cancel();
    _reconnectTimer?.cancel();
    _feedbackTimer?.cancel();
    hideVehicleErrorSnackBar(context);
    _closeWebSocket();
    _stopNfcReader();
    super.dispose();
  }

  // ─── NFC BOARDING READER ──────────────────────────────────────────────
  Future<void> _startNfcReader() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        const message =
            'NFC is not supported on this device. Please use the QR code instead.';
        setState(() {
          _nfcStatus = message;
        });
        return;
      }

      setState(() {
        _nfcStatus = 'READY — awaiting student taps';
      });

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          if (_isProcessingNfc ||
              (_status != 'BOARDING' && _status != 'TRANSIT'))
            return;

          setState(() {
            _isProcessingNfc = true;
            _nfcStatus = 'Reading contactless payload...';
          });

          String parsedPayload = '';
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            try {
              final message = ndef.cachedMessage ?? await ndef.read();
              for (var record in message.records) {
                parsedPayload = _decodeRecord(record);
                if (parsedPayload.isNotEmpty) break;
              }
            } catch (_) {}
          }

          if (parsedPayload.isEmpty) {
            parsedPayload = _extractRawBytes(tag);
          }

          if (parsedPayload.isNotEmpty) {
            await _validateStudentFare(parsedPayload);
          } else {
            const message =
                'No valid NFC ticket was detected. Please try again.';
            setState(() {
              _isProcessingNfc = false;
              _nfcStatus = message;
            });
          }
        },
      );
    } catch (e) {
      const message =
          'NFC is not supported on this device. Please use the QR code instead.';
      setState(() {
        _nfcStatus = message;
      });
    }
  }

  Future<void> _stopNfcReader() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  String _decodeRecord(NdefRecord record) {
    try {
      final payload = record.payload;
      if (payload.isEmpty) return '';

      if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          record.type.length == 1 &&
          record.type[0] == 0x54) {
        int status = payload[0];
        int langLen = status & 0x3F;
        if (langLen + 1 <= payload.length) {
          final textBytes = payload.sublist(1 + langLen);
          return utf8.decode(textBytes);
        }
      }
      return utf8.decode(payload, allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }

  String _extractRawBytes(NfcTag tag) {
    try {
      final Map<dynamic, dynamic> tagData = tag.data;
      for (var tech in tagData.keys) {
        final techData = tagData[tech];
        if (techData is Map && techData.containsKey('payload')) {
          final raw = techData['payload'];
          if (raw is List<int>) {
            return utf8.decode(raw, allowMalformed: true).trim();
          }
        }
      }
    } catch (_) {}
    return '';
  }

  // ─── FARE COLLECTION ──────────────────────────────────────────────────
  Future<void> _validateStudentFare(String tokenId) async {
    if (ConnectivityService.instance.isOffline) {
      if (mounted) {
        setState(() {
          _isProcessingNfc = false;
          _nfcStatus = 'Offline — fare validation paused';
        });
      }
      return;
    }
    // 1. Client-side format check (UUIDv4 validation)
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRegex.hasMatch(tokenId)) {
      setState(() {
        _nfcStatus = 'Invalid scan payload';
        _isProcessingNfc = false;
      });
      _showFeedback('DENIED', 'Invalid ticket format');
      // Re-enable HCE reader
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && (_status == 'BOARDING' || _status == 'TRANSIT')) {
          setState(() => _nfcStatus = 'READY — awaiting student taps');
        }
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      final result = await _authService.collectVehicleFare(
        token: token,
        sessionId: _sessionId,
        tokenId: tokenId,
      );

      if (result != null) {
        final studentName = result['student_name'] ?? 'Student';
        final studentReg = result['student_reg_no'] ?? 'Verified';
        setState(() {
          _boardedStudents.insert(0, {
            'tokenId': tokenId,
            'name': studentName,
            'regNo': studentReg,
            'time': DateTime.now(),
          });
          _nfcStatus = 'Fare collected ✓';
        });
        _showFeedback('SUCCESS', 'Fare Collected — $studentName');
      } else {
        setState(() {
          _nfcStatus = 'DENIED — Invalid token or insufficient balance';
        });
        _showFeedback('DENIED', 'Invalid Ticket or Insufficient Balance');
      }
    } catch (e) {
      final message = friendlyErrorMessage(
        e,
        fallback: 'Ticket validation could not be completed. Please try again.',
      );
      setState(() {
        _nfcStatus = message;
      });
    } finally {
      setState(() => _isProcessingNfc = false);
      // Cooldown then re-ready
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && (_status == 'BOARDING' || _status == 'TRANSIT')) {
          setState(() => _nfcStatus = 'READY — awaiting student taps');
        }
      });
    }
  }

  void _onQrScanned(String code) {
    if (_isProcessingNfc) return;
    setState(() {
      _isScanningQr = false;
      _isProcessingNfc = true;
      _nfcStatus = 'Processing QR ticket...';
    });
    _startNfcReader(); // Re-ready NFC
    _validateStudentFare(code.trim());
  }

  // ─── DEPART TRIP ──────────────────────────────────────────────────────
  Future<void> _departTrip() async {
    if (ConnectivityService.instance.isOffline) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      final success = await _authService.startVehicleTrip(
        token: token,
        sessionId: _sessionId,
      );

      if (success) {
        setState(() {
          _status = 'TRANSIT';
          _isLoading = false;
        });
        _connectWebSocket();
        _startLocationBroadcasting();
      } else {
        throw Exception('Server rejected departure request.');
      }
    } catch (e) {
      final message = friendlyErrorMessage(
        e,
        fallback: 'The trip could not be started. Please try again.',
      );
      setState(() {
        _isLoading = false;
      });
      _showVehicleError(message, onRetry: _departTrip);
    }
  }

  // ─── GPS & WEBSOCKET ──────────────────────────────────────────────────
  void _connectWebSocket() async {
    if (!mounted ||
        _status != 'TRANSIT' ||
        _isConnectingWebSocket ||
        _isSessionClosing)
      return;

    if (ConnectivityService.instance.isOffline) {
      if (mounted) setState(() => _gpsStatus = 'Offline — location broadcasting paused');
      return;
    }

    _isConnectingWebSocket = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _closeWebSocket();

    try {
      var serverUrl = AuthService.serverAddress
          .replaceAll('https://', 'wss://')
          .replaceAll('http://', 'ws://');
      if (serverUrl.endsWith('/')) {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
      }
      final wsUrl = '$serverUrl/ws/vehicle/$_sessionId';
      debugPrint('[VehicleSession] Connecting WebSocket to: $wsUrl');

      // Use web_socket_channel for cross-platform WebSocket support
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsChannel = channel;
      await channel.ready;

      if (!mounted || _status != 'TRANSIT' || !identical(_wsChannel, channel)) {
        await channel.sink.close(ws_status.goingAway);
        return;
      }

      debugPrint('[VehicleSession] WebSocket connected.');
      _handleConnectionRestored();

      // Listen for server-side closure so we can auto-reconnect
      channel.stream.listen(
        (_) {}, // Vehicle doesn't receive data, only sends
        onDone: () {
          debugPrint('[VehicleSession] WebSocket closed by server.');
          if (identical(_wsChannel, channel)) {
            _showConnectionIssue(
              'Connection lost. Reconnecting...',
              const Duration(seconds: 3),
            );
          }
        },
        onError: (e) {
          debugPrint('[VehicleSession] WebSocket error: $e');
          if (identical(_wsChannel, channel)) {
            _showConnectionIssue(
              'Connection interrupted. Reconnecting...',
              const Duration(seconds: 3),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('[VehicleSession] WebSocket connection failed: $e');
      _closeWebSocket();
      _showConnectionIssue(
        'Connection unavailable. Retrying...',
        const Duration(seconds: 5),
      );
    } finally {
      _isConnectingWebSocket = false;
    }
  }

  void _closeWebSocket() {
    try {
      _wsChannel?.sink.close(ws_status.goingAway);
    } catch (_) {}
    _wsChannel = null;
  }

  void _startLocationBroadcasting() {
    _gpsTimer?.cancel();
    // Fire an immediate first broadcast so students don't wait 10s
    _broadcastCurrentLocation();
    _gpsTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_status != 'TRANSIT') return;
      _broadcastCurrentLocation();
    });
  }

  Future<void> _broadcastCurrentLocation() async {
    if (_status != 'TRANSIT') return;
    if (ConnectivityService.instance.isOffline) {
      if (mounted) {
        setState(() => _gpsStatus = 'Offline — location broadcasting paused');
      }
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          const message =
              'Location services are disabled. Enable them to share vehicle location.';
          setState(() => _gpsStatus = message);
          _showVehicleError(message);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            const message =
                'Location permission is required to share vehicle location.';
            setState(() => _gpsStatus = message);
            _showVehicleError(message);
          }
          return;
        }
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      );
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _gpsStatus =
              'Broadcasting: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });

        if (_wsChannel != null) {
          try {
            _wsChannel!.sink.add(
              jsonEncode({
                'latitude': pos.latitude,
                'longitude': pos.longitude,
              }),
            );
          } catch (e) {
            debugPrint('[VehicleSession] Failed to send GPS via WebSocket: $e');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        const message =
            'Vehicle location could not be updated. Check location permissions and try again.';
        setState(() => _gpsStatus = message);
        _showVehicleError(message);
      }
    }
  }

  // ─── END TRIP ─────────────────────────────────────────────────────────
  Future<void> _endTrip() async {
    if (ConnectivityService.instance.isOffline) return;
    // Confirm before ending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          'End Trip?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will stop location broadcasting and complete the session. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: CommutasColors.slateMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'END TRIP',
              style: TextStyle(
                color: CommutasColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Stop late socket/reconnect callbacks from posting a connection message
    // while the completed-session request is in progress.
    _isSessionClosing = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _hideVehicleError();

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      await _authService.endVehicleTrip(token: token, sessionId: _sessionId);

      _gpsTimer?.cancel();
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _connectionNoticeShown = false;
      _closeWebSocket();

      setState(() {
        _status = 'COMPLETED';
        _isLoading = false;
      });
    } catch (e) {
      _isSessionClosing = false;
      final message = friendlyErrorMessage(
        e,
        fallback: 'The trip could not be completed. Please try again.',
      );
      setState(() {
        _isLoading = false;
      });
      _showVehicleError(message, onRetry: _endTrip);
    }
  }

  void _handleConnectivityChanged() {
    if (!mounted) return;
    if (ConnectivityService.instance.isOffline) {
      _wasOffline = true;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _closeWebSocket();
      if (_status == 'TRANSIT') {
        setState(() => _gpsStatus = 'Offline — location broadcasting paused');
      }
    } else if (ConnectivityService.instance.isOnline && _wasOffline) {
      _wasOffline = false;
      if (_status == 'TRANSIT') {
        _connectWebSocket();
        _broadcastCurrentLocation();
      } else if (_isLoading) {
        _fetchSessionDetails();
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ConnectivityGuard(
      presentation: ConnectivityPresentation.banner,
      builder: (context) => PopScope(
      canPop: !_isMapExpanded || _status != 'TRANSIT' || _isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isMapExpanded && _status == 'TRANSIT' && !_isLoading) {
          _toggleMapExpanded();
        }
      },
      child: Scaffold(
        backgroundColor: CommutasColors.backgroundGray,
        body: SafeArea(
          child: Stack(
            children: [
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CommutasColors.primaryNavy,
                        ),
                      ),
                    )
                  : _status == 'COMPLETED'
                  ? _buildCompletedView()
                  : Column(
                      children: [
                        _buildSessionHeader(),
                        Expanded(
                          child: _status == 'BOARDING'
                              ? _buildBoardingView()
                              : _buildTransitView(),
                        ),
                        _buildBottomAction(),
                      ],
                    ),
              // Above the dashboard, but below fare feedback and the QR scanner.
              if (!_isLoading && _status == 'TRANSIT' && _isMapExpanded)
                Positioned.fill(child: _buildExpandedMap()),
              if (_feedbackType != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.8, end: 1.0),
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(32),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                color: _feedbackType == 'SUCCESS'
                                    ? CommutasColors.lightGreenBg
                                    : const Color(0xFFFFF3F3),
                                child: Icon(
                                  _feedbackType == 'SUCCESS'
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: _feedbackType == 'SUCCESS'
                                      ? CommutasColors.emeraldGreen
                                      : CommutasColors.danger,
                                  size: 64,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _feedbackType!,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _feedbackType == 'SUCCESS'
                                      ? CommutasColors.emeraldGreen
                                      : CommutasColors.danger,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _feedbackMessage ?? '',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CommutasColors.primaryNavy,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_isScanningQr)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: MobileScanner(
                            onDetect: (capture) {
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                final String? code = barcode.rawValue;
                                if (code != null && code.isNotEmpty) {
                                  _onQrScanned(code);
                                  break;
                                }
                              }
                            },
                          ),
                        ),
                        // Semi-transparent overlay with a cutout
                        Positioned.fill(
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: 0.6),
                              BlendMode.srcOut,
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(color: Colors.black),
                                ),
                                Center(
                                  child: Container(
                                    width: 240,
                                    height: 240,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Corner borders
                        Center(
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: CommutasColors.emeraldGreen,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                        // Scanning prompt text
                        Positioned(
                          top: 40,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            color: Colors.black.withValues(alpha: 0.6),
                            child: const Text(
                              'Scan student QR boarding ticket to collect fare',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Cancel Button
                        Positioned(
                          bottom: 40,
                          left: 40,
                          right: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isScanningQr = false;
                              });
                              _startNfcReader();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: CommutasColors.primaryNavy,
                              minimumSize: const Size(double.infinity, 50),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'CANCEL SCAN',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  // ─── SESSION HEADER ───────────────────────────────────────────────────
  Widget _buildSessionHeader() {
    final isBoarding = _status == 'BOARDING';

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                color: isBoarding
                    ? CommutasColors.lightGreenBg
                    : CommutasColors.lightBlueBg,
                child: Text(
                  isBoarding ? 'BOARDING ACTIVE' : 'IN TRANSIT',
                  style: TextStyle(
                    color: isBoarding
                        ? CommutasColors.emeraldGreen
                        : CommutasColors.accentCobalt,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                widget.timing,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: CommutasColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.routeName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: CommutasColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.routePath,
            style: const TextStyle(
              fontSize: 11,
              color: CommutasColors.slateMuted,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.people_rounded,
                size: 14,
                color: CommutasColors.slateMuted,
              ),
              const SizedBox(width: 4),
              Text(
                '${_boardedStudents.length} boarded',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: CommutasColors.primaryNavy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── BOARDING VIEW ────────────────────────────────────────────────────
  Widget _buildBoardingView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _buildNfcRadar(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BOARDED PASSENGERS',
                style: CommutasTextStyles.labelBold.copyWith(
                  fontSize: 10,
                  color: CommutasColors.slateMuted,
                ),
              ),
              Text(
                '${_boardedStudents.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: CommutasColors.primaryNavy,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _boardedStudents.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            color: CommutasColors.slateMuted.withValues(
                              alpha: 0.4,
                            ),
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Awaiting student taps...',
                            style: CommutasTextStyles.bodySmall.copyWith(
                              color: CommutasColors.slateMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Students must hold their phone near this device',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: CommutasColors.slateMuted.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _boardedStudents.length,
                  itemBuilder: (ctx, idx) {
                    final item = _boardedStudents[idx];
                    final t = item['time'] as DateTime;
                    final timeStr =
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: CommutasColors.lineBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            color: CommutasColors.lightGreenBg,
                            child: const Icon(
                              Icons.check_rounded,
                              color: CommutasColors.emeraldGreen,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Student',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: CommutasColors.primaryNavy,
                                  ),
                                ),
                                Text(
                                  '${item['regNo'] ?? 'Verified'} • ID: ${item['tokenId'].toString().substring(0, 8)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: CommutasColors.slateMuted,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: CommutasColors.slateMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSessionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
      ),
      child: child,
    );
  }

  Widget _buildNfcRadar() {
    return _buildSessionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) {
                      return Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: CommutasColors.emeraldGreen.withValues(
                            alpha: 0.12 * (1.0 - _pulseController.value),
                          ),
                          border: Border.all(
                            color: CommutasColors.emeraldGreen.withValues(
                              alpha: 0.25 * (1.0 - _pulseController.value),
                            ),
                            width: 1.5,
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    color: CommutasColors.primaryNavy,
                    child: _isProcessingNfc
                        ? const Padding(
                            padding: EdgeInsets.all(10.0),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.nfc_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NFC FARE READER',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: CommutasColors.primaryNavy,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nfcStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            _nfcStatus.contains('DENIED') ||
                                _nfcStatus.contains('error')
                            ? CommutasColors.danger
                            : CommutasColors.emeraldGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: CommutasColors.lineBorder, height: 1),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: ConnectivityService.instance.isOnline
                ? () {
              _stopNfcReader();
              setState(() {
                _isScanningQr = true;
              });
            }
                : null,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text(
              'SCAN STUDENT QR TICKET',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CommutasColors.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TRANSIT VIEW ─────────────────────────────────────────────────────
  Widget _buildTransitView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The overlay is confined to the transit body: it cannot cover the
        // session header or the fixed End Trip button.
        final availableWidth =
            (constraints.maxWidth - 2 * _miniMapMargin).clamp(0.0, _miniMapWidth).toDouble();
        final availableHeight =
            (constraints.maxHeight - 2 * _miniMapMargin).clamp(0.0, _miniMapHeight).toDouble();
        final canShowMiniMap = availableWidth >= 128 && availableHeight >= 112;
        final minX = _miniMapMargin;
        final minY = _miniMapMargin;
        final maxX = (constraints.maxWidth - availableWidth - _miniMapMargin)
            .clamp(minX, double.infinity).toDouble();
        final maxY = (constraints.maxHeight - availableHeight - _miniMapMargin)
            .clamp(minY, double.infinity).toDouble();

        Offset constrain(Offset offset) => Offset(
          offset.dx.clamp(minX, maxX).toDouble(),
          offset.dy.clamp(minY, maxY).toDouble(),
        );
        final defaultOffset = Offset(maxX, maxY);
        final position = constrain(_miniMapOffset ?? defaultOffset);

        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                // Reserve scroll room so the floating map cannot permanently
                // obscure the existing fare reader or trip summary.
                padding: EdgeInsets.fromLTRB(
                  20, 20, 20,
                  canShowMiniMap ? 20 + availableHeight + _miniMapMargin : 20,
                ),
                child: Column(
                  children: [
                    _buildNfcRadar(),
                    const SizedBox(height: 16),
                    _buildTripSummaryCard(),
                    if (!canShowMiniMap) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _toggleMapExpanded,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Open bus location'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (canShowMiniMap && !_isMapExpanded)
              Positioned(
                left: position.dx,
                top: position.dy,
                width: availableWidth,
                height: availableHeight,
                child: _buildMiniMap(
                  onDrag: (details) {
                    setState(() {
                      final current = constrain(_miniMapOffset ?? defaultOffset);
                      _miniMapOffset = constrain(current + details.delta);
                    });
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTripSummaryCard() {
    return _buildSessionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TRIP SUMMARY',
            style: CommutasTextStyles.labelBold.copyWith(
              fontSize: 10,
              color: CommutasColors.slateMuted,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            Icons.people_rounded,
            'Passengers Boarded',
            '${_boardedStudents.length}',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            Icons.account_balance_wallet_rounded,
            'Fares Collected',
            'Rs. ${(_boardedStudents.length * 100).toStringAsFixed(0)}',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            Icons.route_rounded,
            'Route',
            widget.routeName,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap({required GestureDragUpdateCallback onDrag}) {
    return Semantics(
      button: true,
      label: 'Bus location. Tap to expand or drag to move. $_gpsStatus',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleMapExpanded,
        onPanUpdate: onDrag,
        child: Material(
          color: Colors.white,
          elevation: 2,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: CommutasColors.lineBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // Only the floating window receives gestures in mini mode.
                // The map itself cannot intercept taps or drag the camera.
                child: IgnorePointer(child: _buildLiveMap(interactive: false)),
              ),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                color: CommutasColors.primaryNavy,
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator, color: Colors.white70, size: 16),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bus location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _gpsStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_full_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedMap() {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            color: CommutasColors.primaryNavy,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bus location',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _gpsStatus,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Minimize map',
                  onPressed: _toggleMapExpanded,
                  icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(child: _buildLiveMap(interactive: true)),
        ],
      ),
    );
  }

  Widget _buildLiveMap({required bool interactive}) {
    final position = _currentPosition;
    if (position == null) {
      return ColoredBox(
        color: CommutasColors.backgroundGray,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_searching, color: CommutasColors.slateMuted, size: 20),
                const SizedBox(height: 4),
                Text(
                  'Awaiting live GPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CommutasColors.slateMuted, fontSize: interactive ? 13 : 10),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _VehicleLiveMap(
      position: LatLng(position.latitude, position.longitude),
      interactive: interactive,
    );
  }

  void _toggleMapExpanded() {
    if (!mounted || _status != 'TRANSIT') return;
    setState(() => _isMapExpanded = !_isMapExpanded);
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CommutasColors.slateMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: CommutasColors.slateMuted,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: CommutasColors.primaryNavy,
            ),
          ),
        ),
      ],
    );
  }

  // ─── COMPLETED VIEW ───────────────────────────────────────────────────
  Widget _buildCompletedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: CommutasColors.lightGreenBg,
              child: const Icon(
                Icons.check_circle_rounded,
                color: CommutasColors.emeraldGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'TRIP COMPLETED',
              style: CommutasTextStyles.heading2.copyWith(letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              widget.routeName,
              style: CommutasTextStyles.bodyMedium.copyWith(
                color: CommutasColors.slateMuted,
              ),
            ),
            const SizedBox(height: 24),

            // Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: CommutasColors.lineBorder),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    Icons.people_rounded,
                    'Total Passengers',
                    '${_boardedStudents.length}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    Icons.account_balance_wallet_rounded,
                    'Total Fares',
                    'Rs. ${(_boardedStudents.length * 100).toStringAsFixed(0)}',
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryRow(
                    Icons.route_rounded,
                    'Route',
                    widget.routeName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: () {
                widget.onSessionEnded?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CommutasColors.primaryNavy,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                elevation: 0,
              ),
              child: const Text(
                'RETURN TO SCHEDULE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ERROR BANNER ─────────────────────────────────────────────────────
  // ─── BOTTOM ACTION BUTTON ─────────────────────────────────────────────
  Widget _buildBottomAction() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CommutasColors.lineBorder)),
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        top: false,
        child: _status == 'BOARDING'
            ? ElevatedButton(
                onPressed: ConnectivityService.instance.isOnline
                    ? _departTrip
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'DEPART — START TRIP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: ConnectivityService.instance.isOnline
                    ? _endTrip
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'END TRIP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      ),
    );
  }
}

// Each map instance owns its controller. Switching mini/full mode never
// attaches one MapController to two FlutterMap widgets.
class _VehicleLiveMap extends StatefulWidget {
  final LatLng position;
  final bool interactive;

  const _VehicleLiveMap({required this.position, required this.interactive});

  @override
  State<_VehicleLiveMap> createState() => _VehicleLiveMapState();
}

class _VehicleLiveMapState extends State<_VehicleLiveMap> {
  final MapController _controller = MapController();
  bool _mapReady = false;
  bool _followVehicle = true;

  @override
  void didUpdateWidget(covariant _VehicleLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position.latitude != widget.position.latitude ||
        oldWidget.position.longitude != widget.position.longitude) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady && _followVehicle) _centerOnVehicle();
      });
    }
  }

  void _centerOnVehicle() {
    if (!_mapReady) return;
    _controller.move(
      widget.position,
      widget.interactive ? _controller.camera.zoom : 15.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.position,
            initialZoom: 15.0,
            interactionOptions: InteractionOptions(
              flags: widget.interactive ? InteractiveFlag.all : InteractiveFlag.none,
            ),
            onMapReady: () {
              _mapReady = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _followVehicle) _centerOnVehicle();
              });
            },
            onPositionChanged: (_, hasGesture) {
              if (widget.interactive && hasGesture) _followVehicle = false;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'pk.edu.comsats.commutas',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.position,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.directions_bus_rounded,
                    color: CommutasColors.primaryNavy,
                    size: 30,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: widget.interactive ? 10 : 8, color: Colors.black87),
              ),
            ),
          ),
        ),
        if (widget.interactive)
          Positioned(
            right: 12,
            bottom: 26,
            child: Material(
              color: Colors.white,
              elevation: 2,
              child: IconButton(
                tooltip: 'Center on bus',
                onPressed: () {
                  _followVehicle = true;
                  _centerOnVehicle();
                },
                icon: const Icon(Icons.my_location, color: CommutasColors.primaryNavy),
              ),
            ),
          ),
      ],
    );
  }
}
