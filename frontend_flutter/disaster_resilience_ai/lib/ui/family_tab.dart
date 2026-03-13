import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/models/family_model.dart';
import 'package:disaster_resilience_ai/models/risk_map_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

class FamilyTab extends StatefulWidget {
  const FamilyTab({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<FamilyTab> createState() => _FamilyTabState();
}

class _FamilyTabState extends State<FamilyTab> {
  final ApiService _api = ApiService();
  final TextEditingController _identifierController = TextEditingController();

  bool _loading = true;
  bool _sendingInvite = false;
  String? _error;
  List<FamilyInvite> _invites = [];
  List<FamilyMemberLocation> _members = [];
  List<RiskZone> _riskZones = [];
  List<EvacuationCentre> _evacuationCentres = [];
  Timer? _pollTimer;
  // Cache: userId → place name
  final Map<String, String> _placeNames = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.fetchFamilyInvites(accessToken: widget.accessToken),
        _api.fetchFamilyLocations(accessToken: widget.accessToken),
        _api.fetchMapData(),
      ]);

      final invitesJson = (results[0]['invites'] as List<dynamic>? ?? []);
      final membersJson = (results[1]['members'] as List<dynamic>? ?? []);
      final mapJson = results[2];
      final zonesJson = (mapJson['risk_zones'] as List<dynamic>? ?? []);

