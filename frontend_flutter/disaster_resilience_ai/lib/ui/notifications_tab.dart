import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';

class NotificationsTab extends StatefulWidget {
  const NotificationsTab({
    super.key,
    required this.accessToken,
    required this.warnings,
  });

  final String accessToken;
  final List<Warning> warnings;

  @override
  State<NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<NotificationsTab> {
  static const int _previewCount = 3;
  bool _showAllRecent = false;
  bool _showAllOlder = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final recentCutoff = now.subtract(const Duration(days: 3));

    final sorted = _deduplicatedById(widget.warnings);

    final recentWarnings = sorted
        .where((w) => !w.createdAt.isBefore(recentCutoff))
        .toList();
    final olderWarnings = sorted
        .where((w) => w.createdAt.isBefore(recentCutoff))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      color: const Color(0xFF2E7D32),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (sorted.isEmpty)
            SliverToBoxAdapter(
              child: _emptyCard(
                context,
                isDark,
                Icons.check_circle_outline,
                'No notifications',
                'You are all caught up',
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: _sectionHeader(
                context,
                isDark,
                Icons.notifications_active_outlined,
                'Recent Notifications',
                recentWarnings.length,
              ),
            ),
            if (recentWarnings.isEmpty)
              SliverToBoxAdapter(
                child: _emptyCard(
                  context,
                  isDark,
                  Icons.notifications_none,
                  'No recent notifications',
                  'No alerts from the last 3 days',
                ),
              ),
            if (recentWarnings.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _warningTile(ctx, isDark, recentWarnings[i]),
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
                    onTap: () {
                      setState(() {
                        _showAllRecent = !_showAllRecent;
                      });
                    },
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: _sectionHeader(
                context,
                isDark,
                Icons.history,
                'Older Notifications',
                olderWarnings.length,
              ),
            ),
            if (olderWarnings.isEmpty)
              SliverToBoxAdapter(
                child: _emptyCard(
                  context,
                  isDark,
                  Icons.schedule,
                  'No older notifications',
                  'Older alerts will appear here',
                ),
              ),
            if (olderWarnings.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _warningTile(ctx, isDark, olderWarnings[i]),
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
                    onTap: () {
                      setState(() {
                        _showAllOlder = !_showAllOlder;
                      });
                    },
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Warning tile ──────────────────────────────────────────────────────────

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

    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final metaColor = isDark
        ? const Color(0xFFB8C2BA)
        : const Color(0xFF64748B);

    return GestureDetector(
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionHeader(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    int count,
  ) {
    final theme = Theme.of(context);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final accent = isDark ? const Color(0xFF9EDB94) : const Color(0xFF2E7D32);
    final metaColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
    final cardBorder = isDark
        ? const Color(0xFF334236)
        : const Color(0xFFE2E8F0);
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final metaColor = isDark
        ? const Color(0xFF9AA79B)
        : const Color(0xFF64748B);
    final accent = isDark ? const Color(0xFF86C77C) : const Color(0xFF4CAF50);

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

  Widget _expandButton({
    required BuildContext context,
    required bool isDark,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    final accent = isDark ? const Color(0xFF9EDB94) : const Color(0xFF2E7D32);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(12),
          color: isDark ? const Color(0xFF1B251B) : Colors.white,
        ),
        child: Center(
          child: Text(
            expanded ? 'Show less' : 'View all',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
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
