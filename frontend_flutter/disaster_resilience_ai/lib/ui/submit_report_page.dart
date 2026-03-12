import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';

class SubmitReportPage extends StatefulWidget {
  const SubmitReportPage({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<SubmitReportPage> createState() => _SubmitReportPageState();
}

class _SubmitReportPageState extends State<SubmitReportPage> {
  final ApiService _api = ApiService();
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  int _selectedIncident = 0;
  bool _vulnerableHelp = false;
  bool _submitting = false;
  final List<Map<String, String>> _media = [];
  double _selectedLat = 3.8077;
  double _selectedLon = 103.3260;
  String _selectedLocationName = 'Fetching location...';
  bool _isCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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

  Future<void> _initCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        _selectedLat = pos.latitude;
        _selectedLon = pos.longitude;
      }

      final place = await _weatherService.fetchLocationName(
        latitude: _selectedLat,
        longitude: _selectedLon,
      );
      if (!mounted) return;
      setState(() {
        _selectedLocationName = (place != null && place.isNotEmpty)
            ? place
            : 'Near ${_selectedLat.toStringAsFixed(4)}, ${_selectedLon.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedLocationName =
            'Near ${_selectedLat.toStringAsFixed(4)}, ${_selectedLon.toStringAsFixed(4)}';
      });
    }
  }

  String _incidentToReportType(int selected) {
    switch (selected) {
      case 0:
        return 'flood';
      case 1:
        return 'landslide';
      case 2:
        return 'landslide';
      case 3:
      default:
        return 'blocked_road';
    }
  }

  Future<void> _pickAndUploadMedia({required bool video}) async {
    if (widget.accessToken.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: video ? FileType.video : FileType.image,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;

      final filename = file.name;
      final lower = filename.toLowerCase();
      final contentType = video
          ? (lower.endsWith('.webm')
                ? 'video/webm'
                : lower.endsWith('.mov')
                ? 'video/quicktime'
                : 'video/mp4')
          : (lower.endsWith('.png')
                ? 'image/png'
                : lower.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg');

      try {
        final res = await _api.uploadReportMedia(
          accessToken: widget.accessToken,
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
        final url = res['url']?.toString();
        final mediaType =
            res['media_type']?.toString() ?? (video ? 'video' : 'image');

        if (url != null && url.isNotEmpty && mounted) {
          setState(() => _media.add({'url': url, 'type': mediaType}));
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _submitReport() async {
    if (widget.accessToken.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    final description = [title, desc].where((s) => s.isNotEmpty).join('\n\n');

    if (description.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add report details first.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.submitCommunityReport(
        accessToken: widget.accessToken,
        reportType: _incidentToReportType(_selectedIncident),
        description: description,
        locationName: _selectedLocationName,
        latitude: _selectedLat,
        longitude: _selectedLon,
        vulnerablePerson: _vulnerableHelp,
        mediaUrls: _media.map((m) => m['url']!).toList(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _setPinnedLocation(
    double lat,
    double lon, {
    String? knownName,
  }) async {
    setState(() {
      _selectedLat = lat;
      _selectedLon = lon;
      _isCurrentLocation = false;
      _selectedLocationName =
          knownName ??
          'Near ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
    });
    if (knownName != null && knownName.isNotEmpty) return;
    final place = await _weatherService.fetchLocationName(
      latitude: lat,
      longitude: lon,
    );
    if (!mounted) return;
    if (place != null && place.isNotEmpty) {
      setState(() => _selectedLocationName = place);
    }
  }

  void _showLocationSheet() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;
    double draftLat = _selectedLat;
    double draftLon = _selectedLon;
    String draftName = _selectedLocationName;
    bool resolvingPin = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1B251B)
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            Future<void> doSearch(String q) async {
              if (q.trim().isEmpty) {
                setSheetState(() {
                  results = [];
                  searching = false;
                });
                return;
              }
              setSheetState(() => searching = true);
              final found = await _weatherService.searchLocation(q);
              setSheetState(() {
                results = found;
                searching = false;
              });
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final titleColor = isDark
                ? const Color(0xFFE5E7EB)
                : const Color(0xFF1E293B);
            final subColor = isDark
                ? const Color(0xFF94A3B8)
                : const Color(0xFF64748B);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF334236)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 170,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334236)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(draftLat, draftLon),
                        initialZoom: 13,
                        onTap: (_, point) async {
                          setSheetState(() {
                            draftLat = point.latitude;
                            draftLon = point.longitude;
                            draftName =
                                'Near ${draftLat.toStringAsFixed(4)}, ${draftLon.toStringAsFixed(4)}';
                            resolvingPin = true;
                          });
                          final place = await _weatherService.fetchLocationName(
                            latitude: draftLat,
                            longitude: draftLon,
                          );
                          if (ctx.mounted) {
                            setSheetState(() {
                              if (place != null && place.isNotEmpty) {
                                draftName = place;
                              }
                              resolvingPin = false;
                            });
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.disaster.resilience.ai',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              width: 38,
                              height: 38,
                              point: LatLng(draftLat, draftLon),
                              child: const Icon(
                                Icons.location_pin,
                                color: Color(0xFFDC2626),
                                size: 34,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF2E7D32),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          draftName,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (resolvingPin)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _tr(
                      en: 'Tap map to pin exact location.',
                      ms: 'Ketik peta untuk semat lokasi tepat.',
                      zh: '点击地图以标记准确位置。',
                    ),
                    style: TextStyle(color: subColor, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetCtx);
                        await _setPinnedLocation(
                          draftLat,
                          draftLon,
                          knownName: draftName,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.push_pin_outlined, size: 18),
                      label: Text(
                        _tr(
                          en: 'Use Pinned Location',
                          ms: 'Guna Lokasi Disemat',
                          zh: '使用已标记位置',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(en: 'Choose Location', ms: 'Pilih Lokasi', zh: '选择位置'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      hintText: _tr(
                        en: 'Search city or state in Malaysia...',
                        ms: 'Cari bandar atau negeri di Malaysia...',
                        zh: '搜索马来西亚的城市或州...',
                      ),
                      hintStyle: TextStyle(color: subColor),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF2E7D32),
                      ),
                      suffixIcon: searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (searchController.text == v) doSearch(v);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.my_location,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    ),
                    title: Text(
                      _tr(
                        en: 'Use my current location',
                        ms: 'Gunakan lokasi semasa saya',
                        zh: '使用我的当前位置',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: titleColor,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      await _initCurrentLocation();
                      if (mounted) {
                        setState(() => _isCurrentLocation = true);
                      }
                    },
                  ),
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final r = results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 2,
                            ),
                            leading: Icon(
                              Icons.location_on_outlined,
                              color: subColor,
                              size: 18,
                            ),
                            title: Text(
                              r['name'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: titleColor,
                              ),
                            ),
                            onTap: () async {
                              Navigator.pop(sheetCtx);
                              await _setPinnedLocation(
                                r['lat'] as double,
                                r['lon'] as double,
                                knownName: r['name'] as String,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2D5927);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF86C77C) : primary;
    final bg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final sectionLabel = isDark
        ? const Color(0xFF97A09B)
        : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF2A332A) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF1D251D) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _tr(en: 'Submit Report', ms: 'Hantar Laporan', zh: '提交报告'),
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF2D5927).withAlpha(26),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr(
                en: 'WHAT ARE YOU OBSERVING?',
                ms: 'APA YANG ANDA PERHATIKAN?',
                zh: '您观察到了什么？',
              ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: sectionLabel,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: [
                _buildIncidentCard(
                  index: 0,
                  icon: Icons.water_drop,
                  label: _tr(
                    en: 'Rising Water',
                    ms: 'Air Meningkat',
                    zh: '水位上涨',
                  ),
                  border: border,
                  cardBg: cardBg,
                  isDark: isDark,
                  selectedColor: accent,
                ),
                _buildIncidentCard(
                  index: 1,
                  icon: Icons.texture,
                  label: _tr(
                    en: 'Cracks in Soil',
                    ms: 'Retakan Tanah',
                    zh: '土壤裂缝',
                  ),
                  border: border,
                  cardBg: cardBg,
                  isDark: isDark,
                  selectedColor: accent,
                ),
                _buildIncidentCard(
                  index: 2,
                  icon: Icons.landslide,
                  label: _tr(
                    en: 'Land Movement',
                    ms: 'Pergerakan Tanah',
                    zh: '地面位移',
                  ),
                  border: border,
                  cardBg: cardBg,
                  isDark: isDark,
                  selectedColor: accent,
                ),
                _buildIncidentCard(
                  index: 3,
                  icon: Icons.more_horiz,
                  label: _tr(
                    en: 'Other Concern',
                    ms: 'Lain-lain Kebimbangan',
                    zh: '其他问题',
                  ),
                  border: border,
                  cardBg: cardBg,
                  isDark: isDark,
                  selectedColor: accent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3A2020)
                    : const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF7F1D1D)
                      : const Color(0xFFFFCDD2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFFB91C1C) : Colors.red[600],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.share_location,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tr(
                            en: 'Vulnerable Person Help',
                            ms: 'Bantu Golongan Rentan',
                            zh: '弱势人群援助',
                          ),
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tr(
                            en: 'Priority rescue alert',
                            ms: 'Amaran penyelamatan keutamaan',
                            zh: '优先救援提醒',
                          ),
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFFECACA)
                                : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _vulnerableHelp,
                    onChanged: (val) => setState(() => _vulnerableHelp = val),
                    thumbColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected)
                            ? (isDark ? const Color(0xFFFEE2E2) : Colors.white)
                            : (isDark ? const Color(0xFF94A3B8) : Colors.white)),
                    trackColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.selected)
                            ? (isDark ? const Color(0xFFB91C1C) : Colors.red.shade400)
                            : (isDark ? const Color(0xFF475569) : Colors.grey.shade300)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tr(en: 'CHOOSE LOCATION', ms: 'PILIH LOKASI', zh: '选择位置'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: sectionLabel,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showLocationSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedLocationName,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isCurrentLocation) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withAlpha(28),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _tr(en: 'Pinned', ms: 'Disemat', zh: '已标记'),
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _tr(en: 'Change', ms: 'Tukar', zh: '更改'),
                      style: TextStyle(color: sectionLabel, fontSize: 12),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: sectionLabel),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tr(en: 'ADD EVIDENCE', ms: 'TAMBAH BUKTI', zh: '添加证据'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: sectionLabel,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildEvidenceButton(
                    icon: Icons.photo_library,
                    label: _tr(en: 'Add Photo', ms: 'Tambah Foto', zh: '添加照片'),
                    border: border,
                    isDark: isDark,
                    onTap: () => _pickAndUploadMedia(video: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildEvidenceButton(
                    icon: Icons.videocam,
                    label: _tr(en: 'Add Video', ms: 'Tambah Video', zh: '添加视频'),
                    border: border,
                    isDark: isDark,
                    onTap: () => _pickAndUploadMedia(video: true),
                  ),
                ),
              ],
            ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _media
                    .asMap()
                    .entries
                    .map(
                      (entry) => Chip(
                        label: Text('${entry.value['type']} ${entry.key + 1}'),
                        onDeleted: () =>
                            setState(() => _media.removeAt(entry.key)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _tr(en: 'REPORT DETAILS', ms: 'BUTIRAN LAPORAN', zh: '报告详情'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: sectionLabel,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              maxLength: 60,
              style: TextStyle(color: titleColor),
              decoration: InputDecoration(
                hintText: _tr(
                  en: 'Title (optional)',
                  ms: 'Tajuk (pilihan)',
                  zh: '标题（可选）',
                ),
                hintStyle: TextStyle(color: sectionLabel),
                filled: true,
                fillColor: cardBg,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              maxLength: 500,
              style: TextStyle(color: titleColor),
              decoration: InputDecoration(
                hintText: _tr(
                  en: 'Describe what happened, where, and how severe it is.',
                  ms: 'Terangkan apa yang berlaku, di mana, dan tahap keterukannya.',
                  zh: '请描述发生了什么、地点以及严重程度。',
                ),
                hintStyle: TextStyle(color: sectionLabel),
                counterStyle: TextStyle(color: sectionLabel),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF86C77C) : accent,
                  foregroundColor: isDark
                      ? const Color(0xFF0F172A)
                      : Colors.white,
                  disabledBackgroundColor: isDark
                      ? const Color(0xFF4F6252)
                      : const Color(0xFF9CA3AF),
                  disabledForegroundColor: isDark
                      ? const Color(0xFFD1D5DB)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                        ),
                      )
                    : Text(
                        _tr(
                          en: 'Submit Report',
                          ms: 'Hantar Laporan',
                          zh: '提交报告',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard({
    required int index,
    required IconData icon,
    required String label,
    required Color border,
    required Color cardBg,
    required bool isDark,
    required Color selectedColor,
  }) {
    final selected = index == _selectedIncident;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedIncident = index),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                      ? selectedColor.withAlpha(40)
                      : selectedColor.withAlpha(18))
                : cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? selectedColor : border,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: selected
                    ? selectedColor
                    : (isDark
                          ? const Color(0xFFB8C2BA)
                          : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? selectedColor
                      : (isDark
                            ? const Color(0xFFE5E7EB)
                            : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceButton({
    required IconData icon,
    required String label,
    required Color border,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: border),
        backgroundColor: isDark ? const Color(0xFF1D251D) : Colors.white,
        foregroundColor: isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
