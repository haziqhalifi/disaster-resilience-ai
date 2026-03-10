import 'package:flutter/material.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(
            color: Color(0xFF1E293B),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[700]!, Colors.red[900]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.sos, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Emergency SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap to alert all emergency contacts\nand nearest rescue teams',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ACTIVATE SOS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Official Emergency Numbers
            const Text(
              'Official Emergency Lines',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildContactCard(
              icon: Icons.local_police,
              iconColor: Colors.blue[700]!,
              bgColor: Colors.blue[50]!,
              name: 'Police (PDRM)',
              phone: '999',
              subtitle: 'National Emergency Line',
            ),
            _buildContactCard(
              icon: Icons.local_fire_department,
              iconColor: Colors.red[700]!,
              bgColor: Colors.red[50]!,
              name: 'Fire & Rescue',
              phone: '994',
              subtitle: 'Bomba Malaysia',
            ),
            _buildContactCard(
              icon: Icons.medical_services,
              iconColor: const Color(0xFF2E7D32),
              bgColor: const Color(0xFFE8F5E9),
              name: 'Ambulance',
              phone: '999',
              subtitle: 'Medical Emergency',
            ),
            _buildContactCard(
              icon: Icons.flood,
              iconColor: Colors.orange[700]!,
              bgColor: Colors.orange[50]!,
              name: 'NADMA Hotline',
              phone: '03-8064 2400',
              subtitle: 'National Disaster Management',
            ),
            _buildContactCard(
              icon: Icons.water,
              iconColor: Colors.teal[700]!,
              bgColor: Colors.teal[50]!,
              name: 'DID Flood Info',
              phone: '1800-88-6722',
              subtitle: 'Dept. of Irrigation & Drainage',
            ),

            const SizedBox(height: 28),

            // Local Community Contacts
            const Text(
              'Local Community Contacts',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildContactCard(
              icon: Icons.person,
              iconColor: const Color(0xFF2E7D32),
              bgColor: const Color(0xFFE8F5E9),
              name: 'Ketua Kampung - En. Razak',
              phone: '+60 12-345 6789',
              subtitle: 'Village Chief, Kg. Melayu',
            ),
            _buildContactCard(
              icon: Icons.groups,
              iconColor: Colors.purple[700]!,
              bgColor: Colors.purple[50]!,
              name: 'JPAM Volunteer Team',
              phone: '+60 13-987 6543',
              subtitle: 'Civil Defence Volunteers',
            ),
            _buildContactCard(
              icon: Icons.local_hospital,
              iconColor: Colors.red[700]!,
              bgColor: Colors.red[50]!,
              name: 'Klinik Kesihatan Kuantan',
              phone: '+60 9-573 3333',
              subtitle: 'Nearest Health Clinic',
            ),

            const SizedBox(height: 28),

            // Quick Tip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tip',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Save these contacts offline. SMS fallback works when there is no internet.',
                          style: TextStyle(
                            color: Colors.amber[800],
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String name,
    required String phone,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                phone,
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone,
                  color: Color(0xFF2E7D32),
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
