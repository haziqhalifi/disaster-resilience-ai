import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import 'package:disaster_resilience_ai/models/risk_map_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/learn_module_page.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';

/// Catalogue of learning modules keyed by hazard type.
class _ModuleInfo {
  final String hazardType;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> tags;

  const _ModuleInfo({
    required this.hazardType,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tags,
  });
}

const List<_ModuleInfo> _allModules = [
  _ModuleInfo(
    hazardType: 'flood',
    title: 'Flood Preparedness',
    subtitle: 'Learn to prepare, respond and recover from floods',
    icon: Icons.water,
    color: Color(0xFF1565C0),
    tags: ['Monsoon', 'Flash Flood', 'River Overflow'],
  ),
  _ModuleInfo(
    hazardType: 'landslide',
    title: 'Landslide Safety',
    subtitle: 'Recognise warning signs and safe responses',
    icon: Icons.terrain,
    color: Color(0xFF795548),
    tags: ['Slope', 'Heavy Rainfall', 'Soil Erosion'],
  ),
  _ModuleInfo(
    hazardType: 'earthquake',
    title: 'Earthquake Response',
    subtitle: 'Drop, cover, hold on — and what comes after',
    icon: Icons.vibration,
    color: Color(0xFFE65100),
    tags: ['Tremor', 'Aftershock', 'Structural Safety'],
  ),
  _ModuleInfo(
    hazardType: 'storm',
    title: 'Storm & Typhoon',
    subtitle: 'Preparedness for tropical storms and monsoon surges',
    icon: Icons.storm,
    color: Color(0xFF37474F),
    tags: ['Typhoon', 'Strong Wind', 'Monsoon'],
  ),
  _ModuleInfo(
    hazardType: 'tsunami',
    title: 'Tsunami Awareness',
    subtitle: 'Know the signs and evacuation procedures',
    icon: Icons.waves,
    color: Color(0xFF00838F),
    tags: ['Coastal', 'Earthquake-Triggered', 'Evacuation'],
  ),
  _ModuleInfo(
    hazardType: 'haze',
    title: 'Haze & Air Quality',
    subtitle: 'Protect your health during poor air quality events',
    icon: Icons.cloud,
    color: Color(0xFF757575),
    tags: ['Pollution', 'Respiratory', 'N95 Mask'],
  ),
];

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  Position? _userPos;
  List<RiskZone> _nearbyZones = [];
  Set<String> _localHazards = {};
  Map<String, double> _masteryByHazard = {};
  double _overallMastery = 0.0;
  int _totalQuizzes = 0;

  String _tr({required String en, required String ms, String? zh}) {
    final lang = AppLanguageScope.of(context).language;
    if (lang == AppLanguage.malay) return ms;
    if (lang == AppLanguage.chinese) return zh ?? en;
    return en;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Fetch user location
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        // Fallback: show all modules
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Fetch risk zones from API
      final json = await _api.fetchMapData();
      final mapData = MapData.fromJson(json);

      // Find hazards within ~50 km of user
      final nearby = <RiskZone>[];
      for (final zone in mapData.riskZones) {
        final dist = _distanceKm(
          pos.latitude,
          pos.longitude,
          zone.latitude,
          zone.longitude,
        );
        if (dist <= 50) {
          nearby.add(zone);
        }
      }

      final hazards = nearby.map((z) => z.hazardType.toLowerCase()).toSet();

      if (mounted) {
        setState(() {
          _userPos = pos;
          _nearbyZones = nearby;
          _localHazards = hazards;
        });
      }
    } catch (_) {
      // Location failed — continue without recommendations
    }

    // Fetch learning progress
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_access_token');
      if (token != null) {
        final data = await _api.fetchLearningProgress(accessToken: token);
        final progress = data['progress'] as List? ?? [];
        final mastery = <String, double>{};
        for (final p in progress) {
          final hp = p as Map<String, dynamic>;
          mastery[hp['hazard_type'] as String] = (hp['mastery_level'] as num)
              .toDouble();
        }
        if (mounted) {
          setState(() {
            _masteryByHazard = mastery;
            _overallMastery =
                (data['overall_mastery'] as num?)?.toDouble() ?? 0;
            _totalQuizzes = (data['total_quizzes'] as num?)?.toInt() ?? 0;
          });
        }
      }
    } catch (_) {
      // Progress fetch failed — continue without it
    }

    if (mounted) setState(() => _loading = false);
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  List<_ModuleInfo> get _recommendedModules =>
      _allModules.where((m) => _localHazards.contains(m.hazardType)).toList();

  List<_ModuleInfo> get _otherModules =>
      _allModules.where((m) => !_localHazards.contains(m.hazardType)).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final barBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    final divColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Learn',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: divColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          : _error != null
          ? Center(
              child: Text(_error!, style: TextStyle(color: subtitleColor)),
            )
          : RefreshIndicator(
              onRefresh: _init,
              color: const Color(0xFF2E7D32),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                children: [
                  // Header
                  _buildHeader(isDark, titleColor, subtitleColor),
                  const SizedBox(height: 16),
                  // AI Learning Progress
                  if (_totalQuizzes > 0) ...[
                    _buildProgressCard(isDark, titleColor, subtitleColor),
                    const SizedBox(height: 24),
                  ] else
                    const SizedBox(height: 8),
                  // Recommended for your area
                  if (_recommendedModules.isNotEmpty) ...[
                    _buildSectionTitle(
                      'Recommended for Your Area',
                      Icons.gps_fixed,
                      titleColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on disaster risks near your location',
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                    const SizedBox(height: 12),
                    ..._recommendedModules.map(
                      (m) => _buildModuleCard(m, isDark, isRecommended: true),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Other modules
                  _buildSectionTitle(
                    _recommendedModules.isNotEmpty
                        ? 'Other Modules'
                        : 'All Modules',
                    Icons.menu_book,
                    titleColor,
                  ),
                  const SizedBox(height: 12),
                  ...(_recommendedModules.isNotEmpty
                          ? _otherModules
                          : _allModules)
                      .map((m) => _buildModuleCard(m, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isDark, Color titleColor, Color subtitleColor) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final riskCount = _nearbyZones.where((z) => z.zoneType == 'danger').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2D5927).withAlpha(60)
              : const Color(0xFF2D5927).withAlpha(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Color(0xFF2E7D32),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disaster Management Training',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'AI-driven learning tailored to your area',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_userPos != null && _localHazards.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: riskCount > 0
                    ? Colors.red.withAlpha(20)
                    : const Color(0xFF2E7D32).withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    riskCount > 0
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    color: riskCount > 0
                        ? Colors.red[700]
                        : const Color(0xFF2E7D32),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      riskCount > 0
                          ? '$riskCount danger zone${riskCount > 1 ? 's' : ''} nearby — ${_localHazards.join(', ')} risk detected'
                          : '${_localHazards.length} hazard type${_localHazards.length > 1 ? 's' : ''} identified near you',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: riskCount > 0
                            ? Colors.red[700]
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(
    _ModuleInfo mod,
    bool isDark, {
    bool isRecommended = false,
  }) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    final tagBg = isDark ? mod.color.withAlpha(40) : mod.color.withAlpha(20);
    final tagText = isDark ? mod.color.withAlpha(200) : mod.color;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LearnModulePage(hazardType: mod.hazardType),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: isRecommended
              ? Border.all(color: mod.color.withAlpha(100), width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: mod.color.withAlpha(isDark ? 50 : 25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(mod.icon, color: mod.color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mod.title,
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isRecommended)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: mod.color.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gps_fixed, size: 10, color: mod.color),
                              const SizedBox(width: 4),
                              Text(
                                'Nearby',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: mod.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mod.subtitle,
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: mod.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tagBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: tagText,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  // Mastery indicator
                  if (_masteryByHazard.containsKey(mod.hazardType)) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: _masteryByHazard[mod.hazardType]!,
                              backgroundColor: isDark
                                  ? const Color(0xFF263226)
                                  : const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                mod.color,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_masteryByHazard[mod.hazardType]! * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: mod.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: subtitleColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    bool isDark,
    Color titleColor,
    Color subtitleColor,
  ) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final completedModules = _masteryByHazard.values
        .where((m) => m >= 0.8)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E7D32).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              Text(
                _tr(
                  en: 'AI Learning Progress',
                  ms: 'Kemajuan Pembelajaran AI',
                  zh: 'AI学习进度',
                ),
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(en: 'Overall Mastery', ms: 'Penguasaan', zh: '总掌握度'),
                      style: TextStyle(color: subtitleColor, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _overallMastery,
                        backgroundColor: isDark
                            ? const Color(0xFF263226)
                            : const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2E7D32),
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                children: [
                  Text(
                    '${(_overallMastery * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: const Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    '$_totalQuizzes ${_tr(en: 'quizzes', ms: 'kuiz', zh: '测验')}',
                    style: TextStyle(color: subtitleColor, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          if (completedModules > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$completedModules / ${_allModules.length} ${_tr(en: 'modules mastered', ms: 'modul dikuasai', zh: '模块已掌握')}',
              style: TextStyle(
                color: const Color(0xFF2E7D32),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