      if (!mounted) return;
      setState(() {
        _invites = invitesJson
            .map((e) => FamilyInvite.fromJson(e as Map<String, dynamic>))
            .toList();
        _members = membersJson
            .map(
              (e) => FamilyMemberLocation.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        _riskZones = zonesJson
            .map((e) => RiskZone.fromJson(e as Map<String, dynamic>))
            .toList();
        _evacuationCentres =
            (mapJson['evacuation_centres'] as List<dynamic>? ?? [])
                .map(
                  (e) => EvacuationCentre.fromJson(e as Map<String, dynamic>),
                )
                .toList();
        _loading = false;
        _error = null;
      });
      // Reverse-geocode new locations (skip cached ones)
      _reverseGeocodeAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendInvite() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return;

    setState(() {
      _sendingInvite = true;
      _error = null;
    });

    try {
      await _api.inviteFamilyMember(
        accessToken: widget.accessToken,
        identifier: identifier,
      );
      _identifierController.clear();
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _sendingInvite = false);
      }
    }
  }

  Future<void> _respondInvite(String inviteId, bool accept) async {
    try {
      await _api.respondFamilyInvite(
        accessToken: widget.accessToken,
        inviteId: inviteId,
        accept: accept,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return _tr(en: 'Never', ms: 'Tidak Pernah', zh: '从未');
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) {
      return _tr(en: 'Just now', ms: 'Baru sahaja', zh: '刚刚');
    }
    if (diff.inMinutes < 60) {
      return _tr(
        en: '${diff.inMinutes}m ago',
        ms: '${diff.inMinutes}m lalu',
        zh: '${diff.inMinutes}分钟前',
      );
    }
    if (diff.inHours < 24) {
      return _tr(
        en: '${diff.inHours}h ago',
        ms: '${diff.inHours}j lalu',
        zh: '${diff.inHours}小时前',
      );
    }
    return _tr(
      en: '${diff.inDays}d ago',
      ms: '${diff.inDays}h lalu',
      zh: '${diff.inDays}天前',
    );
  }

  /// Returns the worst risk zone type a member is inside, or null if none.
  /// Returns 'evacuation_centre' if the member is within 500 m of a PPS.
  String? _zoneStatusFor(FamilyMemberLocation m) {
    if (!m.hasLocation) return null;
    for (final centre in _evacuationCentres) {
      final distKm = _haversineKm(
        m.latitude!,
        m.longitude!,
        centre.latitude,
        centre.longitude,
      );
      if (distKm <= 0.5) return 'evacuation_centre';
    }
    String? worst; // 'danger' beats 'warning' beats 'safe'
    for (final zone in _riskZones) {
      final distKm = _haversineKm(
        m.latitude!,
        m.longitude!,
        zone.latitude,
        zone.longitude,
      );
      if (distKm <= zone.radiusKm) {
        if (zone.zoneType == 'danger') return 'danger';
        if (zone.zoneType == 'warning' && worst != 'danger') worst = 'warning';
        if (zone.zoneType == 'safe' && worst == null) worst = 'safe';
      }
    }
    return worst;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Widget _safetyBadge(String? zoneType) {
    final (label, color, icon) = switch (zoneType) {
      'evacuation_centre' => (
        _tr(en: 'SAFE AT EVACUATION CENTRE', ms: 'SELAMAT DI PPS', zh: '在疏散中心'),
        const Color(0xFF2E7D32),
        Icons.house_siding,
      ),
      'danger' => (
        _tr(en: 'IN DANGER ZONE', ms: 'DALAM ZON BAHAYA', zh: '处于危险区域'),
        Colors.red,
        Icons.dangerous,
      ),
      'warning' => (
        _tr(en: 'IN WARNING ZONE', ms: 'DALAM ZON AMARAN', zh: '处于警戒区域'),
        Colors.orange,
        Icons.warning_amber,
      ),
      'safe' => (
        _tr(en: 'IN SAFE ZONE', ms: 'DALAM ZON SELAMAT', zh: '处于安全区域'),
        const Color(0xFF2E7D32),
        Icons.check_circle,
      ),
      _ => (
        _tr(en: 'SAFE', ms: 'SELAMAT', zh: '安全'),
        const Color(0xFF2E7D32),
        Icons.check_circle_outline,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reverseGeocodeAll() async {
    for (final m in _members) {
      if (!m.hasLocation || _placeNames.containsKey(m.userId)) continue;
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'lat': m.latitude!.toString(),
          'lon': m.longitude!.toString(),
          'format': 'json',
          'zoom': '14',
        });
        final res = await http.get(
          uri,
          headers: {'User-Agent': 'DisasterResilienceAI/1.0'},
        );
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final addr = json['address'] as Map<String, dynamic>?;
          final place =
              addr?['village'] ??
              addr?['suburb'] ??
              addr?['town'] ??
              addr?['city'] ??
              addr?['county'] ??
              addr?['state'] ??
              (json['display_name'] as String?)?.split(',').first;
          if (place != null && mounted) {
            setState(() => _placeNames[m.userId] = place as String);
          }
        }
      } catch (_) {
        // silently ignore geocoding errors
      }
    }
  }

  List<FamilyMemberLocation> get _membersWithLocation =>
      _members.where((m) => m.hasLocation).toList();

  String _tr({required String en, required String ms, required String zh}) {
    final language = AppLanguageScope.of(context).language;
    return switch (language) {
      AppLanguage.english => en,
      AppLanguage.indonesian => (() {
        final id = indonesianText(en);
        return id == en ? ms : id;
      })(),
      AppLanguage.malay => ms,
      AppLanguage.chinese => zh,
    };
  }

  LatLng get _mapCenter {
    final located = _membersWithLocation;
    if (located.isEmpty) return const LatLng(3.8077, 103.3260);
    final avgLat =
        located.map((m) => m.latitude!).reduce((a, b) => a + b) /
        located.length;
    final avgLng =
        located.map((m) => m.longitude!).reduce((a, b) => a + b) /
        located.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final appBarBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final bodyText = isDark ? const Color(0xFFA7B5A8) : const Color(0xFF475569);
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFFE2E8F0);
    final mutedText = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: Colors.transparent,
        title: Text(_tr(en: 'Family', ms: 'Keluarga', zh: '家人')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _tr(
                en: 'Family Live Location',
                ms: 'Lokasi Langsung Keluarga',
                zh: '家庭实时位置',
              ),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                en: 'Invite family by username or email, then view their latest location updates.',
                ms: 'Jemput keluarga melalui nama pengguna atau emel, kemudian lihat kemas kini lokasi terkini mereka.',
                zh: '通过用户名或邮箱邀请家人，然后查看他们的最新位置更新。',
              ),
              style: TextStyle(color: bodyText),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr(
                      en: 'Add Family Member',
                      ms: 'Tambah Ahli Keluarga',
                      zh: '添加家庭成员',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _identifierController,
                    decoration: InputDecoration(
                      hintText: _tr(
                        en: 'username or email',
                        ms: 'nama pengguna atau emel',
                        zh: '用户名或邮箱',
                      ),
                      hintStyle: TextStyle(color: mutedText),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2720)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: borderColor),
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendingInvite ? null : _sendInvite,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _sendingInvite
                            ? _tr(
                                en: 'Sending...',
                                ms: 'Menghantar...',
                                zh: '发送中...',
                              )
                            : _tr(
                                en: 'Send Invite',
                                ms: 'Hantar Jemputan',
                                zh: '发送邀请',
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 20),
            Text(
              _tr(en: 'Pending Invites', ms: 'Jemputan Tertunda', zh: '待处理邀请'),
              style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_invites.isEmpty)
              Text(
                _tr(
                  en: 'No pending invites.',
                  ms: 'Tiada jemputan tertunda.',
                  zh: '暂无待处理邀请。',
                ),
                style: TextStyle(color: mutedText),
              )
            else
              ..._invites.map(
                (invite) => Card(
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.requesterUsername,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          invite.requesterEmail,
                          style: TextStyle(color: mutedText),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _respondInvite(invite.id, false),
                                child: Text(
                                  _tr(en: 'Reject', ms: 'Tolak', zh: '拒绝'),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    _respondInvite(invite.id, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _tr(en: 'Accept', ms: 'Terima', zh: '接受'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              _tr(en: 'Family Members', ms: 'Ahli Keluarga', zh: '家庭成员'),
              style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
            ),
            const SizedBox(height: 10),
            if (!_loading && _membersWithLocation.isNotEmpty)
              Container(
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _membersWithLocation.length == 1
                        ? LatLng(
                            _membersWithLocation.first.latitude!,
                            _membersWithLocation.first.longitude!,
                          )
                        : _mapCenter,
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName:
                          'com.disasterai.disaster_resilience_ai',
                    ),
                    MarkerLayer(
                      markers: _membersWithLocation.map((m) {
                        final zone = _zoneStatusFor(m);
                        final pinColor = switch (zone) {
                          'danger' => Colors.red,
                          'warning' => Colors.orange,
                          _ => const Color(0xFF2E7D32),
                        };
                        return Marker(
                          point: LatLng(m.latitude!, m.longitude!),
                          width: 90,
                          height: 50,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: pinColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  m.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                Icons.location_on,
                                color: pinColor,
                                size: 28,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            if (!_loading && _membersWithLocation.isNotEmpty)
              const SizedBox(height: 12),
            if (_loading)
              const SizedBox.shrink()
            else if (_members.isEmpty)
              Text(
                _tr(
                  en: 'No family members connected yet.',
                  ms: 'Belum ada ahli keluarga yang disambungkan.',
                  zh: '尚未连接任何家庭成员。',
                ),
                style: TextStyle(color: mutedText),
              )
            else
              ..._members.map((member) {
                final zoneType = _zoneStatusFor(member);
                final markerColor = switch (zoneType) {
                  'danger' => Colors.red,
                  'warning' => Colors.orange,
                  _ => const Color(0xFF2E7D32),
                };
                return Card(
                  color: cardBg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: markerColor.withAlpha(30),
                          child: Text(
                            member.username.isNotEmpty
                                ? member.username[0].toUpperCase()
                                : '?',
                            style: TextStyle(color: markerColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _safetyBadge(zoneType),
                              const SizedBox(height: 4),
                              Text(
                                member.hasLocation
                                    ? '${_placeNames[member.userId] ?? '${member.latitude!.toStringAsFixed(4)}, ${member.longitude!.toStringAsFixed(4)}'}'
                                          '  ·  ${_tr(en: 'Updated', ms: 'Dikemas kini', zh: '更新')} ${_timeAgo(member.updatedAt)}'
                                    : _tr(
                                        en: 'Location not available yet',
                                        ms: 'Lokasi belum tersedia',
                                        zh: '位置尚不可用',
                                      ),
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
