import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:disaster_resilience_ai/models/weather_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

class WeatherService {
  static const String _openMeteoUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _reverseGeoUrl =
      'https://geocoding-api.open-meteo.com/v1/reverse';
  static const String _osmReverseGeoUrl =
      'https://nominatim.openstreetmap.org/reverse';

  /// Uses backend proxy on web (avoids CORS). Direct Open-Meteo on mobile.
  Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (kIsWeb) {
      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/weather/forecast')
          .replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'timezone': 'Asia/Kuala_Lumpur',
        'forecast_days': '7',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch weather (${response.statusCode})');
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return WeatherData.fromJson(json);
    }

    final uri = Uri.parse(_openMeteoUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current':
            'temperature_2m,weathercode,windspeed_10m,relative_humidity_2m',
        'daily':
            'weathercode,temperature_2m_max,temperature_2m_min,precipitation_sum',
        'timezone': 'Asia/Kuala_Lumpur',
        'forecast_days': '7',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch weather (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return WeatherData.fromJson(json);
  }

  Future<String?> fetchLocationName({
    required double latitude,
    required double longitude,
  }) async {
    final exact = await _fetchExactLocationName(
      latitude: latitude,
      longitude: longitude,
    );
    if (exact != null && exact.isNotEmpty) {
      return exact;
    }

    return _fetchApproximateLocationName(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<String?> _fetchExactLocationName({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_osmReverseGeoUrl).replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      },
    );

    final response = await http
        .get(
          uri,
          headers: {
            'User-Agent': 'DisasterResilienceAI/1.0 (contact: app-client)',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final displayName = json['display_name']?.toString();
    if (displayName == null || displayName.isEmpty) {
      return null;
    }

    // Keep label readable while still specific.
    final parts = displayName
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    return parts.take(3).join(', ');
  }

  Future<String?> _fetchApproximateLocationName({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_reverseGeoUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'language': 'en',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return null;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final resultsRaw = json['results'];
    if (resultsRaw is! List || resultsRaw.isEmpty) {
      return null;
    }

    final first = resultsRaw.first;
    if (first is! Map<String, dynamic>) {
      return null;
    }

    final city = (first['city'] ?? first['name'] ?? first['locality'])
        ?.toString();
    final admin1 = first['admin1']?.toString();
    final country = first['country']?.toString();

    final parts = [
      if (city != null && city.isNotEmpty) city,
      if (admin1 != null && admin1.isNotEmpty) admin1,
      if ((city == null || city.isEmpty) &&
          country != null &&
          country.isNotEmpty)
        country,
    ];

    if (parts.isEmpty) {
      return null;
    }
    return parts.join(', ');
  }

  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(
        queryParameters: {
          'q': query.trim(),
          'format': 'json',
          'countrycodes': 'my',
          'limit': '6',
          'accept-language': 'en',
        },
      );
      final response = await http.get(uri, headers: {
        'User-Agent': 'DisasterResilienceApp/1.0',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((e) {
        final parts = (e['display_name'] as String).split(',');
        final name = parts.take(2).map((s) => s.trim()).join(', ');
        return {
          'name': name,
          'lat': double.parse(e['lat'].toString()),
          'lon': double.parse(e['lon'].toString()),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
