import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'auth_service.dart';
import 'api_interceptor.dart';

/// OpenRouteService (ORS) Directions API client via Backend Proxy.
///
/// Communicates with FastAPI backend proxy to securely fetch routing details
/// without exposing private API keys on the mobile client.
class RoutingService {
  RoutingService._();

  static const String _baseUrl = '/api/routing/eta';

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AuthService.serverAddress,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ))..interceptors.add(ApiInterceptor());

  // Cache to avoid redundant API calls when positions haven't changed much
  static LatLng? _lastOrigin;
  static LatLng? _lastDestination;
  static RouteResult? _cachedResult;
  static const double _cacheThresholdMeters = 50.0;

  /// Fetch driving route between two points via the backend proxy.
  ///
  /// Returns [RouteResult] with distance, duration, and polyline points.
  /// Returns `null` on failure.
  static Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    // Check cache — skip API call if positions haven't moved significantly
    if (_cachedResult != null &&
        _lastOrigin != null &&
        _lastDestination != null) {
      final originMoved =
          const Distance().as(LengthUnit.Meter, origin, _lastOrigin!);
      final destMoved =
          const Distance().as(LengthUnit.Meter, destination, _lastDestination!);

      if (originMoved < _cacheThresholdMeters &&
          destMoved < _cacheThresholdMeters) {
        developer.log('RoutingService: Using cached route result',
            name: 'RoutingService');
        return _cachedResult;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token') ?? '';

      final response = await _dio.get(
        _baseUrl,
        queryParameters: {
          'start_lng': origin.longitude,
          'start_lat': origin.latitude,
          'end_lng': destination.longitude,
          'end_lat': destination.latitude,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final features = data['features'] as List?;
        if (features == null || features.isEmpty) return null;

        final feature = features[0];
        final properties = feature['properties'];
        final summary = properties['summary'];

        final double distanceMeters = (summary['distance'] as num).toDouble();
        final double durationSeconds = (summary['duration'] as num).toDouble();

        // Decode GeoJSON LineString coordinates into LatLng list
        final geometry = feature['geometry'];
        final List<dynamic> coords = geometry['coordinates'] as List;
        final List<LatLng> polylinePoints = coords.map((coord) {
          // GeoJSON is [lng, lat]
          return LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          );
        }).toList();

        final result = RouteResult(
          distanceKm: distanceMeters / 1000.0,
          durationMinutes: durationSeconds / 60.0,
          polylinePoints: polylinePoints,
        );

        // Cache the result
        _lastOrigin = origin;
        _lastDestination = destination;
        _cachedResult = result;

        developer.log(
          'RoutingService (Proxy): ${result.distanceKm.toStringAsFixed(1)} km, '
          '${result.durationMinutes.toStringAsFixed(0)} min, '
          '${polylinePoints.length} polyline points',
          name: 'RoutingService',
        );

        return result;
      }

      developer.log(
        'RoutingService (Proxy): API returned status ${response.statusCode}',
        name: 'RoutingService',
      );
      return null;
    } on DioException catch (e) {
      developer.log(
        'RoutingService (Proxy): Network error — ${e.response?.data?['detail'] ?? e.message}',
        name: 'RoutingService',
      );
      return null;
    } catch (e) {
      developer.log(
        'RoutingService (Proxy): Unexpected error — $e',
        name: 'RoutingService',
      );
      return null;
    }
  }

  /// Calculate straight-line distance as a fallback when the API is unavailable.
  static double straightLineDistanceKm(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Kilometer, a, b);
  }

  /// Clear cached route (e.g., when navigating away from the map screen).
  static void clearCache() {
    _lastOrigin = null;
    _lastDestination = null;
    _cachedResult = null;
  }
}

/// Immutable result of a routing API call.
class RouteResult {
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> polylinePoints;

  const RouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polylinePoints,
  });
}
