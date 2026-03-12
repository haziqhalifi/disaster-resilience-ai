import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/models/disaster_news_model.dart';
import 'package:disaster_resilience_ai/models/report_model.dart';
import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/all_news_page.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';

class LocationNewsPage extends StatefulWidget {
  const LocationNewsPage({
    super.key,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.accessToken,
  });

  final String locationName;
  final double latitude;
  final double longitude;
  final String accessToken;

  @override
  State<LocationNewsPage> createState() => _LocationNewsPageState();
}

class _LocationNewsPageState extends State<LocationNewsPage> {
  final ApiService _api = ApiService();

  List<Warning> _warnings = [];
  List<Report> _reports = [];
  late List<DisasterNews> _news;

  bool _loadingWarnings = true;
  bool _loadingReports = true;
  String? _warningsError;
  String? _reportsError;

  @override
  void initState() {
    super.initState();
    _news = _filterNews(widget.locationName);
    _loadWarnings();
    _loadReports();
  }

  List<DisasterNews> _filterNews(String locationName) {
    final lower = locationName.toLowerCase();
    // Extract the first part (city or state name) for keyword matching
    final keyword = lower.split(',').first.trim();
    final matches = DisasterNewsData.articles
        .where((a) =>
            a.title.toLowerCase().contains(keyword) ||
            a.body.toLowerCase().contains(keyword))
        .toList();
    // Always ensure at least 3 articles — fall back to emergency kit, flood warning, climate
    if (matches.length < 3) {
      final fallbackIds = ['1', '3', '8'];
      final fallbacks = DisasterNewsData.articles
          .where((a) => fallbackIds.contains(a.id) && !matches.contains(a))
          .toList();
      return [...matches, ...fallbacks];
    }
    return matches;
  }

  Future<void> _loadWarnings() async {
    setState(() { _loadingWarnings = true; _warningsError = null; });
    try {
      final data = await _api.fetchNearbyWarnings(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      final list = (data['warnings'] as List<dynamic>? ?? [])
          .map((e) => Warning.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _warnings = list; _loadingWarnings = false; });
    } catch (e) {
      if (mounted) setState(() {
        _warningsError = e.toString().replaceFirst('Exception: ', '');
        _loadingWarnings = false;
      });
    }
  }

