import 'package:flutter/material.dart';

class WeatherData {
  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final int humidity;
  final List<DailyWeather> daily;

  const WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.humidity,
    required this.daily,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>;
    final dailyRaw = json['daily'] as Map<String, dynamic>;

    final times = (dailyRaw['time'] as List).cast<String>();
    final codes = (dailyRaw['weathercode'] as List).cast<int>();
    final maxTemps = (dailyRaw['temperature_2m_max'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    final minTemps = (dailyRaw['temperature_2m_min'] as List)
        .map((v) => (v as num).toDouble())
        .toList();
    final precip = (dailyRaw['precipitation_sum'] as List)
        .map((v) => (v as num?)?.toDouble() ?? 0.0)
        .toList();

    final daily = List.generate(times.length, (i) {
      return DailyWeather(
        date: DateTime.parse(times[i]),
        weatherCode: codes[i],
        maxTemp: maxTemps[i],
        minTemp: minTemps[i],
        precipitation: precip[i],
      );
    });

    return WeatherData(
      temperature: (current['temperature_2m'] as num).toDouble(),
      weatherCode: current['weathercode'] as int,
      windSpeed: (current['windspeed_10m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      daily: daily,
    );
  }

  String get description => _codeToDescription(weatherCode);
  IconData get icon => _codeToIcon(weatherCode);

  static String _codeToDescription(int code) {
    if (code == 0) return 'Clear Sky';
    if (code == 1) return 'Mainly Clear';
    if (code == 2) return 'Partly Cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Foggy';
    if (code >= 51 && code <= 55) return 'Drizzle';
    if (code >= 61 && code <= 65) return 'Rain';
    if (code >= 71 && code <= 75) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain Showers';
    if (code == 95) return 'Thunderstorm';
    if (code == 96 || code == 99) return 'Thunderstorm w/ Hail';
    return 'Unknown';
  }

  static IconData _codeToIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code == 1 || code == 2) return Icons.cloud_queue_rounded;
    if (code == 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 67) return Icons.grain;
    if (code >= 71 && code <= 77) return Icons.ac_unit;
    if (code >= 80 && code <= 82) return Icons.water_drop_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }
}

class DailyWeather {
  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;
  final double precipitation;

  const DailyWeather({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitation,
  });

  String get description => WeatherData._codeToDescription(weatherCode);
  IconData get icon => WeatherData._codeToIcon(weatherCode);

  String get dayLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.add(const Duration(days: 1))) return 'Tomorrow';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }
}
