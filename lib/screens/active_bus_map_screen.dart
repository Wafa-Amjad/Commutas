import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  
  // Connection state
  WebSocket? _webSocket;
  String _connectionStatus = 'CONNECTING'; // CONNECTING, CONNECTED, DISCONNECTED
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  @override
  void initState() {
    super.initState();
    
    // Set initial position if provided by the active buses API call
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _busPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _hasCoordinates = true;
    } else {
      // Fallback: Default to COMSATS Abbottabad Campus coordinates
      _busPosition = const LatLng(34.1912, 73.2418);
    }

    _connectWebSocket();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _closeWebSocket();
    _flutterMapController.dispose();
    super.dispose();
  }

  void _closeWebSocket() {
    _webSocket?.close();
    _webSocket = null;
  }

  void _connectWebSocket() async {
    _reconnectTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _connectionStatus = 'CONNECTING';
    });

    try {
      final serverUrl = AuthService.serverAddress
          .replaceAll('https://', 'wss://')
          .replaceAll('http://', 'ws://');
      final wsUrl = '$serverUrl/ws/student/route/${widget.routeId}';

      _webSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 10));
      
      if (mounted) {
        setState(() {
          _connectionStatus = 'CONNECTED';
          _reconnectAttempts = 0;
        });
      }

      // Listen for broadcasts from the vehicle
      _webSocket!.listen(
        (message) {
          if (!mounted) return;
          try {
            final payload = jsonDecode(message);
            final double? lat = payload['latitude'] != null ? (payload['latitude'] as num).toDouble() : null;
            final double? lng = payload['longitude'] != null ? (payload['longitude'] as num).toDouble() : null;

            if (lat != null && lng != null) {
              setState(() {
                _busPosition = LatLng(lat, lng);
                _hasCoordinates = true;
              });

              // Smoothly center map to the updated coordinate
              _flutterMapController.move(LatLng(lat, lng), _flutterMapController.camera.zoom);
            }
          } catch (_) {
            // Ignore malformed payloads
          }
        },
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (!mounted) return;
    setState(() {
      _connectionStatus = 'DISCONNECTED';
    });

    // Attempt backoff reconnection
    _reconnectAttempts++;
    final backoffSeconds = _reconnectAttempts > 5 ? 15 : 5;
    
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
        return 'LIVE TRACKING ACTIVE';
      case 'CONNECTING':
        return 'CONNECTING TO BUS...';
      case 'DISCONNECTED':
      default:
        return 'OFFLINE - RETRYING';
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
                          // Pulse effect
                          if (_connectionStatus == 'CONNECTED')
                            _PulseAnimation(
                              color: CommutasColors.primaryNavy.withOpacity(0.3),
                            ),
                          // Bus Icon Circle
                          Container(
                            decoration: const BoxDecoration(
                              color: CommutasColors.primaryNavy,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.directions_bus_filled,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Real-time Status Overlay Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: CommutasShapes.cardDecoration.copyWith(
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getStatusText(),
                    style: CommutasTextStyles.labelBold.copyWith(
                      fontSize: 10,
                      color: _getStatusColor(),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (_connectionStatus == 'DISCONNECTED')
                    GestureDetector(
                      onTap: _connectWebSocket,
                      child: Text(
                        'RECONNECT',
                        style: CommutasTextStyles.labelBold.copyWith(
                          fontSize: 10,
                          color: CommutasColors.primaryNavy,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Floating Detail Card at bottom
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: CommutasShapes.cardDecoration.copyWith(
                color: Colors.white,
              ),
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
                            Text(
                              widget.routeName,
                              style: CommutasTextStyles.heading2.copyWith(fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bus No: ${widget.vehicleNo}',
                              style: CommutasTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
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
                        child: Text(
                          '${widget.passengersBoarded} / ${widget.maxCapacity} Full',
                          style: CommutasTextStyles.labelCaption.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_hasCoordinates) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(CommutasColors.slateMuted),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Waiting for driver GPS stream...',
                          style: CommutasTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
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
                    ),
                  ],
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}
