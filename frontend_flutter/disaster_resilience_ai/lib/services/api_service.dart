import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
  static const Duration _requestTimeout = Duration(seconds: 12);
  static const String _baseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Base URL of the FastAPI server.
  ///
  /// Override with `--dart-define=API_BASE_URL=http://<host>:8000`.
  /// - Web (Chrome/Edge): uses localhost directly.
  /// - Android emulator: 10.0.2.2 maps to the host machine's localhost.
  /// - Desktop/iOS: localhost works when backend runs on same machine.
  static String get baseUrl {
    if (_baseUrlOverride.trim().isNotEmpty) {
      return _baseUrlOverride.trim();
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
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
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/auth/signup'),
      body: {'username': username, 'email': email, 'password': password},
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
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/auth/signin'),
      body: {'email': email, 'password': password},
    );

    if (response.statusCode == 200) {
      return AuthResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final response = await _getWithNetworkHandling(
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

  Future<http.Response> _postWithNetworkHandling(
    Uri uri, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      return await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...?headers},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  Future<http.Response> _getWithNetworkHandling(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    try {
      return await _client.get(uri, headers: headers).timeout(_requestTimeout);
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  String _connectivityErrorMessage() {
    return 'Cannot reach backend at $baseUrl. Ensure FastAPI is running and '
        'use --dart-define=API_BASE_URL=http://<your-host>:8000 if needed.';
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
    final params = <String, String>{'active_only': activeOnly.toString()};
    if (hazardType != null) params['hazard_type'] = hazardType;
    if (alertLevel != null) params['alert_level'] = alertLevel;

    final uri = Uri.parse(
      '$baseUrl/api/v1/warnings',
    ).replace(queryParameters: params);
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
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
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
    final payload = <String, dynamic>{};
    if (fcmToken != null && fcmToken.isNotEmpty) {
      payload['fcm_token'] = fcmToken;
    }
    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      payload['phone_number'] = phoneNumber;
    }

    final response = await _client.put(
      Uri.parse('$baseUrl/api/v1/devices/me/device'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
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

    final uri = Uri.parse(
      '$baseUrl/api/v1/risk-map',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
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
    final url =
        'https://router.project-osrm.org/route/v1/driving/'
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

  // ── User Profile & Emergency Info ───────────────────────────────────────

  /// Fetch the current user's profile information.
  Future<Map<String, dynamic>> fetchProfile(String accessToken) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/profile/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  /// Update the current user's profile / emergency info.
  Future<Map<String, dynamic>> updateProfile({
    required String accessToken,
    required Map<String, dynamic> profileData,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/api/v1/profile/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(profileData),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  // ── Family Location Sharing ─────────────────────────────────────────────

  Future<Map<String, dynamic>> inviteFamilyMember({
    required String accessToken,
    required String identifier,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/invite'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'identifier': identifier},
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> fetchFamilyInvites({
    required String accessToken,
  }) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/invites'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> respondFamilyInvite({
    required String accessToken,
    required String inviteId,
    required bool accept,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/invites/$inviteId/respond'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'accept': accept},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> fetchFamilyLocations({
    required String accessToken,
  }) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/members/locations'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  // ── Community Reports ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadReportMedia({
    required String accessToken,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/reports/media/upload'),
    );
    request.headers['Authorization'] = 'Bearer $accessToken';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: _parseMediaType(contentType),
      ),
    );

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> submitCommunityReport({
    required String accessToken,
    required String reportType,
    required String description,
    required String locationName,
    required double latitude,
    required double longitude,
    bool vulnerablePerson = false,
    List<String> mediaUrls = const [],
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/reports/submit'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'report_type': reportType,
        'description': description,
        'location_name': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'vulnerable_person': vulnerablePerson,
        'media_urls': mediaUrls,
      },
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  MediaType? _parseMediaType(String contentType) {
    final chunks = contentType.split('/');
    if (chunks.length != 2) return null;
    return MediaType(chunks[0], chunks[1]);
  }

  /// Generic GET that returns decoded JSON or null on failure.
  /// Used by [NotificationService] for polling.
  Future<Map<String, dynamic>?> httpGet(Uri uri) async {
    try {
      final response = await _client.get(uri);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // Swallow — caller decides how to handle null.
    }
    return null;
  }

  // ── IoT Siren endpoints ────────────────────────────────────────────────

  Future<List<dynamic>> fetchSirens() async {
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/sirens/'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch sirens (${response.statusCode})');
  }

  Future<Map<String, dynamic>> registerSiren({
    required String accessToken,
    required String name,
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    String? endpointUrl,
    String? apiKey,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/sirens/'),
  // ── AI-Driven Learning / Quiz ─────────────────────────────────────────

  /// Generate an adaptive quiz for a hazard type.
  Future<Map<String, dynamic>> generateQuiz({
    required String accessToken,
    required String hazardType,
    int numQuestions = 5,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/learn/quiz/generate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        if (endpointUrl != null) 'endpoint_url': endpointUrl,
        if (apiKey != null) 'api_key': apiKey,
      },
    );
    if (response.statusCode == 201) {
      body: {'hazard_type': hazardType, 'num_questions': numQuestions},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> triggerSiren({
    required String accessToken,
    required String sirenId,
    String? warningId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/sirens/$sirenId/trigger'),
  /// Submit quiz answers and get graded results + recommendations.
  Future<Map<String, dynamic>> submitQuiz({
    required String accessToken,
    required String hazardType,
    required List<Map<String, String>> answers,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/learn/quiz/submit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({if (warningId != null) 'warning_id': warningId}),
      body: {'hazard_type': hazardType, 'answers': answers},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to trigger siren (${response.statusCode})');
  }

  Future<void> stopSiren({
    required String accessToken,
    required String sirenId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/sirens/$sirenId/stop'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to stop siren (${response.statusCode})');
    }
  }

  Future<void> updateSirenStatus({
    required String accessToken,
    required String sirenId,
    required String status,
  }) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/api/v1/sirens/$sirenId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update siren status (${response.statusCode})');
    }
    throw Exception(_extractErrorMessage(response));
  }

  /// Get learning progress across all hazard types.
  Future<Map<String, dynamic>> fetchLearningProgress({
    required String accessToken,
  }) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/learn/progress'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
  }
}
