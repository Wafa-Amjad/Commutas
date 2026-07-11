import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'services/auth_service.dart';
import '../theme.dart';

class ActiveBusMapScreen extends StatefulWidget {
  final String routeId;
  final String routeName;
  final String vehicleNo;
  final double? initialLatitude;
  final double? initialLongitude;
  final int maxCapacity;
  final int passengersBoarded;

  const ActiveBusMapScreen({
    super.key,
    required this.routeId,
    required this.routeName,
    required this.vehicleNo,
    this.initialLatitude,
    this.initialLongitude,
    required this.maxCapacity,
    required this.passengersBoarded,
  });

  @override
  State<ActiveBusMapScreen> createState() => _ActiveBusMapScreenState();
}

class _ActiveBusMapScreenState extends State<ActiveBusMapScreen> with TickerProviderStateMixin {
  final MapController _flutterMapController = MapController();
  
  // Coordinates state
  LatLng? _busPosition;
  bool _hasCoordinates = false;
  
  // Dynamic capacity state
  late int _passengersBoarded;
  late int _maxCapacity;
  
  // Connection state — now using web_socket_channel (cross-platform)
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  String _connectionStatus = 'CONNECTING';
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isManualReconnecting = false;

  // Last update tracking
  DateTime? _lastUpdateTime;
  Timer? _lastUpdateDisplayTimer;
  String _lastUpdateAgo = '';

  @override
  void initState() {
    super.initState();
    _passengersBoarded = widget.passengersBoarded;
    _maxCapacity = widget.maxCapacity;
    
    // Set initial position if provided by the active buses API call
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _busPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _hasCoordinates = true;
    } else {
      // Fallback: Default to COMSATS Abbottabad Campus coordinates
      _busPosition = const LatLng(34.1912, 73.2418);
    }

    _connectWebSocket();

