import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/ui/submit_report_page.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Community Reports',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Real-time situational awareness from your community',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Alert Stats Row
            Row(
              children: [
                _buildStatCard('12', 'Active\nReports', Colors.orange[700]!, Colors.orange[50]!),
                const SizedBox(width: 12),
                _buildStatCard('3', 'Critical\nAlerts', Colors.red[700]!, Colors.red[50]!),
                const SizedBox(width: 12),
                _buildStatCard('28', 'Resolved\nToday', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', true),
                  const SizedBox(width: 8),
                  _buildFilterChip('Flood', false),
                  const SizedBox(width: 8),
                  _buildFilterChip('Landslide', false),
                  const SizedBox(width: 8),
                  _buildFilterChip('Road Block', false),
                  const SizedBox(width: 8),
                  _buildFilterChip('Medical', false),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Live Reports Feed
            const Row(
              children: [
                Icon(Icons.circle, color: Colors.red, size: 10),
                SizedBox(width: 6),
                Text(
                  'LIVE FEED',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Report items
            _buildReportItem(
              icon: Icons.water_drop,
              iconColor: Colors.blue[700]!,
              bgColor: Colors.blue[50]!,
              title: 'Water Rising - Sungai Lembing',
              subtitle: 'Water level at 2.5m, approaching danger threshold.',
              time: '5 min ago',
              severity: 'HIGH',
              severityColor: Colors.red,
              isVerified: true,
            ),
            _buildReportItem(
              icon: Icons.block,
              iconColor: Colors.orange[700]!,
              bgColor: Colors.orange[50]!,
              title: 'Road Blocked - Jalan Kuantan',
              subtitle: 'Fallen tree blocking main road. Alternate route via Jalan Gambang.',
              time: '18 min ago',
              severity: 'MEDIUM',
              severityColor: Colors.orange,
              isVerified: true,
            ),
            _buildReportItem(
              icon: Icons.landscape,
              iconColor: Colors.brown[700]!,
              bgColor: Colors.brown[50]!,
              title: 'Landslide Risk - Bukit Fraser',
              subtitle: 'Soil erosion detected near hillside settlement area.',
              time: '32 min ago',
              severity: 'HIGH',
              severityColor: Colors.red,
              isVerified: false,
            ),
            _buildReportItem(
              icon: Icons.medical_services_rounded,
              iconColor: Colors.red[700]!,
              bgColor: Colors.red[50]!,
              title: 'Medical Aid Needed - Kg. Banjir',
              subtitle: 'Elderly resident requires medication pickup. Accessible via boat only.',
              time: '1 hour ago',
              severity: 'CRITICAL',
              severityColor: Colors.red[900]!,
              isVerified: true,
            ),
            _buildReportItem(
              icon: Icons.water_drop,
              iconColor: Colors.blue[700]!,
              bgColor: Colors.blue[50]!,
              title: 'River Level Update - Sg. Pahang',
              subtitle: 'Water receding. Current level 1.2m, below warning threshold.',
              time: '2 hours ago',
              severity: 'LOW',
              severityColor: const Color(0xFF2E7D32),
              isVerified: true,
            ),
            const SizedBox(height: 24),

            // Submit new report button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubmitReportPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Submit New Report',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String count, String label, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2E7D32) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? const Color(0xFF2E7D32) : Colors.grey[300]!,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey[700],
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildReportItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required String time,
    required String severity,
    required Color severityColor,
    required bool isVerified,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        severity,
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                    if (isVerified) ...[
                      Icon(Icons.verified, size: 14, color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Text(
                        'AI Verified',
                        style: TextStyle(color: Colors.blue[400], fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
