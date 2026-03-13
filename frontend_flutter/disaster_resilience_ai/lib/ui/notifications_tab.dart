import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({
    super.key,
    required this.accessToken,
    required this.warnings,
    this.latitude,
    this.longitude,
  });

  final String accessToken;
  final List<Warning> warnings;
  final double? latitude;
  final double? longitude;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsTabState extends State<NotificationsTab>
    with SingleTickerProviderStateMixin {
  static const int _previewCount = 3;
  bool _showAllRecent = false;
  bool _showAllOlder = false;
  bool _showAllMyReports = false;
  bool _showAllCommunity = false;

  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _communityReports = [];
  List<Map<String, dynamic>> _myReports = [];
  bool _loadingExtra = false;

  // Shimmer controller — pulses the placeholder skeleton cards.
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _fetchExtra();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // ── Data fetching (unchanged) ───────────────────────────────────────────────

  Future<void> _fetchExtra() async {
    if (widget.accessToken.isEmpty) return;
    setState(() => _loadingExtra = true);

    // Run both fetches independently so one failure doesn't block the other.
    final myFuture = _api
        .fetchAllMyReports(accessToken: widget.accessToken)
        .catchError((_) => <String, dynamic>{});

    Future<Map<String, dynamic>> communityFuture =
        Future.value(<String, dynamic>{});
    if (widget.latitude != null && widget.longitude != null) {
      communityFuture = _api
          .fetchNearbyReports(
            accessToken: widget.accessToken,
            latitude: widget.latitude!,
            longitude: widget.longitude!,
            radiusKm: 10,
            statusFilter: 'validated',
          )
          .catchError((_) => <String, dynamic>{});
    }

    final results = await Future.wait([myFuture, communityFuture]);

    final myList = (results[0]['reports'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final communityList = (results[1]['reports'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    if (mounted) {
      setState(() {
        _myReports = myList;
        _communityReports = communityList;
        _loadingExtra = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final recentCutoff = now.subtract(const Duration(days: 3));

    final sorted = _deduplicatedById(widget.warnings);

    final recentWarnings =
        sorted.where((w) => !w.createdAt.isBefore(recentCutoff)).toList();
    final olderWarnings =
        sorted.where((w) => w.createdAt.isBefore(recentCutoff)).toList();

    return RefreshIndicator(
      onRefresh: () async => _fetchExtra(),
      color: const Color(0xFF2E7D32),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── All-clear empty state ──────────────────────────────────────────
          if (sorted.isEmpty &&
              _communityReports.isEmpty &&
              _myReports.isEmpty &&
              !_loadingExtra)
            SliverToBoxAdapter(
              child: _StaggeredItem(
                delay: Duration.zero,
                child: _emptyCard(
                  context,
                  isDark,
                  Icons.check_circle_outline,
                  'No notifications',
                  'You are all caught up',
                ),
              ),
            )
          else ...[

            // ── Official Alerts ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StaggeredItem(
                delay: Duration.zero,
                child: _sectionHeader(
                  context,
                  isDark,
                  Icons.notifications_active_outlined,
                  'Official Alerts',
                  sorted.length,
                ),
              ),
            ),
            if (sorted.isEmpty)
              SliverToBoxAdapter(
                child: _StaggeredItem(
                  delay: const Duration(milliseconds: 60),
                  child: _emptyCard(
                    context,
                    isDark,
                    Icons.notifications_none,
                    'No official alerts',
                    'No active government warnings',
                  ),
                ),
              ),
            if (recentWarnings.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _StaggeredItem(
                  delay: const Duration(milliseconds: 60),
                  child: _subSectionLabel(context, isDark, 'Recent (last 3 days)'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StaggeredItem(
                      delay: Duration(milliseconds: 80 + i * 55),
                      child: _warningTile(ctx, isDark, recentWarnings[i]),
                    ),
                    childCount: _showAllRecent
                        ? recentWarnings.length
                        : math.min(_previewCount, recentWarnings.length),
                  ),
                ),
              ),
              if (recentWarnings.length > _previewCount)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _expandButton(
                      context: context,
                      isDark: isDark,
                      expanded: _showAllRecent,
                      onTap: () =>
                          setState(() => _showAllRecent = !_showAllRecent),
                    ),
                  ),
                ),
            ],
            if (olderWarnings.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _subSectionLabel(context, isDark, 'Older'),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StaggeredItem(
                      delay: Duration(milliseconds: 80 + i * 55),
                      child: _warningTile(ctx, isDark, olderWarnings[i]),
                    ),
                    childCount: _showAllOlder
                        ? olderWarnings.length
                        : math.min(_previewCount, olderWarnings.length),
                  ),
                ),
              ),
              if (olderWarnings.length > _previewCount)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _expandButton(
                      context: context,
                      isDark: isDark,
                      expanded: _showAllOlder,
                      onTap: () =>
                          setState(() => _showAllOlder = !_showAllOlder),
                    ),
                  ),
                ),
            ],

            // ── Community Alerts Nearby ──────────────────────────────────────
            SliverToBoxAdapter(
              child: _StaggeredItem(
                delay: const Duration(milliseconds: 100),
                child: _sectionHeader(
                  context,
                  isDark,
                  Icons.groups_outlined,
                  'Community Alerts Nearby',
                  _communityReports.length,
                ),
              ),
            ),
            if (_loadingExtra)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => _ShimmerCard(
                      shimmer: _shimmerController,
                      isDark: isDark,
                    ),
                    childCount: 2,
                  ),
                ),
              )
            else if (_communityReports.isEmpty)
              SliverToBoxAdapter(
                child: _StaggeredItem(
                  delay: const Duration(milliseconds: 140),
                  child: _emptyCard(
                    context,
                    isDark,
                    Icons.location_on_outlined,
                    'No community alerts nearby',
                    'No validated reports within 10 km',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StaggeredItem(
                      delay: Duration(milliseconds: 140 + i * 60),
                      child: _communityReportTile(
                          ctx, isDark, _communityReports[i]),
                    ),
                    childCount: _showAllCommunity
                        ? _communityReports.length
                        : math.min(_previewCount, _communityReports.length),
                  ),
                ),
              ),
              if (_communityReports.length > _previewCount)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _expandButton(
                      context: context,
                      isDark: isDark,
                      expanded: _showAllCommunity,
                      onTap: () => setState(
                          () => _showAllCommunity = !_showAllCommunity),
                    ),
                  ),
                ),
            ],

            // ── My Submitted Reports ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: _StaggeredItem(
                delay: const Duration(milliseconds: 160),
                child: _sectionHeader(
                  context,
                  isDark,
                  Icons.assignment_outlined,
                  'My Reports',
                  _myReports.length,
                ),
              ),
            ),
            if (_loadingExtra)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, __) => _ShimmerCard(
                      shimmer: _shimmerController,
                      isDark: isDark,
                    ),
                    childCount: 2,
                  ),
                ),
              )
            else if (_myReports.isEmpty)
              SliverToBoxAdapter(
                child: _StaggeredItem(
                  delay: const Duration(milliseconds: 200),
                  child: _emptyCard(
                    context,
                    isDark,
                    Icons.edit_off_outlined,
                    'No reports submitted',
                    'Reports you submit will appear here',
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StaggeredItem(
                      delay: Duration(milliseconds: 200 + i * 60),
                      child: _myReportTile(ctx, isDark, _myReports[i]),
                    ),
                    childCount: _showAllMyReports
                        ? _myReports.length
                        : math.min(_previewCount, _myReports.length),
                  ),
                ),
              ),
              if (_myReports.length > _previewCount)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _expandButton(
                      context: context,
                      isDark: isDark,
                      expanded: _showAllMyReports,
                      onTap: () => setState(
                          () => _showAllMyReports = !_showAllMyReports),
                    ),
                  ),
                ),
            ],
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Community report tile ──────────────────────────────────────────────────

  Widget _communityReportTile(
      BuildContext context, bool isDark, Map<String, dynamic> r) {
    final reportType = (r['report_type'] as String? ?? 'unknown')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    final location = r['location_name'] as String? ?? 'Unknown location';
    final createdAt = r['created_at'] != null
        ? _timeAgo(
            DateTime.tryParse(r['created_at'] as String) ?? DateTime.now())
        : '';

    final tileColor = isDark ? const Color(0xFF3B2817) : Colors.orange[50]!;
    final borderColor =
        isDark ? const Color(0xFF9A3412) : Colors.orange[300]!;
    final iconColor = isDark ? const Color(0xFFFDBA74) : Colors.orange[700]!;
    final titleColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final metaColor =
        isDark ? const Color(0xFFB8C2BA) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF243124) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(Icons.warning_amber_rounded, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reportType,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$location • $createdAt',
                  style: TextStyle(color: metaColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(40),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Validated',
              style: TextStyle(
                color: iconColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── My report tile ─────────────────────────────────────────────────────────

  Widget _myReportTile(
      BuildContext context, bool isDark, Map<String, dynamic> r) {
    final reportType = (r['report_type'] as String? ?? 'unknown')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    final location = r['location_name'] as String? ?? 'Unknown location';
    final status = r['status'] as String? ?? 'pending';
    final createdAt = r['created_at'] != null
        ? _timeAgo(
            DateTime.tryParse(r['created_at'] as String) ?? DateTime.now())
        : '';

    final Color statusColor;
    final String statusLabel;
    switch (status) {
      case 'validated':
        statusColor = const Color(0xFF16A34A);
        statusLabel = 'Approved';
        break;
      case 'rejected':
        statusColor = const Color(0xFFDC2626);
        statusLabel = 'Rejected';
        break;
      case 'resolved':
        statusColor = const Color(0xFF2563EB);
        statusLabel = 'Resolved';
        break;
      default:
        statusColor = const Color(0xFFD97706);
        statusLabel = 'Pending';
    }

    final tileColor = isDark ? const Color(0xFF192A3A) : Colors.blue[50]!;
    final borderColor = isDark ? const Color(0xFF1E40AF) : Colors.blue[200]!;
    final iconColor = isDark ? const Color(0xFF93C5FD) : Colors.blue[700]!;
    final titleColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final metaColor =
        isDark ? const Color(0xFFB8C2BA) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2A3B) : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.assignment_outlined, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reportType,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$location • $createdAt',
                  style: TextStyle(color: metaColor, fontSize: 12),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Container(
              key: ValueKey(statusLabel),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Warning tile ───────────────────────────────────────────────────────────

  Widget _warningTile(BuildContext context, bool isDark, Warning w) {
    final Color tileColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    switch (w.alertLevel) {
      case AlertLevel.evacuate:
        tileColor = isDark ? const Color(0xFF3E1D1D) : Colors.red[50]!;
        borderColor = isDark ? const Color(0xFF7F1D1D) : Colors.red[300]!;
        iconColor = isDark ? const Color(0xFFFCA5A5) : Colors.red[700]!;
        icon = Icons.directions_run;
      case AlertLevel.warning:
        tileColor = isDark ? const Color(0xFF3B2817) : Colors.orange[50]!;
        borderColor = isDark ? const Color(0xFF9A3412) : Colors.orange[300]!;
        iconColor = isDark ? const Color(0xFFFDBA74) : Colors.orange[700]!;
        icon = Icons.warning_amber_rounded;
      case AlertLevel.observe:
        tileColor = isDark ? const Color(0xFF373018) : Colors.amber[50]!;
        borderColor = isDark ? const Color(0xFFA16207) : Colors.amber[300]!;
        iconColor = isDark ? const Color(0xFFFCD34D) : Colors.amber[700]!;
        icon = Icons.visibility_outlined;
      case AlertLevel.advisory:
        tileColor = isDark ? const Color(0xFF192A3A) : Colors.blue[50]!;
        borderColor = isDark ? const Color(0xFF1E40AF) : Colors.blue[200]!;
        iconColor = isDark ? const Color(0xFF93C5FD) : Colors.blue[700]!;
        icon = Icons.info_outline;
    }

    final titleColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final metaColor =
        isDark ? const Color(0xFFB8C2BA) : const Color(0xFF64748B);

    return _TappableCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EmergencyAlertPage(warning: w)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF243124) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${w.hazardType.displayName} • ${w.alertLevel.displayName} • ${_timeAgo(w.createdAt)}',
                    style: TextStyle(color: metaColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: iconColor),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _subSectionLabel(BuildContext context, bool isDark, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color:
              isDark ? const Color(0xFF9AA79B) : const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    int count,
  ) {
    final theme = Theme.of(context);
    final titleColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final accent =
        isDark ? const Color(0xFF9EDB94) : const Color(0xFF2E7D32);
    final metaColor =
        isDark ? const Color(0xFF9AA79B) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Container(
              key: ValueKey(count),
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: metaColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final titleColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    final metaColor =
        isDark ? const Color(0xFF9AA79B) : const Color(0xFF64748B);
    final accent =
        isDark ? const Color(0xFF86C77C) : const Color(0xFF4CAF50);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 28),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: metaColor, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Expand / collapse button with animated chevron rotation and text fade.
  Widget _expandButton({
    required BuildContext context,
    required bool isDark,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    final accent =
        isDark ? const Color(0xFF9EDB94) : const Color(0xFF2E7D32);
    final borderColor =
        isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final bgColor = isDark ? const Color(0xFF1B251B) : Colors.white;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: expanded ? 0.0 : 1.0, end: expanded ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      builder: (ctx, t, _) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12),
              color: bgColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  child: Text(
                    expanded ? 'Show less' : 'View all',
                    key: ValueKey(expanded),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Transform.rotate(
                  angle: t * math.pi, // 0° → 180° as expanded goes true
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: accent,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Warning> _deduplicatedById(List<Warning> warnings) {
    final sorted = [...warnings]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final deduped = <String, Warning>{};
    for (final warning in sorted) {
      deduped.putIfAbsent(warning.id, () => warning);
    }
    return deduped.values.toList();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private animation helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Fade + slide-up entrance with a configurable delay. Each card/section that
/// mounts for the first time runs this once — no re-animation on rebuild.
class _StaggeredItem extends StatefulWidget {
  const _StaggeredItem({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredItem> createState() => _StaggeredItemState();
}

class _StaggeredItemState extends State<_StaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 290),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}

/// Pulsing skeleton card shown while community reports / my reports are loading.
/// Uses the parent's repeating [shimmer] animation so all placeholders pulse
/// in sync without creating extra animation controllers.
class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.shimmer, required this.isDark});

  final Animation<double> shimmer;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final t = shimmer.value; // 0 → 1 → 0 (reverse repeat)
        final base = isDark
            ? Color.lerp(
                const Color(0xFF242424), const Color(0xFF303030), t)!
            : Color.lerp(
                const Color(0xFFEEEEEE), const Color(0xFFF6F6F6), t)!;
        final highlight = isDark
            ? Color.lerp(
                const Color(0xFF2E2E2E), const Color(0xFF3C3C3C), t)!
            : Color.lerp(
                const Color(0xFFF2F2F2), const Color(0xFFFFFFFF), t)!;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Icon placeholder
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              // Text placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      decoration: BoxDecoration(
                        color: highlight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 11,
                      width: 120,
                      decoration: BoxDecoration(
                        color: highlight,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge placeholder
              Container(
                width: 58,
                height: 22,
                decoration: BoxDecoration(
                  color: highlight,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lightweight press-scale wrapper that gives warning tiles a satisfying
/// tap feedback without requiring a StatefulWidget for each tile.
class _TappableCard extends StatefulWidget {
  const _TappableCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
