import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/models/weather_model.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';
import 'package:geolocator/geolocator.dart';

class WeatherPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const WeatherPage({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final _weatherService = WeatherService();

  WeatherData? _weather;
  bool _loading = true;
  String? _error;
  late double _activeLatitude;
  late double _activeLongitude;
  late String _activeLocationName;

  @override
  void initState() {
    super.initState();
    _activeLatitude = widget.latitude;
    _activeLongitude = widget.longitude;
    _activeLocationName = widget.locationName == 'Kuantan, Pahang'
        ? 'Current location'
        : widget.locationName;
    _refreshFromBestLocation();
  }

  Future<void> _fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _weatherService.fetchWeather(
        latitude: latitude,
        longitude: longitude,
      );
      if (mounted) {
        setState(() {
          _weather = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<bool> _applyDeviceLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return false;
      }

      final pos = await Geolocator.getCurrentPosition();

      final place = await _weatherService.fetchLocationName(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (!mounted) return false;
      setState(() {
        _activeLatitude = pos.latitude;
        _activeLongitude = pos.longitude;
        if (place != null && place.isNotEmpty) {
          _activeLocationName = place;
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshFromBestLocation() async {
    final gotDeviceLocation = await _applyDeviceLocation();
    if (!gotDeviceLocation && mounted) {
      setState(() {
        _activeLatitude = widget.latitude;
        _activeLongitude = widget.longitude;
      });
    }
    await _fetchWeather(
      latitude: _activeLatitude,
      longitude: _activeLongitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weather',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _activeLocationName,
              style: TextStyle(
                color: Colors.white.withAlpha(178),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _refreshFromBestLocation,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Fetching weather...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load weather',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refreshFromBestLocation,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: const Color(0xFF0D1B2A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final w = _weather!;
    return RefreshIndicator(
      onRefresh: _refreshFromBestLocation,
      color: const Color(0xFF4FC3F7),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentWeather(w),
            const SizedBox(height: 24),
            _buildStatsRow(w),
            const SizedBox(height: 24),
            _buildDailyForecast(w.daily),
            const SizedBox(height: 24),
            _buildDisasterNote(w),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWeather(WeatherData w) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Icon(w.icon, color: const Color(0xFF4FC3F7), size: 88),
        const SizedBox(height: 8),
        Text(
          '${w.temperature.round()}°C',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.w200,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          w.description,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        if (w.daily.isNotEmpty) ...[
          Text(
            'H: ${w.daily.first.maxTemp.round()}°  L: ${w.daily.first.minTemp.round()}°',
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsRow(WeatherData w) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(38)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(Icons.water_drop_outlined, '${w.humidity}%', 'Humidity'),
          _buildDivider(),
          _buildStat(Icons.air, '${w.windSpeed.round()} km/h', 'Wind'),
          _buildDivider(),
          if (w.daily.isNotEmpty)
            _buildStat(
              Icons.umbrella_rounded,
              '${w.daily.first.precipitation.toStringAsFixed(1)} mm',
              'Precip.',
            ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4FC3F7), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.white.withAlpha(51));
  }

  Widget _buildDailyForecast(List<DailyWeather> days) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: Colors.white54,
                size: 14,
              ),
              SizedBox(width: 6),
              Text(
                '7-DAY FORECAST',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...days.map((day) => _buildDayRow(day, day == days.last)),
        ],
      ),
    );
  }

  Widget _buildDayRow(DailyWeather day, bool isLast) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  day.dayLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              Icon(day.icon, color: const Color(0xFF4FC3F7), size: 20),
              const Spacer(),
              Text(
                '${day.minTemp.round()}°',
                style: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(width: 8),
              _buildTempBar(day),
              const SizedBox(width: 8),
              Text(
                '${day.maxTemp.round()}°',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: Colors.white.withAlpha(26), height: 0),
      ],
    );
  }

  Widget _buildTempBar(DailyWeather day) {
    // Normalize bar width between minTemp and maxTemp relative to the day range
    const double barWidth = 60;
    return Container(
      width: barWidth,
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          colors: [const Color(0xFF4FC3F7), _tempColor(day.maxTemp)],
        ),
      ),
    );
  }

  Color _tempColor(double temp) {
    if (temp >= 35) return Colors.red[400]!;
    if (temp >= 30) return Colors.orange[400]!;
    if (temp >= 25) return Colors.yellow[600]!;
    return const Color(0xFF4FC3F7);
  }

  Widget _buildDisasterNote(WeatherData w) {
    final isRainy = w.weatherCode >= 51 && w.weatherCode <= 99;
    final isThunder = w.weatherCode >= 95;

    if (!isRainy) return const SizedBox.shrink();

    final (color, icon, title, body) = isThunder
        ? (
            Colors.red[900]!,
            Icons.thunderstorm_rounded,
            'Thunderstorm Warning',
            'Heavy storms detected. Avoid flooded areas and elevated ground. Stay indoors and away from windows.',
          )
        : (
            Colors.orange[900]!,
            Icons.warning_amber_rounded,
            'Flood Risk Advisory',
            'Rainfall may cause localised flooding. Monitor drainage systems and be ready to evacuate low-lying areas.',
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(180)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
