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
import '../../theme.dart';

/// Vehicle Session Dashboard — embedded in the bottom nav (no AppBar back button).
///
/// Lifecycle: BOARDING → TRANSIT → COMPLETED
/// - BOARDING: NFC reader active, collecting student fares
/// - TRANSIT: GPS broadcasting via WebSocket, live location card, custom animated vector map
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

class _VehicleSessionScreenState extends State<VehicleSessionScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late final AnimationController _pulseController;
  final MapController _flutterMapController = MapController();

  // Session state
  late String _sessionId;
  String _status = 'BOARDING'; // BOARDING, TRANSIT, COMPLETED
  bool _isLoading = false;
  String? _errorMsg;

  // Boarding state
  final List<Map<String, dynamic>> _boardedStudents = [];
  bool _isProcessingNfc = false;
  String _nfcStatus = 'Initializing reader...';
  bool _isScanningQr = false;

  // Transit state (GPS & WebSocket)
  WebSocketChannel? _wsChannel;
  Timer? _gpsTimer;
  Position? _currentPosition;
  String _gpsStatus = 'GPS Idle';

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

  @override
  void initState() {
    super.initState();
    _sessionId = widget.sessionId;
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startNfcReader();
    _fetchSessionDetails();
  }

  Future<void> _fetchSessionDetails() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
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
      setState(() {
        _errorMsg = 'Failed to load session details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gpsTimer?.cancel();
    _feedbackTimer?.cancel();
    _closeWebSocket();
    _stopNfcReader();
    super.dispose();
  }

  // ─── NFC BOARDING READER ──────────────────────────────────────────────
  Future<void> _startNfcReader() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        setState(() {
          _nfcStatus = 'NFC Hardware unavailable. Use manual/QR scan fallback.';
        });
        return;
      }

      setState(() {
        _nfcStatus = 'READY — awaiting student taps';
      });

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          if (_isProcessingNfc || (_status != 'BOARDING' && _status != 'TRANSIT')) return;

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
            setState(() {
              _isProcessingNfc = false;
              _nfcStatus = 'Empty/Invalid NFC scan. Try again.';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _nfcStatus = 'NFC initialization failed: $e';
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
    // 1. Client-side format check (UUIDv4 validation)
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
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
      setState(() {
        _nfcStatus = 'Validation error: $e';
      });
      _showFeedback('DENIED', 'Server validation failed');
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
    setState(() {
      _isLoading = true;
      _errorMsg = null;
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
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  // ─── GPS & WEBSOCKET ──────────────────────────────────────────────────
  void _connectWebSocket() async {
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
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _wsChannel!.ready;

      debugPrint('[VehicleSession] WebSocket connected.');
      if (mounted) setState(() => _gpsStatus = 'Connected to server');

      // Listen for server-side closure so we can auto-reconnect
      _wsChannel!.stream.listen(
        (_) {}, // Vehicle doesn't receive data, only sends
        onDone: () {
          debugPrint('[VehicleSession] WebSocket closed by server.');
          if (mounted && _status == 'TRANSIT') {
            setState(() => _gpsStatus = 'Server disconnected. Reconnecting...');
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _status == 'TRANSIT') _connectWebSocket();
            });
          }
        },
        onError: (e) {
          debugPrint('[VehicleSession] WebSocket error: $e');
          if (mounted && _status == 'TRANSIT') {
            setState(() => _gpsStatus = 'Connection error. Reconnecting...');
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted && _status == 'TRANSIT') _connectWebSocket();
            });
          }
        },
      );
    } catch (e) {
      debugPrint('[VehicleSession] WebSocket connection failed: $e');
      if (mounted) {
        setState(() => _gpsStatus = 'Server connection failed. Retrying...');
      }
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _status == 'TRANSIT') _connectWebSocket();
      });
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

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _gpsStatus = 'Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _gpsStatus = 'Location permission denied');
          return;
        }
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      );
      Position pos = await Geolocator.getCurrentPosition(locationSettings: locationSettings);

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _gpsStatus = 'Broadcasting: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });

        try {
          _flutterMapController.move(
            LatLng(pos.latitude, pos.longitude),
            15.0,
          );
        } catch (_) {}

        if (_wsChannel != null) {
          try {
            _wsChannel!.sink.add(jsonEncode({
              'latitude': pos.latitude,
              'longitude': pos.longitude,
            }));
          } catch (e) {
            debugPrint('[VehicleSession] Failed to send GPS via WebSocket: $e');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gpsStatus = 'Broadcasting failed: $e');
      }
    }
  }

  // ─── END TRIP ─────────────────────────────────────────────────────────
  Future<void> _endTrip() async {
    // Confirm before ending
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('End Trip?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('This will stop location broadcasting and complete the session. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: CommutasColors.slateMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('END TRIP', style: TextStyle(color: CommutasColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      await _authService.endVehicleTrip(
        token: token,
        sessionId: _sessionId,
      );

      _gpsTimer?.cancel();
      _closeWebSocket();

      setState(() {
        _status = 'COMPLETED';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception:', '').trim();
        _isLoading = false;
      });
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      body: SafeArea(
        child: Stack(
          children: [
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
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
                          if (_errorMsg != null) _buildErrorBanner(),
                          _buildBottomAction(),
                        ],
                      ),
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
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
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
                                child: Container(
                                  color: Colors.black,
                                ),
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
                            border: Border.all(color: CommutasColors.emeraldGreen, width: 3),
                          ),
                        ),
                      ),
                      // Scanning prompt text
                      Positioned(
                        top: 40,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: isBoarding ? CommutasColors.lightGreenBg : CommutasColors.lightBlueBg,
                child: Text(
                  isBoarding ? 'BOARDING ACTIVE' : 'IN TRANSIT',
                  style: TextStyle(
                    color: isBoarding ? CommutasColors.emeraldGreen : CommutasColors.accentCobalt,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                widget.timing,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: CommutasColors.primaryNavy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.routeName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CommutasColors.primaryNavy),
          ),
          const SizedBox(height: 4),
          Text(
            widget.routePath,
            style: const TextStyle(fontSize: 11, color: CommutasColors.slateMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.people_rounded, size: 14, color: CommutasColors.slateMuted),
              const SizedBox(width: 4),
              Text(
                '${_boardedStudents.length} boarded',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CommutasColors.primaryNavy),
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
        _buildNfcRadar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BOARDED PASSENGERS',
                style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, color: CommutasColors.slateMuted),
              ),
              Text(
                '${_boardedStudents.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: CommutasColors.primaryNavy),
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
                          Icon(Icons.people_outline_rounded, color: CommutasColors.slateMuted.withValues(alpha: 0.4), size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Awaiting student taps...',
                            style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Students must hold their phone near this device',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, color: CommutasColors.slateMuted.withValues(alpha: 0.6)),
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
                    final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: CommutasColors.lineBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            color: CommutasColors.lightGreenBg,
                            child: const Icon(Icons.check_rounded, color: CommutasColors.emeraldGreen, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'] ?? 'Student',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: CommutasColors.primaryNavy),
                                ),
                                Text(
                                  '${item['regNo'] ?? 'Verified'} • ID: ${item['tokenId'].toString().substring(0, 8)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 9, color: CommutasColors.slateMuted, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 10, color: CommutasColors.slateMuted, fontFamily: 'monospace'),
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

  Widget _buildNfcRadar() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
      ),
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
                          color: CommutasColors.emeraldGreen.withValues(alpha: 0.12 * (1.0 - _pulseController.value)),
                          border: Border.all(
                            color: CommutasColors.emeraldGreen.withValues(alpha: 0.25 * (1.0 - _pulseController.value)),
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
                        : const Icon(Icons.nfc_rounded, color: Colors.white, size: 20),
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
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: CommutasColors.primaryNavy, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nfcStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _nfcStatus.contains('DENIED') || _nfcStatus.contains('error')
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
            onPressed: () {
              _stopNfcReader();
              setState(() {
                _isScanningQr = true;
              });
            },
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text(
              'SCAN STUDENT QR TICKET',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CommutasColors.primaryNavy,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── TRANSIT VIEW ─────────────────────────────────────────────────────
  Widget _buildTransitView() {
    final hasCoords = _currentPosition != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Live Map Card using flutter_map
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
            ),
            child: !hasCoords
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.primaryNavy),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Awaiting live GPS coordinates...',
                          style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                        ),
                      ],
                    ),
                  )
                : FlutterMap(
                    mapController: _flutterMapController,
                    options: MapOptions(
                      initialCenter: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'pk.edu.comsats.commutas',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
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
          ),
          const SizedBox(height: 16),

          // NFC & QR scan option during Transit
          _buildNfcRadar(),
          const SizedBox(height: 16),

          // Live GPS Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CommutasColors.lineBorder, width: 1.5),
            ),
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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: CommutasColors.accentCobalt.withValues(alpha: 0.08 * (1.0 - _pulseController.value)),
                                border: Border.all(
                                  color: CommutasColors.accentCobalt.withValues(alpha: 0.20 * (1.0 - _pulseController.value)),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          color: CommutasColors.primaryNavy,
                          child: const Icon(Icons.radar_rounded, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LIVE LOCATION BROADCAST',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: CommutasColors.primaryNavy, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _gpsStatus,
                            style: const TextStyle(fontSize: 11, color: CommutasColors.emeraldGreen, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_currentPosition != null) ...[
                  const SizedBox(height: 16),
                  const Divider(color: CommutasColors.lineBorder, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCoordTile('LATITUDE', _currentPosition!.latitude.toStringAsFixed(6)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCoordTile('LONGITUDE', _currentPosition!.longitude.toStringAsFixed(6)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trip summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CommutasColors.lineBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRIP SUMMARY',
                  style: CommutasTextStyles.labelBold.copyWith(fontSize: 10, color: CommutasColors.slateMuted),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(Icons.people_rounded, 'Passengers Boarded', '${_boardedStudents.length}'),
                const SizedBox(height: 8),
                _buildSummaryRow(Icons.account_balance_wallet_rounded, 'Fares Collected', 'Rs. ${(_boardedStudents.length * 100).toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                _buildSummaryRow(Icons.route_rounded, 'Route', widget.routeName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: CommutasColors.slateMuted, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: CommutasColors.primaryNavy, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CommutasColors.slateMuted),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: CommutasColors.slateMuted)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CommutasColors.primaryNavy),
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
              child: const Icon(Icons.check_circle_rounded, color: CommutasColors.emeraldGreen, size: 48),
            ),
            const SizedBox(height: 24),
            Text('TRIP COMPLETED', style: CommutasTextStyles.heading2.copyWith(letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              widget.routeName,
              style: CommutasTextStyles.bodyMedium.copyWith(color: CommutasColors.slateMuted),
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
                  _buildSummaryRow(Icons.people_rounded, 'Total Passengers', '${_boardedStudents.length}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow(Icons.account_balance_wallet_rounded, 'Total Fares', 'Rs. ${(_boardedStudents.length * 100).toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  _buildSummaryRow(Icons.route_rounded, 'Route', widget.routeName),
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
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                elevation: 0,
              ),
              child: const Text(
                'RETURN TO SCHEDULE',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ERROR BANNER ─────────────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFFFF3F3),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: CommutasColors.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMsg!,
              style: const TextStyle(fontSize: 11, color: CommutasColors.danger),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMsg = null),
            child: const Icon(Icons.close, size: 16, color: CommutasColors.danger),
          ),
        ],
      ),
    );
  }

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
                onPressed: _departTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
                child: const Text(
                  'DEPART — START TRIP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
              )
            : ElevatedButton(
                onPressed: _endTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CommutasColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  elevation: 0,
                ),
                child: const Text(
                  'END TRIP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                ),
              ),
      ),
    );
  }
}
