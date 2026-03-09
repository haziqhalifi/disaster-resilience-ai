import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/models/warning_model.dart';
import 'package:disaster_resilience_ai/ui/emergency_alert_page.dart';

class AllWarningsPage extends StatelessWidget {
  final List<Warning> warnings;

  const AllWarningsPage({super.key, required this.warnings});

  @override
  Widget build(BuildContext context) {
    // Sort by severity descending, then by most recent first
    final sorted = [...warnings]
      ..sort((a, b) {
        final cmp = b.alertLevel.severityIndex.compareTo(
          a.alertLevel.severityIndex,
        );
        return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF2E7D32),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Warnings',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${sorted.length} warning${sorted.length == 1 ? '' : 's'} found',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF4CAF50),
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No Active Warnings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your area is currently safe.',
                    style: TextStyle(color: Colors.grey),
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
    final Color tileColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;

    switch (warning.alertLevel) {
      case AlertLevel.evacuate:
        tileColor = Colors.red[50]!;
        borderColor = Colors.red[300]!;
        iconColor = Colors.red[700]!;
        icon = Icons.directions_run;
        break;
      case AlertLevel.warning:
        tileColor = Colors.orange[50]!;
        borderColor = Colors.orange[300]!;
        iconColor = Colors.orange[700]!;
        icon = Icons.warning_amber_rounded;
        break;
      case AlertLevel.observe:
        tileColor = Colors.amber[50]!;
        borderColor = Colors.amber[300]!;
        iconColor = Colors.amber[700]!;
        icon = Icons.visibility_outlined;
        break;
      case AlertLevel.advisory:
        tileColor = Colors.blue[50]!;
        borderColor = Colors.blue[200]!;
        iconColor = Colors.blue[700]!;
        icon = Icons.info_outline;
        break;
    }

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
                color: Colors.white,
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
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${warning.hazardType.displayName} • ${warning.alertLevel.displayName} • ${_timeAgo(warning.createdAt)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
