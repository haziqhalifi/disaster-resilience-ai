import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Returns the worst risk zone type a member is inside, or null if none.
  String? _zoneStatusFor(FamilyMemberLocation m) {
    if (!m.hasLocation) return null;
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
      'danger' => ('IN DANGER ZONE', Colors.red, Icons.dangerous),
      'warning' => ('IN WARNING ZONE', Colors.orange, Icons.warning_amber),
      'safe' => ('IN SAFE ZONE', const Color(0xFF2E7D32), Icons.check_circle),
      _ => ('SAFE', const Color(0xFF2E7D32), Icons.check_circle_outline),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Family Live Location',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Invite family by username or email, then view their latest location updates.',
              style: TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Family Member',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _identifierController,
                    decoration: const InputDecoration(
                      hintText: 'username or email',
                      border: OutlineInputBorder(),
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
                        _sendingInvite ? 'Sending...' : 'Send Invite',
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
            const Text(
              'Pending Invites',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_invites.isEmpty)
              const Text('No pending invites.')
            else
              ..._invites.map(
                (invite) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.requesterUsername,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(invite.requesterEmail),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    _respondInvite(invite.id, false),
                                child: const Text('Reject'),
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
                                child: const Text('Accept'),
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
            const Text(
              'Family Members',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            if (!_loading && _membersWithLocation.isNotEmpty)
              Container(
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
              const Text('No family members connected yet.')
            else
              ..._members.map((member) {
                final zoneType = _zoneStatusFor(member);
                final markerColor = switch (zoneType) {
                  'danger' => Colors.red,
                  'warning' => Colors.orange,
                  _ => const Color(0xFF2E7D32),
                };
                return Card(
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
                                          '  ·  Updated ${_timeAgo(member.updatedAt)}'
                                    : 'Location not available yet',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
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
