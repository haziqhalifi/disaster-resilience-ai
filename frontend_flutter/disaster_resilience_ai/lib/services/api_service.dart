import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart' show XFile;

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

  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {}
    return 'Request failed with status ${response.statusCode}';
  }

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<AuthResult> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/auth/signup'),
      body: {'username': username, 'email': email, 'password': password},
    );
    if (response.statusCode == 201) return AuthResult.fromJson(jsonDecode(response.body));
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
    if (response.statusCode == 200) return AuthResult.fromJson(jsonDecode(response.body));
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/auth/me'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
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

  Future<http.Response> _patchWithNetworkHandling(
    Uri uri, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      return await _client
          .patch(
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

  String _connectivityErrorMessage() {
    return 'Cannot reach backend at $baseUrl. Ensure FastAPI is running and '
        'use --dart-define=API_BASE_URL=http://<your-host>:8000 if needed.';
  }

  // ── Hyper-Local Early Warnings ──────────────────────────────────────────

  Future<Map<String, dynamic>> fetchNearbyWarnings({required double latitude, required double longitude}) async {
    final uri = Uri.parse('$baseUrl/api/v1/warnings/nearby').replace(
      queryParameters: {'latitude': latitude.toString(), 'longitude': longitude.toString()},
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) return jsonDecode(response.body);
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
    if (response.statusCode == 200) return jsonDecode(response.body);
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

  // ── Location & Device ─────────────────────────────────────────────────────

  /// Create and broadcast a new warning.
  /// Returns notify result containing warning_id and delivery stats.
  Future<Map<String, dynamic>> createWarning({
    required String accessToken,
    required String title,
    required String description,
    required String hazardType,
    required String alertLevel,
    required double latitude,
    required double longitude,
    required double radiusKm,
    String source = 'system',
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/warnings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: {
        'title': title,
        'description': description,
        'hazard_type': hazardType,
        'alert_level': alertLevel,
        'location': {'latitude': latitude, 'longitude': longitude},
        'radius_km': radiusKm,
        'source': source,
      },
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractErrorMessage(response));
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
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update location: ${response.statusCode}');
  }

  /// Fetch the current user's stored device record (includes phone_number).
  Future<Map<String, dynamic>> getDevice(String accessToken) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/devices/me/device'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    if (response.statusCode == 404) return {};
    throw Exception(_extractErrorMessage(response));
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
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to register device: ${response.statusCode}');
  }

  // ── Map ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchMapData({String? hazardType}) async {
    final params = <String, String>{};
    if (hazardType != null) params['hazard_type'] = hazardType;

    final uri = Uri.parse(
      '$baseUrl/api/v1/risk-map',
    ).replace(queryParameters: params.isNotEmpty ? params : null);
    final response = await _client.get(uri);
    if (response.statusCode == 200) return jsonDecode(response.body);
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
          return geometry.map((point) => {'lat': (point[1] as num).toDouble(), 'lng': (point[0] as num).toDouble()}).toList();
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

  // ── Reports ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchNearbyReports({
    required String accessToken,
    required double latitude,
    required double longitude,
    double radiusKm = 50,
    String? statusFilter,
  }) async {
    final params = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'radius_km': radiusKm.toString(),
    };
    if (statusFilter != null) params['status_filter'] = statusFilter;
    final uri = Uri.parse('$baseUrl/api/v1/reports/nearby/list').replace(
      queryParameters: params,
    );
    final response = await _getWithNetworkHandling(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> submitReport({
    required String accessToken,
    required String reportType,
    required String description,
    required double latitude,
    required double longitude,
    required String locationName,
    bool vulnerablePerson = false,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/reports/submit'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'report_type': reportType,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName,
        'vulnerable_person': vulnerablePerson,
      },
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<String> uploadReportMedia({
    required String accessToken,
    required String reportId,
    required XFile imageFile,
    String mimeType = 'image/jpeg',
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/reports/$reportId/upload-media');
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.name.isNotEmpty ? imageFile.name : 'photo.jpg';
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: MediaType.parse(mimeType),
      ));
    try {
      final streamed = await request.send().timeout(_requestTimeout);
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        return (jsonDecode(resp.body) as Map<String, dynamic>)['media_url'] as String;
      }
      throw Exception('Media upload failed: ${resp.statusCode}');
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  Future<void> vouchReport(String accessToken, String reportId) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/reports/$reportId/vouch'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  Future<void> unvouchReport(String accessToken, String reportId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/v1/reports/$reportId/vouch'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_requestTimeout);
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(_extractErrorMessage(response));
      }
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  // ── Preparedness ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchChecklist(String accessToken) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/preparedness/checklist'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<void> toggleChecklistItem(String accessToken, String itemId, bool completed) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/api/v1/preparedness/checklist/$itemId/toggle'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'completed': completed}),
      ).timeout(_requestTimeout);
      if (response.statusCode != 200) throw Exception(_extractErrorMessage(response));
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  Future<List<dynamic>> fetchEducationalTopics(String accessToken) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/preparedness/education'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception(_extractErrorMessage(response));
  }

  Future<void> markTopicViewed(String accessToken, String topicId) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/preparedness/education/$topicId/view'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {},
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractErrorMessage(response));
    }
  }

  // ── Family Groups ─────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchFamilyGroups(String accessToken) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/groups'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> createFamilyGroup({
    required String accessToken,
    required String name,
    List<Map<String, String>> members = const [],
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/groups'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'name': name,
        'members': members.map((m) => {
          'name': m['name'] ?? '',
          'phone_number': m['phone'] ?? m['phone_number'] ?? '',
          'relationship': m['relationship'] ?? '',
        }).toList(),
      },
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<void> deleteFamilyGroup({
    required String accessToken,
    required String groupId,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/v1/family/groups/$groupId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_requestTimeout);
      if (response.statusCode != 204) throw Exception(_extractErrorMessage(response));
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  Future<Map<String, dynamic>> renameFamilyGroup({
    required String accessToken,
    required String groupId,
    required String name,
  }) async {
    try {
      final response = await _client.patch(
        Uri.parse('$baseUrl/api/v1/family/groups/$groupId/rename'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'name': name}),
      ).timeout(_requestTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      throw Exception(_extractErrorMessage(response));
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  Future<Map<String, dynamic>> addFamilyMember({
    required String accessToken,
    required String groupId,
    required String name,
    String? phone,
    String? phoneNumber,
    String? relationship,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/members'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'group_id': groupId,
        'name': name,
        'phone_number': phoneNumber ?? phone ?? '',
        'relationship': relationship ?? '',
      },
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<void> deleteFamilyMember({
    required String accessToken,
    required String memberId,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/v1/family/members/$memberId'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ).timeout(_requestTimeout);
      if (response.statusCode != 204) throw Exception(_extractErrorMessage(response));
    } on TimeoutException {
      throw Exception(_connectivityErrorMessage());
    } on http.ClientException {
      throw Exception(_connectivityErrorMessage());
    }
  }

  Future<Map<String, dynamic>> familyCheckin({
    required String accessToken,
    required String memberId,
    required String status,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/checkin'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'member_id': memberId, 'status': status},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception(_extractErrorMessage(response));
  }

  /// In-app safety self-checkin — reports the current user's own safety status.
  /// The backend resolves the user's family_members row by their registered phone.
  Future<Map<String, dynamic>> selfCheckin({
    required String accessToken,
    required String status,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/family/self-checkin'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'member_id': '', 'status': status},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception(_extractErrorMessage(response));
  }

  // ── IoT Sirens ───────────────────────────────────────────────────────────

  Future<List<dynamic>> fetchSirens() async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/sirens/'),
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as List;
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> registerSiren({
    required String accessToken,
    required String name,
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
    String? endpointUrl,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/sirens/'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        if (endpointUrl != null) 'endpoint_url': endpointUrl,
      },
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> triggerSiren({
    required String accessToken,
    required String sirenId,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/sirens/$sirenId/trigger'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> stopSiren({
    required String accessToken,
    required String sirenId,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/sirens/$sirenId/stop'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> updateSirenStatus({
    required String accessToken,
    required String sirenId,
    required String status,
  }) async {
    final response = await _patchWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/sirens/$sirenId/status'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'status': status},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  // ── AI Risk Prediction ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> predictRisk(List<double> features) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/risk-map/predict'),
      body: {'features': features},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  // ── Adaptive Learning ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchLearningProgress({
    required String accessToken,
  }) async {
    final response = await _getWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/learn/progress'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> generateQuiz({
    required String accessToken,
    required String hazardType,
    int numQuestions = 5,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/learn/quiz/generate'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'hazard_type': hazardType, 'num_questions': numQuestions},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }

  Future<Map<String, dynamic>> submitQuiz({
    required String accessToken,
    required String hazardType,
    required List<Map<String, dynamic>> answers,
  }) async {
    final response = await _postWithNetworkHandling(
      Uri.parse('$baseUrl/api/v1/learn/quiz/submit'),
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'hazard_type': hazardType, 'answers': answers},
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception(_extractErrorMessage(response));
  }
}
