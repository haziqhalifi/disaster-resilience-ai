import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/services/api_service.dart';

class MySubmissionsPage extends StatefulWidget {
  const MySubmissionsPage({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<MySubmissionsPage> createState() => _MySubmissionsPageState();
}

class _MySubmissionsPageState extends State<MySubmissionsPage> {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _myReports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMyReports();
  }

  Future<void> _loadMyReports() async {
    if (widget.accessToken.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final payload = await _api.fetchMyReports(
        accessToken: widget.accessToken,
      );
      final rows = (payload['reports'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted) {
        setState(() {
          _myReports = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _tr({
    required String en,
    required String ms,
    required String zh,
    String? id,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ms':
        return ms;
      case 'zh':
        return zh;
      case 'id':
        return id ?? ms;
      default:
        return en;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) {
      return _tr(en: 'Just now', ms: 'Baru sahaja', zh: '刚刚', id: 'Baru saja');
    }
    if (diff.inMinutes < 60) {
      return _tr(
        en: '${diff.inMinutes}m ago',
        ms: '${diff.inMinutes}m lalu',
        zh: '${diff.inMinutes}分钟前',
        id: '${diff.inMinutes}m lalu',
      );
    }
    if (diff.inHours < 24) {
      return _tr(
        en: '${diff.inHours}h ago',
        ms: '${diff.inHours}j lalu',
        zh: '${diff.inHours}小时前',
        id: '${diff.inHours}j lalu',
      );
    }
    return _tr(
      en: '${diff.inDays}d ago',
      ms: '${diff.inDays}h lalu',
      zh: '${diff.inDays}天前',
      id: '${diff.inDays}h lalu',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final barBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final border = isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final secondaryText = isDark
        ? const Color(0xFFB8C2BA)
        : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        title: Text(
          _tr(
            en: 'My Submissions',
            ms: 'Penghantaran Saya',
            zh: '我的提交',
            id: 'Kiriman Saya',
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyReports,
        color: const Color(0xFF2E7D32),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
              )
            : _myReports.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B251B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: isDark
                              ? const Color(0xFF9EDB94)
                              : const Color(0xFF4CAF50),
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tr(
                                  en: 'No submissions yet',
                                  ms: 'Tiada penghantaran lagi',
                                  zh: '暂无提交',
                                  id: 'Belum ada kiriman',
                                ),
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _tr(
                                  en: 'Use the map to report an incident',
                                  ms: 'Gunakan peta untuk laporkan insiden',
                                  zh: '使用地图上报事件',
                                  id: 'Gunakan peta untuk melaporkan insiden',
                                ),
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: _myReports.length,
                itemBuilder: (context, i) {
                  final r = _myReports[i];
                  final status = (r['status'] as String? ?? 'pending')
                      .toLowerCase();
                  final type = (r['report_type'] as String? ?? 'report')
                      .toLowerCase();
                  final title = (r['location_name'] as String?)?.trim();
                  final description =
                      (r['description'] as String?)?.trim() ?? '';
                  final createdAt = r['created_at'] as String?;
                  final dt = createdAt != null
                      ? DateTime.tryParse(createdAt)
                      : null;

                  final (
                    Color statusFg,
                    Color statusBg,
                    IconData statusIcon,
                  ) = switch (status) {
                    'validated' || 'verified' || 'resolved' => (
                      isDark ? const Color(0xFF86EFAC) : Colors.green.shade700,
                      isDark ? const Color(0xFF14532D) : Colors.green.shade50,
                      Icons.check_circle_outline,
                    ),
                    'rejected' => (
                      isDark ? const Color(0xFFFCA5A5) : Colors.red.shade700,
                      isDark ? const Color(0xFF3E1D1D) : Colors.red.shade50,
                      Icons.cancel_outlined,
                    ),
                    _ => (
                      isDark ? const Color(0xFFFCD34D) : Colors.amber.shade700,
                      isDark ? const Color(0xFF373018) : Colors.amber.shade50,
                      Icons.hourglass_empty_rounded,
                    ),
                  };

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B251B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(statusIcon, color: statusFg, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title?.isNotEmpty == true
                                    ? title!
                                    : type.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                  color: titleColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      status[0].toUpperCase() +
                                          status.substring(1),
                                      style: TextStyle(
                                        color: statusFg,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (dt != null)
                                    Text(
                                      _timeAgo(dt),
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