    // Tick every second to update the "last update X ago" display
    _lastUpdateDisplayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_lastUpdateTime != null && mounted) {
        final diff = DateTime.now().difference(_lastUpdateTime!);
        final newText = _formatDuration(diff);
        if (newText != _lastUpdateAgo) {
          setState(() {
            _lastUpdateAgo = newText;
          });
        }
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 5) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _lastUpdateDisplayTimer?.cancel();
    _closeWebSocket();
    _flutterMapController.dispose();
    super.dispose();
  }

  void _closeWebSocket() {
    _channelSubscription?.cancel();
    _channelSubscription = null;
    try {
      _channel?.sink.close(ws_status.goingAway);
    } catch (_) {}
    _channel = null;
  }

  void _connectWebSocket({bool isManual = false}) async {
    _reconnectTimer?.cancel();
    _closeWebSocket();
    if (!mounted) return;

    setState(() {
      _connectionStatus = 'CONNECTING';
      _isManualReconnecting = isManual;
    });

    try {
      var serverUrl = AuthService.serverAddress
          .replaceAll('https://', 'wss://')
          .replaceAll('http://', 'ws://');
      if (serverUrl.endsWith('/')) {
        serverUrl = serverUrl.substring(0, serverUrl.length - 1);
      }
      final wsUrl = '$serverUrl/ws/student/route/${widget.routeId}';
      debugPrint('[ActiveBusMap] Connecting to: $wsUrl');

      // web_socket_channel provides cross-platform WebSocket support
      // (works on Android, iOS, Web, Desktop — unlike dart:io WebSocket)
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for the connection to be ready (throws on failure)
      await _channel!.ready;
      debugPrint('[ActiveBusMap] WebSocket connected.');
      
      if (!mounted) return;

      setState(() {
        _connectionStatus = 'CONNECTED';
        _reconnectAttempts = 0;
        _isManualReconnecting = false;
      });

      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnected successfully'),
            backgroundColor: CommutasColors.emeraldGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Listen for broadcasts from the vehicle
      _channelSubscription = _channel!.stream.listen(
        (message) {
          if (!mounted) return;
          try {
            final payload = jsonDecode(message as String);
            final double? lat = payload['latitude'] != null
                ? (payload['latitude'] as num).toDouble()
                : null;
            final double? lng = payload['longitude'] != null
                ? (payload['longitude'] as num).toDouble()
                : null;
            final int? boarded = payload['passengers_boarded'] != null
                ? (payload['passengers_boarded'] as num).toInt()
                : null;
            final int? maxCap = payload['max_capacity'] != null
                ? (payload['max_capacity'] as num).toInt()
                : null;

            setState(() {
              if (boarded != null) {
                _passengersBoarded = boarded;
              }
              if (maxCap != null) {
                _maxCapacity = maxCap;
              }
              
              if (lat != null && lng != null) {
                _busPosition = LatLng(lat, lng);
                _hasCoordinates = true;
                _lastUpdateTime = DateTime.now();
                _lastUpdateAgo = 'just now';
              }
            });

            if (lat != null && lng != null) {
              try {
                _flutterMapController.move(
                  LatLng(lat, lng),
                  _flutterMapController.camera.zoom,
                );
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('[ActiveBusMap] Payload parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('[ActiveBusMap] Stream error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[ActiveBusMap] Stream closed (closeCode: ${_channel?.closeCode}, closeReason: ${_channel?.closeReason})');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[ActiveBusMap] Connection failed: $e');
      if (mounted && isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed. Please check your network.'),
            backgroundColor: CommutasColors.danger,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _closeWebSocket();
    if (!mounted) return;
    setState(() {
      _connectionStatus = 'DISCONNECTED';
      _isManualReconnecting = false;
    });

    _reconnectAttempts++;
    final backoffSeconds = _reconnectAttempts > 5 ? 15 : (_reconnectAttempts > 2 ? 8 : 3);
    
    debugPrint('[ActiveBusMap] Auto-reconnect in ${backoffSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      if (mounted && _connectionStatus == 'DISCONNECTED') {
        _connectWebSocket();
      }
    });
  }

  Color _getStatusColor() {
    switch (_connectionStatus) {
      case 'CONNECTED':
        return CommutasColors.emeraldGreen;
      case 'CONNECTING':
        return CommutasColors.warning;
      case 'DISCONNECTED':
      default:
        return CommutasColors.danger;
    }
  }

  String _getStatusText() {
    switch (_connectionStatus) {
      case 'CONNECTED':
        if (_lastUpdateAgo.isNotEmpty) {
          return 'LIVE • Updated $_lastUpdateAgo';
        }
        return 'LIVE TRACKING ACTIVE';
      case 'CONNECTING':
        return _isManualReconnecting ? 'RECONNECTING...' : 'CONNECTING TO BUS...';
      case 'DISCONNECTED':
      default:
        final backoff = _reconnectAttempts > 5 ? 15 : (_reconnectAttempts > 2 ? 8 : 3);
        return 'CONNECTION LOST • RETRYING IN ${backoff}s';
    }
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: CommutasShapes.cardDecoration.copyWith(color: Colors.white),
      child: Row(
        children: [
          if (_connectionStatus == 'CONNECTING')
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              ),
            )
          else
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusText(),
              style: CommutasTextStyles.labelBold.copyWith(
                fontSize: 10,
                color: _getStatusColor(),
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_connectionStatus == 'DISCONNECTED')
            GestureDetector(
              onTap: () => _connectWebSocket(isManual: true),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CommutasColors.primaryNavy,
                  border: Border.all(color: CommutasColors.primaryNavy),
                ),
                child: const Text(
                  'RETRY NOW',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordinateInfo() {
    if (!_hasCoordinates) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _connectionStatus == 'CONNECTED'
                        ? CommutasColors.primaryNavy
                        : CommutasColors.slateMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _connectionStatus == 'CONNECTED'
                      ? 'Connected. Waiting for first GPS update from driver...'
                      : _connectionStatus == 'CONNECTING'
                          ? 'Establishing connection to bus...'
                          : 'Unable to connect. Retrying automatically...',
                  style: CommutasTextStyles.bodySmall.copyWith(color: CommutasColors.slateMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The driver\'s phone broadcasts GPS every 10 seconds after departure.',
            style: CommutasTextStyles.bodySmall.copyWith(
              fontSize: 11,
              color: CommutasColors.slateMuted.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          const Icon(Icons.location_on, size: 16, color: CommutasColors.emeraldGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Location: ${_busPosition!.latitude.toStringAsFixed(5)}, ${_busPosition!.longitude.toStringAsFixed(5)}',
              style: CommutasTextStyles.bodyMedium.copyWith(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommutasColors.backgroundGray,
      appBar: AppBar(
        title: Text(widget.routeId.toUpperCase()),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. OpenStreetMap Layer
          FlutterMap(
            mapController: _flutterMapController,
            options: MapOptions(
              initialCenter: _busPosition!,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'pk.edu.comsats.commutas',
              ),
              if (_hasCoordinates)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _busPosition!,
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_connectionStatus == 'CONNECTED')
                            _PulseAnimation(
                              color: CommutasColors.primaryNavy.withOpacity(0.3),
                            ),
                          Container(
                            decoration: BoxDecoration(
                              color: _connectionStatus == 'CONNECTED'
                                  ? CommutasColors.primaryNavy
                                  : CommutasColors.slateMuted,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
                              ],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.directions_bus_filled, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Status overlay
          Positioned(top: 16, left: 16, right: 16, child: _buildStatusBar()),

          // 3. Detail card
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: CommutasShapes.cardDecoration.copyWith(color: Colors.white),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.routeName,
                              style: CommutasTextStyles.heading2.copyWith(fontSize: 16),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('Bus No: ${widget.vehicleNo}',
                              style: CommutasTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: CommutasColors.lightGreenBg,
                          border: Border.all(color: CommutasColors.emeraldGreen),
                        ),
                        child: Text('$_passengersBoarded / $_maxCapacity Full',
                          style: CommutasTextStyles.labelCaption.copyWith(fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCoordinateInfo(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseAnimation extends StatefulWidget {
  final Color color;
  const _PulseAnimation({required this.color});

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _animation = Tween<double>(begin: 0.8, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Opacity(
            opacity: (2.2 - _animation.value) / 1.4,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}
