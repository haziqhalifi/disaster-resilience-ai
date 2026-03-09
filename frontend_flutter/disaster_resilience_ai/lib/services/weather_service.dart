import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:disaster_resilience_ai/models/weather_model.dart';

class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherData> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
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
}
