import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';

class AllWarningsPage extends StatelessWidget {
  final List<Warning> warnings;

  const AllWarningsPage({super.key, required this.warnings});

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
    final dividerColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);

    // Sort by severity descending, then by most recent first
    final sorted = [...warnings]
      ..sort((a, b) {
        final cmp = b.alertLevel.severityIndex.compareTo(
          a.alertLevel.severityIndex,
        );
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? const Color(0xFF9EDB94) : const Color(0xFF2E7D32),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Warnings',
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${sorted.length} warning${sorted.length == 1 ? '' : 's'} found',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      ),
      body: sorted.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: isDark
                        ? const Color(0xFF86C77C)
                        : const Color(0xFF4CAF50),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Active Warnings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your area is currently safe.',
                    style: TextStyle(color: subtitleColor),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, index) =>
                  _buildTile(context, sorted[index]),
            ),
    );
  }

  Widget _buildTile(BuildContext context, Warning warning) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color tileColor;
    final Color borderColor;
    final Color iconColor;
    final Color titleColor;
    final Color metaColor;
    final Color iconCardColor;
    final IconData icon;

    switch (warning.alertLevel) {
      case AlertLevel.evacuate:
        tileColor = isDark ? const Color(0xFF3E1D1D) : Colors.red[50]!;
        borderColor = isDark ? const Color(0xFF7F1D1D) : Colors.red[300]!;
        iconColor = isDark ? const Color(0xFFFCA5A5) : Colors.red[700]!;
        icon = Icons.directions_run;
        break;
      case AlertLevel.warning:
        tileColor = isDark ? const Color(0xFF3B2817) : Colors.orange[50]!;
        borderColor = isDark ? const Color(0xFF9A3412) : Colors.orange[300]!;
        iconColor = isDark ? const Color(0xFFFDBA74) : Colors.orange[700]!;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertLevel.observe:
        tileColor = isDark ? const Color(0xFF373018) : Colors.amber[50]!;
        borderColor = isDark ? const Color(0xFFA16207) : Colors.amber[300]!;
        iconColor = isDark ? const Color(0xFFFCD34D) : Colors.amber[700]!;
        icon = Icons.visibility_outlined;
        break;
      case AlertLevel.advisory:
        tileColor = isDark ? const Color(0xFF192A3A) : Colors.blue[50]!;
        borderColor = isDark ? const Color(0xFF1E40AF) : Colors.blue[200]!;
        iconColor = isDark ? const Color(0xFF93C5FD) : Colors.blue[700]!;
        icon = Icons.info_outline;
        break;
    }
    titleColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B);
    metaColor = isDark ? const Color(0xFFB8C2BA) : const Color(0xFF64748B);
    iconCardColor = isDark ? const Color(0xFF243124) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmergencyAlertPage(warning: warning),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconCardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${warning.hazardType.displayName} • ${warning.alertLevel.displayName} • ${_timeAgo(warning.createdAt)}',
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