  Future<void> _loadReports() async {
    setState(() { _loadingReports = true; _reportsError = null; });
    try {
      final data = await _api.fetchNearbyReports(
        accessToken: widget.accessToken,
        latitude: widget.latitude,
        longitude: widget.longitude,
        radiusKm: 50,
      );
      final list = ReportList.fromJson(data);
      if (mounted) setState(() { _reports = list.reports.where((r) => r.status != 'rejected').toList(); _loadingReports = false; });
    } catch (e) {
      if (mounted) setState(() {
        _reportsError = e.toString().replaceFirst('Exception: ', '');
        _loadingReports = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Short display name (first segment before comma)
    final shortName = widget.locationName.split(',').first.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2E7D32)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shortName,
                style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 17)),
            const Text('Disaster Overview',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async { await Future.wait([_loadWarnings(), _loadReports()]); },
        color: const Color(0xFF2E7D32),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader(
              Icons.warning_amber_rounded,
              'Active Warnings',
              _warnings.length,
              Colors.orange[700]!,
            ),
            const SizedBox(height: 10),
            _buildWarningsSection(),
            const SizedBox(height: 24),

            _buildSectionHeader(
              Icons.feed_rounded,
              'Community Reports',
              _reports.length,
              const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 10),
            _buildReportsSection(),
            const SizedBox(height: 24),

            _buildSectionHeader(
              Icons.newspaper_rounded,
              'Related News & Guides',
              _news.length,
              Colors.blue[700]!,
            ),
            const SizedBox(height: 10),
            _buildNewsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ─── Warnings ────────────────────────────────────────────────────────────────

  Widget _buildWarningsSection() {
    if (_loadingWarnings) return _loadingCard();
    if (_warningsError != null) return _errorCard(_warningsError!, _loadWarnings);
    if (_warnings.isEmpty) {
      return _emptyCard(Icons.check_circle_outline, 'No active warnings', 'This area is currently safe.');
    }
    return Column(
      children: _warnings.map(_buildWarningTile).toList(),
    );
  }

  Widget _buildWarningTile(Warning w) {
    final Color tileColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    switch (w.alertLevel) {
      case AlertLevel.evacuate:
        tileColor = Colors.red[50]!; borderColor = Colors.red[300]!;
        iconColor = Colors.red[700]!; icon = Icons.directions_run;
        break;
      case AlertLevel.warning:
        tileColor = Colors.orange[50]!; borderColor = Colors.orange[300]!;
        iconColor = Colors.orange[700]!; icon = Icons.warning_amber_rounded;
        break;
      case AlertLevel.observe:
        tileColor = Colors.amber[50]!; borderColor = Colors.amber[300]!;
        iconColor = Colors.amber[700]!; icon = Icons.visibility_outlined;
        break;
      case AlertLevel.advisory:
        tileColor = Colors.blue[50]!; borderColor = Colors.blue[200]!;
        iconColor = Colors.blue[700]!; icon = Icons.info_outline;
        break;
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmergencyAlertPage(warning: w))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.title, style: TextStyle(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                    '${w.alertLevel.displayName} • ${_timeAgo(w.createdAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: iconColor, size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Reports ─────────────────────────────────────────────────────────────────

  Widget _buildReportsSection() {
    if (_loadingReports) return _loadingCard();
    if (_reportsError != null) return _errorCard(_reportsError!, _loadReports);
    if (_reports.isEmpty) {
      return _emptyCard(Icons.check_circle_outline, 'No recent reports', 'No community reports in this area.');
    }
    return Column(
      children: _reports.take(5).map(_buildReportTile).toList(),
    );
  }

  Widget _buildReportTile(Report r) {
    final Color typeColor = _colorForType(r.reportType);
    final IconData typeIcon = _iconForType(r.reportType);

    return GestureDetector(
      onTap: () => _showReportDetail(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(typeIcon, color: typeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.typeLabel} — ${r.locationName}',
                    style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_timeAgo(r.createdAt)}${r.distanceKm != null ? ' • ${r.distanceKm!.toStringAsFixed(1)} km away' : ''}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
            _buildStatusDot(r.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    final color = status == 'validated' ? Colors.green : Colors.orange;
    final label = status == 'validated' ? 'Verified' : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showReportDetail(Report r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final typeColor = _colorForType(r.reportType);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_iconForType(r.reportType), color: typeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.typeLabel ?? 'Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                  Text(r.locationName, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ])),
                _buildStatusDot(r.status),
              ]),
              const SizedBox(height: 16),
              Text(r.description ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(_timeAgo(r.createdAt), style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                if (r.distanceKm != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.near_me, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('${r.distanceKm!.toStringAsFixed(1)} km away', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
                if (r.vouchCount > 0) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.thumb_up, size: 14, color: Colors.blue[400]),
                  const SizedBox(width: 4),
                  Text('${r.vouchCount} vouch${r.vouchCount == 1 ? '' : 'es'}',
                      style: TextStyle(color: Colors.blue[400], fontSize: 12)),
                ],
              ]),
              if (r.vulnerablePerson) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.priority_high, size: 14, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Text('Involves vulnerable person', style: TextStyle(color: Colors.red[400], fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── News ─────────────────────────────────────────────────────────────────────

  Widget _buildNewsSection() {
    return Column(
      children: _news.map(_buildNewsTile).toList(),
    );
  }

  Widget _buildNewsTile(DisasterNews article) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NewsDetailPage(article: article)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: article.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(article.icon, color: article.accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.title,
                      style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: article.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(article.category,
                          style: TextStyle(color: article.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.menu_book_outlined, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text('${article.readMinutes} min read', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  Widget _loadingCard() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      ),
    );
  }

  Widget _errorCard(String msg, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.wifi_off, color: Colors.red[400], size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: TextStyle(color: Colors.red[700], fontSize: 12))),
        TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(color: Color(0xFF2E7D32)))),
      ]),
    );
  }

  Widget _emptyCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Column(children: [
        Icon(icon, color: Colors.green[300], size: 36),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'flood': return Colors.blue[700]!;
      case 'blocked_road': return Colors.orange[700]!;
      case 'landslide': return Colors.brown[700]!;
      case 'medical_emergency': return Colors.red[700]!;
      default: return Colors.grey[700]!;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'flood': return Icons.water_drop;
      case 'blocked_road': return Icons.block;
      case 'landslide': return Icons.landscape;
      case 'medical_emergency': return Icons.medical_services_rounded;
      default: return Icons.warning_amber_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
