import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _searchController = TextEditingController();
  bool _showNewReportForm = false;

  static const _items = <_ReportItem>[
    _ReportItem(
      title: 'Rising Water in Village A',
      time: '15 mins ago',
      distance: '200m away',
      icon: Icons.water_drop,
      iconBgLight: Color(0xFFDBEAFE),
      iconBgDark: Color(0xFF1E3A5F),
      iconColorLight: Color(0xFF2563EB),
      iconColorDark: Color(0xFF60A5FA),
      status: 'Verified',
      statusBgLight: Color(0xFFDCFCE7),
      statusBgDark: Color(0xFF224032),
      statusTextLight: Color(0xFF15803D),
      statusTextDark: Color(0xFF86EFAC),
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCHYbeNlIKs6fqVtsNvYIrkPsULnbohfaU50CBeHnzlfVOhQjYAJMQKaxMzq9RWIFUOyPznZ6iP_7COtMZpjJDzOF6l50SHshWTCEUYxaJ_99xcHV5QP8xBQn2QYsGvidkMH1MD9hxgiLiIXXtqNhjNJIymusSqMew4Pp-NAXnYeVropTu6V99H2cc8g-gnpCdTcqjlRtWZDqwUdB9SxV27G79aCXZMGwSnhP8_C-NqpdcpSS_28oQz21TkAC8nF0G6rSOA2-wSSQE',
    ),
    _ReportItem(
      title: 'Soil Cracks on Slope B',
      time: '45 mins ago',
      distance: '1.2km away',
      icon: Icons.texture,
      iconBgLight: Color(0xFFFFEDD5),
      iconBgDark: Color(0xFF4A2F16),
      iconColorLight: Color(0xFFEA580C),
      iconColorDark: Color(0xFFFDBA74),
      status: 'Pending',
      statusBgLight: Color(0xFFFEF3C7),
      statusBgDark: Color(0xFF453714),
      statusTextLight: Color(0xFFB45309),
      statusTextDark: Color(0xFFFCD34D),
    ),
    _ReportItem(
      title: 'Downed Power Lines',
      time: '2 hours ago',
      distance: '500m away',
      icon: Icons.electrical_services,
      iconBgLight: Color(0xFFFEE2E2),
      iconBgDark: Color(0xFF4A1F1F),
      iconColorLight: Color(0xFFDC2626),
      iconColorDark: Color(0xFFFCA5A5),
      status: 'Verified',
      statusBgLight: Color(0xFFDCFCE7),
      statusBgDark: Color(0xFF224032),
      statusTextLight: Color(0xFF15803D),
      statusTextDark: Color(0xFF86EFAC),
    ),
    _ReportItem(
      title: 'Minor Landslide near Trail',
      time: '3 hours ago',
      distance: '2.5km away',
      icon: Icons.forest,
      iconBgLight: Color(0x1A2D5927),
      iconBgDark: Color(0xFF223724),
      iconColorLight: Color(0xFF2D5927),
      iconColorDark: Color(0xFF86C77C),
      status: 'Verified',
      statusBgLight: Color(0xFFDCFCE7),
      statusBgDark: Color(0xFF224032),
      statusTextLight: Color(0xFF15803D),
      statusTextDark: Color(0xFF86EFAC),
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2D5927);
    final language = AppLanguageScope.of(context).language;
    String tr({required String en, required String ms, required String zh}) {
      return switch (language) {
        AppLanguage.english => en,
        AppLanguage.malay => ms,
        AppLanguage.chinese => zh,
      };
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final border = isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    final chipBg = isDark
        ? const Color(0xFF2D5927).withAlpha(64)
        : const Color(0xFF2D5927).withAlpha(18);
    final chipText = isDark ? const Color(0xFF9EDB94) : primary;

    final reportsList = SingleChildScrollView(
      key: const ValueKey('reports_list'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tr(
                    en: 'Community Reports',
                    ms: 'Laporan Komuniti',
                    zh: '社区报告',
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => setState(() => _showNewReportForm = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    tr(en: 'New Report', ms: 'Laporan Baharu', zh: '新报告'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: tr(en: 'Search', ms: 'Cari', zh: '搜索'),
                hintStyle: TextStyle(color: subtitleColor),
                prefixIcon: Icon(Icons.search_rounded, color: subtitleColor),
                filled: true,
                fillColor: chipBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primary, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildFilterChip(
                    icon: Icons.near_me_rounded,
                    label: tr(en: 'Distance', ms: 'Jarak', zh: '距离'),
                    color: chipText,
                    bg: chipBg,
                    showExpand: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    icon: Icons.category,
                    label: tr(en: 'Type', ms: 'Jenis', zh: '类型'),
                    color: chipText,
                    bg: chipBg,
                    showExpand: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    icon: Icons.history,
                    label: tr(en: 'Recent', ms: 'Terkini', zh: '最新'),
                    color: chipText,
                    bg: chipBg,
                    showExpand: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              tr(en: 'NEARBY ACTIVITY', ms: 'AKTIVITI BERHAMPIRAN', zh: '附近动态'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 12),
            ..._items.map(
              (item) => _buildReportCard(
                item: item,
                cardBg: cardBg,
                border: border,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      color: bg,
      child: SafeArea(
        top: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final isForm = child.key == const ValueKey('new_report_form');
            final begin = isForm ? const Offset(1, 0) : const Offset(-0.12, 0);
            return ClipRect(
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: begin,
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _showNewReportForm
              ? _InlineNewReportForm(
                  key: const ValueKey('new_report_form'),
                  onBack: () => setState(() => _showNewReportForm = false),
                )
              : reportsList,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required bool showExpand,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (showExpand) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 14, color: color),
          ],
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required _ReportItem item,
    required Color cardBg,
    required Color border,
    required Color titleColor,
    required Color subtitleColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? item.iconBgDark : item.iconBgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: isDark ? item.iconColorDark : item.iconColorLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.time} • ${item.distance}',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? item.statusBgDark : item.statusBgLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (isDark ? item.statusTextDark : item.statusTextLight)
                        .withAlpha(90),
                  ),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? item.statusTextDark : item.statusTextLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (item.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl!,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineNewReportForm extends StatefulWidget {
  const _InlineNewReportForm({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<_InlineNewReportForm> createState() => _InlineNewReportFormState();
}

class _InlineNewReportFormState extends State<_InlineNewReportForm> {
  int _selectedIncident = 0;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ApiService _api = ApiService();
  final WeatherService _weatherService = WeatherService();
  final List<Map<String, String>> _media = [];
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_access_token');
  }

  Future<Map<String, dynamic>> _resolveLocation() async {
    const fallbackLat = 3.8077;
    const fallbackLon = 103.3260;
    const fallbackName = 'Kuantan, Pahang';

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return {
          'latitude': fallbackLat,
          'longitude': fallbackLon,
          'location_name': fallbackName,
        };
      }
      final pos = await Geolocator.getCurrentPosition();
      final place = await _weatherService.fetchLocationName(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      return {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'location_name': (place != null && place.isNotEmpty)
            ? place
            : fallbackName,
      };
    } catch (_) {
      return {
        'latitude': fallbackLat,
        'longitude': fallbackLon,
        'location_name': fallbackName,
      };
    }
  }

  String _incidentToReportType(int selected) {
    switch (selected) {
      case 0:
        return 'flood';
      case 1:
      case 2:
        return 'landslide';
      case 3:
      default:
        return 'blocked_road';
    }
  }

  Future<void> _pickAndUploadMedia({required bool video}) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      }
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
      final ext = filename.toLowerCase();
      final contentType = video
          ? (ext.endsWith('.webm')
                ? 'video/webm'
                : ext.endsWith('.mov')
                ? 'video/quicktime'
                : 'video/mp4')
          : (ext.endsWith('.png')
                ? 'image/png'
                : ext.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg');

      try {
        final res = await _api.uploadReportMedia(
          accessToken: token,
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      }
    }
  }

  Future<void> _submitReport() async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      }
      return;
    }

    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    final description = [title, desc].where((s) => s.isNotEmpty).join('\n\n');
    if (description.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add report details first.')),
        );
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final loc = await _resolveLocation();
      await _api.submitCommunityReport(
        accessToken: token,
        reportType: _incidentToReportType(_selectedIncident),
        description: description,
        locationName: loc['location_name'] as String,
        latitude: (loc['latitude'] as num).toDouble(),
        longitude: (loc['longitude'] as num).toDouble(),
        mediaUrls: _media.map((m) => m['url']!).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully.')),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF2D5927);
    final language = AppLanguageScope.of(context).language;
    String tr({required String en, required String ms, required String zh}) {
      return switch (language) {
        AppLanguage.english => en,
        AppLanguage.malay => ms,
        AppLanguage.chinese => zh,
      };
    }

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

    return Container(
      key: const ValueKey('new_report_form'),
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF334155),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Text(
                  tr(
                    en: 'New Community Report',
                    ms: 'Laporan Komuniti Baharu',
                    zh: '新社区报告',
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                en: 'Share what you\'re observing to help LANDA predict local risks.',
                ms: 'Kongsi apa yang anda perhatikan untuk membantu LANDA meramal risiko setempat.',
                zh: '分享您观察到的情况，帮助 LANDA 预测当地风险。',
              ),
              style: TextStyle(color: sectionLabel, height: 1.35),
            ),
            const SizedBox(height: 22),
            Text(
              tr(
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
            LayoutBuilder(
              builder: (context, constraints) {
                final textScale = MediaQuery.of(
                  context,
                ).textScaler.scale(1).clamp(1.0, 1.3);
                final cellWidth = (constraints.maxWidth - 10) / 2;
                final cardHeight = (cellWidth * 0.68 + (textScale - 1.0) * 14)
                    .clamp(88.0, 118.0);

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: cellWidth / cardHeight,
                  children: [
                    _buildIncidentCard(
                      index: 0,
                      selectedIndex: _selectedIncident,
                      icon: Icons.water_drop,
                      label: tr(
                        en: 'Rising Water',
                        ms: 'Air Meningkat',
                        zh: '水位上涨',
                      ),
                      onTap: () => setState(() => _selectedIncident = 0),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                    _buildIncidentCard(
                      index: 1,
                      selectedIndex: _selectedIncident,
                      icon: Icons.texture,
                      label: tr(
                        en: 'Cracks in Soil',
                        ms: 'Retakan Tanah',
                        zh: '土壤裂缝',
                      ),
                      onTap: () => setState(() => _selectedIncident = 1),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                    _buildIncidentCard(
                      index: 2,
                      selectedIndex: _selectedIncident,
                      icon: Icons.landslide,
                      label: tr(
                        en: 'Land Movement',
                        ms: 'Pergerakan Tanah',
                        zh: '地面位移',
                      ),
                      onTap: () => setState(() => _selectedIncident = 2),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                    _buildIncidentCard(
                      index: 3,
                      selectedIndex: _selectedIncident,
                      icon: Icons.more_horiz,
                      label: tr(
                        en: 'Other Concern',
                        ms: 'Lain-lain Kebimbangan',
                        zh: '其他问题',
                      ),
                      onTap: () => setState(() => _selectedIncident = 3),
                      border: border,
                      cardBg: cardBg,
                      isDark: isDark,
                      selectedColor: accent,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Text(
              tr(en: 'EVIDENCE', ms: 'BUKTI', zh: '证据'),
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
                    icon: Icons.add_a_photo,
                    label: tr(en: 'Add Photos', ms: 'Tambah Foto', zh: '添加照片'),
                    border: border,
                    isDark: isDark,
                    onTap: () => _pickAndUploadMedia(video: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildEvidenceButton(
                    icon: Icons.videocam,
                    label: tr(en: 'Add Video', ms: 'Tambah Video', zh: '添加视频'),
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
            const SizedBox(height: 22),
            Text(
              tr(en: 'REPORT DETAILS', ms: 'BUTIRAN LAPORAN', zh: '报告详情'),
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
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF111827),
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                hintText: tr(
                  en: 'Title (optional)',
                  ms: 'Tajuk (pilihan)',
                  zh: '标题（可选）',
                ),
                hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA79B)
                      : const Color(0xFF64748B),
                ),
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              maxLength: 500,
              style: TextStyle(
                color: isDark
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFF111827),
              ),
              cursorColor: accent,
              decoration: InputDecoration(
                hintText: tr(
                  en: 'Describe what happened, where, and how severe it is.',
                  ms: 'Terangkan apa yang berlaku, di mana, dan tahap keterukannya.',
                  zh: '请描述发生了什么、地点以及严重程度。',
                ),
                hintStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA79B)
                      : const Color(0xFF64748B),
                ),
                counterStyle: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA79B)
                      : const Color(0xFF64748B),
                ),
                filled: true,
                fillColor: cardBg,
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: accent, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        tr(
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
    required int selectedIndex,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color border,
    required Color cardBg,
    required bool isDark,
    required Color selectedColor,
  }) {
    final selected = index == selectedIndex;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
                          ? const Color(0xFFA7B5A8)
                          : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? selectedColor
                      : (isDark
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFF334155)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: isDark ? const Color(0xFF4F6252) : const Color(0xFF64748B),
            radius: 12,
            strokeWidth: 1.5,
            dashWidth: 5,
            dashGap: 4,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isDark
                      ? const Color(0xFFA7B5A8)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        radius != oldDelegate.radius ||
        strokeWidth != oldDelegate.strokeWidth ||
        dashWidth != oldDelegate.dashWidth ||
        dashGap != oldDelegate.dashGap;
  }
}

class _ReportItem {
  const _ReportItem({
    required this.title,
    required this.time,
    required this.distance,
    required this.icon,
    required this.iconBgLight,
    required this.iconBgDark,
    required this.iconColorLight,
    required this.iconColorDark,
    required this.status,
    required this.statusBgLight,
    required this.statusBgDark,
    required this.statusTextLight,
    required this.statusTextDark,
    this.imageUrl,
  });

  final String title;
  final String time;
  final String distance;
  final IconData icon;
  final Color iconBgLight;
  final Color iconBgDark;
  final Color iconColorLight;
  final Color iconColorDark;
  final String status;
  final Color statusBgLight;
  final Color statusBgDark;
  final Color statusTextLight;
  final Color statusTextDark;
  final String? imageUrl;
}
