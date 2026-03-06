import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class AuthResult {
  final String accessToken;
  final String userId;
  final String username;
  final String email;

  const AuthResult({
    required this.accessToken,
    required this.userId,
    required this.username,
    required this.email,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return AuthResult(
      accessToken: json['access_token'] as String,
      userId: user['id'] as String,
      username: user['username'] as String,
      email: user['email'] as String,
    );
  }
}

/// Service class for communicating with the FastAPI backend.
class ApiService {
  /// Base URL of the FastAPI server.
  /// - Web (Chrome/Edge): uses localhost directly.
  /// - Android emulator: 10.0.2.2 maps to the host machine's localhost.
  /// - Physical device: replace with your machine's LAN IP.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    return 'http://10.0.2.2:8000';
  }

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Ping the alerts service to verify connectivity.
  Future<Map<String, dynamic>> ping() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/alerts/ping'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Ping failed with status ${response.statusCode}');
  }

  /// Request a risk prediction from the backend.
  Future<Map<String, dynamic>> predictRisk(List<double> features) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/alerts/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'features': features}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Prediction failed with status ${response.statusCode}');
  }

  Future<AuthResult> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      return AuthResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_extractErrorMessage(response));
  }

  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/signin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      return AuthResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/auth/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception(_extractErrorMessage(response));
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // Fallback below if response body is not JSON.
    }
    return 'Request failed with status ${response.statusCode}';
  }

  // ── Hyper-Local Early Warnings ──────────────────────────────────────────

  /// Fetch active warnings near a specific coordinate.
  /// This is the core "hyper-local" feature — only returns warnings whose
  /// affected zone covers the user's current location.
  Future<Map<String, dynamic>> fetchNearbyWarnings({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/warnings/nearby/').replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch nearby warnings: ${response.statusCode}');
  }

  /// Fetch all active warnings (optionally filtered).
  Future<Map<String, dynamic>> fetchWarnings({
    bool activeOnly = true,
    String? hazardType,
    String? alertLevel,
  }) async {
    final params = <String, String>{
      'active_only': activeOnly.toString(),
    };
    if (hazardType != null) params['hazard_type'] = hazardType;
    if (alertLevel != null) params['alert_level'] = alertLevel;

    final uri = Uri.parse('$baseUrl/api/v1/warnings').replace(
      queryParameters: params,
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch warnings: ${response.statusCode}');
  }

  /// Get a single warning by ID.
  Future<Map<String, dynamic>> fetchWarning(String warningId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/warnings/$warningId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Warning not found');
  }

  /// Update the authenticated user's GPS location so the backend
  /// can send hyper-local warnings.
  Future<Map<String, dynamic>> updateLocation({
    required String accessToken,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/v1/devices/me/location'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update location: ${response.statusCode}');
  }

  /// Register device for push notifications and/or SMS fallback.
  Future<Map<String, dynamic>> registerDevice({
    required String accessToken,
    String? fcmToken,
    String? phoneNumber,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/v1/devices/me/device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (phoneNumber != null) 'phone_number': phoneNumber,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to register device: ${response.statusCode}');
  }

  // ── AI Risk Mapping ──────────────────────────────────────────────────────

  /// Fetch all map data: risk zones, evacuation centres, and routes.
  Future<Map<String, dynamic>> fetchMapData({String? hazardType}) async {
    final params = <String, String>{};
    if (hazardType != null) params['hazard_type'] = hazardType;

    final uri = Uri.parse('$baseUrl/api/v1/risk-map').replace(
      queryParameters: params.isNotEmpty ? params : null,
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch map data: ${response.statusCode}');
  }

  /// Fetch real-world road routing between two points using OSRM (Open Source Routing Machine).
  /// Returns a list of LatLng coordinates.
  Future<List<Map<String, double>>> fetchRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
  }) async {
    // Public OSRM API (no key required for low volume)
    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '$startLon,$startLat;$endLon,$endLat?overview=full&geometries=geojson';

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry']['coordinates'] as List;
          return geometry.map((point) {
            return {
              'lat': (point[1] as num).toDouble(),
              'lng': (point[0] as num).toDouble(),
            };
          }).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
