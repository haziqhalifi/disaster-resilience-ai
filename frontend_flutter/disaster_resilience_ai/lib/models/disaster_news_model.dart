import 'package:flutter/material.dart';

class DisasterNews {
  final String id;
  final String title;
  final String summary;
  final String body;
  final String category;
  final IconData icon;
  final Color accentColor;
  final DateTime publishedAt;
  final String source;
  final int readMinutes;

  const DisasterNews({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.publishedAt,
    required this.source,
    required this.readMinutes,
  });
}

/// Curated static disaster news and preparedness articles.
class DisasterNewsData {
  static final List<DisasterNews> articles = [
    DisasterNews(
      id: '1',
      title: 'Understanding Flood Early Warning Systems in Malaysia',
      summary:
          'How JPS monitors river levels and issues alerts to protect communities in flood-prone areas.',
      body:
          'Malaysia\'s Department of Irrigation and Drainage (JPS) operates one of Southeast Asia\'s most advanced flood early warning networks. With over 1,800 telemetric rain and water level stations nationwide, JPS can detect rising river levels hours before flooding reaches populated areas.\n\n'
          '**How the System Works**\n\n'
          'Water level sensors transmit real-time data every 15 minutes to JPS\'s flood forecasting centres. When levels exceed critical thresholds — typically 85–95% of bankfull capacity — the system automatically triggers alerts to state disaster management agencies.\n\n'
          '**Three-Tier Warning Levels**\n\n'
          '• **Alert (Siaga)** — Water rising; residents in low-lying areas should prepare\n'
          '• **Warning (Amaran)** — High probability of flooding; move valuables upstairs\n'
          '• **Danger (Bahaya)** — Immediate evacuation required\n\n'
          '**What You Should Do**\n\n'
          'When you receive a flood warning, do not wait for water to reach your doorstep. Begin evacuation early. Use this app\'s Safe Routes feature to find recommended evacuation paths in your area.',
      category: 'Flood',
      icon: Icons.water_rounded,
      accentColor: Color(0xFF1565C0),
      publishedAt: DateTime(2026, 3, 7),
      source: 'JPS Malaysia',
      readMinutes: 4,
    ),
    DisasterNews(
      id: '2',
      title: 'Northeast Monsoon: Preparing Pahang for the Season',
      summary:
          'The Northeast Monsoon brings heavy rainfall to Pahang from November to March — here\'s how to stay ready.',
      body:
          'The Northeast Monsoon (Monsun Timur Laut) is a seasonal weather pattern that affects Malaysia\'s east coast states — Kelantan, Terengganu, and Pahang — from November through March each year.\n\n'
          '**What to Expect**\n\n'
          'During the monsoon, Pahang receives significantly above-average rainfall, with coastal and river-valley areas facing the highest flood risk. Kuantan, Pekan, and Temerloh districts have historically been most affected.\n\n'
          '**Pre-Season Checklist**\n\n'
          '• Clear drains and gutters around your home\n'
          '• Inspect your roof and seal any leaks\n'
          '• Stock at least 7 days of food and water\n'
          '• Identify your nearest evacuation centre\n'
          '• Ensure your vehicle is fuelled\n\n'
          '**During the Monsoon**\n\n'
          '• Monitor JPS alerts and this app\'s warning system daily\n'
          '• Do not attempt to cross flooded roads — just 30 cm of fast-moving water can sweep a vehicle\n'
          '• Keep emergency cash and important documents in a waterproof bag\n\n'
          '**Recovery Planning**\n\n'
          'Know your insurance coverage. The government\'s BNPM (Natural Disaster Relief Fund) provides assistance for those without insurance. Contact your district office (Pejabat Daerah) for registration.',
      category: 'Weather',
      icon: Icons.thunderstorm_rounded,
      accentColor: Color(0xFF6A1B9A),
      publishedAt: DateTime(2026, 3, 6),
      source: 'MetMalaysia',
      readMinutes: 5,
    ),
    DisasterNews(
      id: '3',
      title: 'Emergency Kit Guide: What Every Malaysian Home Needs',
      summary:
          'A practical, affordable guide to building a 72-hour emergency supply kit for your household.',
      body:
          'Emergency preparedness experts recommend that every household maintain a 72-hour (3-day) emergency kit. Communities with prepared households recover from disasters significantly faster.\n\n'
          '**Water**\n\n'
          'Store 3 litres per person per day. For a family of four, that\'s 36 litres minimum. Use food-grade containers and rotate every 6 months.\n\n'
          '**Food**\n\n'
          '• Canned goods (sardines, corned beef, vegetables)\n'
          '• Biscuits and crackers\n'
          '• Energy bars and nuts\n'
          '• Baby formula / special dietary foods if needed\n\n'
          '**Documents (in a waterproof envelope)**\n\n'
          '• IC copies for all family members\n'
          '• Insurance policies\n'
          '• Medical prescriptions\n'
          '• Emergency contact list (on paper, not just your phone)\n\n'
          '**Health & First Aid**\n\n'
          '• First aid kit with bandages, antiseptic, and scissors\n'
          '• 7-day supply of any prescription medications\n'
          '• Masks, gloves, hand sanitiser\n\n'
          '**Tools**\n\n'
          '• Torch with extra batteries\n'
          '• Battery-powered or hand-crank radio\n'
          '• Power bank charged to full\n'
          '• Whistle (to signal for rescue)\n\n'
          'Store everything in a large waterproof bag near your exit. Check and refresh it every 6 months.',
      category: 'Preparedness',
      icon: Icons.backpack_rounded,
      accentColor: Color(0xFF2E7D32),
      publishedAt: DateTime(2026, 3, 5),
      source: 'NADMA',
      readMinutes: 6,
    ),
    DisasterNews(
      id: '4',
      title: 'New Flood Monitoring Stations Along Sungai Pahang',
      summary:
          'JPS expanded its telemetric network with 12 new stations to improve early warning lead times.',
      body:
          'The Department of Irrigation and Drainage (JPS) has completed installation of 12 new telemetric water level and rainfall monitoring stations along Sungai Pahang and its major tributaries as part of the 12th Malaysia Plan.\n\n'
          '**About This Expansion**\n\n'
          'The new stations are located in areas that previously had gaps in monitoring coverage — particularly along the upper Pahang valley from Temerloh to Maran. The RM 4.2 million project was funded under the National Flood Mitigation Programme.\n\n'
          '**How This Helps You**\n\n'
          '• Earlier warnings — lead time for evacuation notices improved from 2 hours to up to 6 hours\n'
          '• More accurate flood forecasting using real-time data\n'
          '• Better coordination between JPS, state disaster agencies, and this app\n\n'
          '**What\'s Next**\n\n'
          'JPS plans to install an additional 30 stations in Kelantan and Terengganu before the 2026–2027 monsoon season.',
      category: 'Infrastructure',
      icon: Icons.sensors_rounded,
      accentColor: Color(0xFF00838F),
      publishedAt: DateTime(2026, 3, 4),
      source: 'JPS Malaysia',
      readMinutes: 3,
    ),
    DisasterNews(
      id: '5',
      title: 'Landslide Risk Zones in Peninsular Malaysia',
      summary:
          'Understanding which areas carry the highest landslide risk and what warning signs to watch for.',
      body:
          'Landslides are among Malaysia\'s most deadly natural hazards. Hilly terrain, high rainfall, and development on slopes combine to create significant risk — particularly in highland areas.\n\n'
          '**High-Risk Areas**\n\n'
          '• Cameron Highlands, Pahang\n'
          '• Fraser\'s Hill and Genting Highlands\n'
          '• Bukit Antarabangsa, Ampang (Selangor)\n'
          '• Slope cuts along the Karak Highway corridor\n\n'
          '**Warning Signs**\n\n'
          '• Cracks appearing in the ground or walls of buildings near slopes\n'
          '• Newly appearing spring water or increased muddy runoff\n'
          '• Tilting trees, telephone poles, or fences\n'
          '• Unusual rumbling sounds from slopes\n\n'
          '**What To Do**\n\n'
          '1. Evacuate immediately — do not wait for confirmation\n'
          '2. Move horizontally away from the slide path, not downhill\n'
          '3. Call Bomba (994) or your local Civil Defence (APM)\n'
          '4. Report the location using this app\'s Community Report feature\n\n'
          '**After a Landslide**\n\n'
          'Stay out of the slide area. Secondary slides are common. Do not enter damaged buildings until structural engineers certify them safe.',
      category: 'Landslide',
      icon: Icons.terrain_rounded,
      accentColor: Color(0xFF6D4C41),
      publishedAt: DateTime(2026, 3, 3),
      source: 'Minerals & Geoscience Dept (JMG)',
      readMinutes: 5,
    ),
    DisasterNews(
      id: '6',
      title: 'Earthquake Preparedness: Lessons from Sabah',
      summary:
          'What the 6.0-magnitude Ranau earthquake taught Malaysia about readiness — and how to prepare.',
      body:
          'On 5 June 2015, a 6.0-magnitude earthquake struck near Ranau, Sabah, killing 18 people and injuring 11. It remains one of the most significant earthquakes ever recorded in Malaysia.\n\n'
          '**Malaysia\'s Seismic Risk**\n\n'
          'Peninsular Malaysia lies away from active tectonic boundaries and has relatively low seismic risk. However, Sabah — particularly areas near the Ranau fault zone — experiences moderate earthquake activity.\n\n'
          '**Key Lessons from 2015**\n\n'
          '• Buildings built before modern seismic standards can suffer significant damage from moderate quakes\n'
          '• Communication blackouts hampered rescue operations — have offline maps and local contact numbers\n'
          '• First responders need clear access routes — do not park on evacuation roads\n\n'
          '**During Shaking (DROP, COVER, HOLD ON)**\n\n'
          '• Drop to hands and knees immediately\n'
          '• Take cover under a sturdy table or desk\n'
          '• Stay away from windows and exterior walls\n'
          '• If outdoors, move to open ground away from buildings\n\n'
          '**After the Quake**\n\n'
          '• Check for gas leaks — if suspected, leave immediately\n'
          '• Do not use lifts\n'
          '• Expect aftershocks for the next 24–72 hours',
      category: 'Earthquake',
      icon: Icons.vibration_rounded,
      accentColor: Color(0xFFE65100),
      publishedAt: DateTime(2026, 3, 2),
      source: 'Malaysian Meteorological Dept',
      readMinutes: 6,
    ),
    DisasterNews(
      id: '7',
      title: 'How to Help Your Community After a Disaster',
      summary:
          'Practical ways to contribute to recovery efforts while keeping yourself and others safe.',
      body:
          'In the aftermath of a disaster, community solidarity is one of the most powerful forces for recovery. However, uncoordinated assistance can hinder professional relief efforts.\n\n'
          '**Before Rushing In**\n\n'
          '• Wait for official clearance before entering disaster zones\n'
          '• Register as a volunteer with a recognised organisation (e.g., Mercy Malaysia, Red Crescent)\n\n'
          '**What Communities Actually Need**\n\n'
          '• **Cash donations** to reputable organisations — they can purchase exactly what\'s needed\n'
          '• **Dry food in sealed packaging** (coordinated with shelter teams)\n'
          '• **Time and labour** for clean-up efforts\n'
          '• **Skilled volunteers** — medical professionals, engineers, social workers\n\n'
          '**Using This App to Help**\n\n'
          '• Submit community reports of hazards or unserved areas via the Reports tab\n'
          '• Share the app with neighbours — the more connected a community, the faster it recovers\n\n'
          '**Mental Health Matters**\n\n'
          'Disasters are traumatic. Check on neighbours — especially the elderly and those living alone. Contact the Befrienders Malaysia hotline (03-7627 2929) for emotional support.',
      category: 'Community',
      icon: Icons.people_rounded,
      accentColor: Color(0xFF00796B),
      publishedAt: DateTime(2026, 3, 1),
      source: 'NADMA',
      readMinutes: 4,
    ),
    DisasterNews(
      id: '8',
      title: 'Climate Change and Malaysia\'s Increasing Flood Risk',
      summary:
          'Scientists explain why floods in Malaysia are becoming more frequent and severe — and what needs to change.',
      body:
          'Malaysia has experienced a statistically significant increase in both the frequency and intensity of extreme rainfall events over the past two decades — a trend attributed primarily to climate change.\n\n'
          '**The Evidence**\n\n'
          '• Annual average rainfall has increased by approximately 8% since 2000\n'
          '• The occurrence of extreme rainfall days (>100 mm in 24 hours) has more than doubled in east coast states\n'
          '• 7 of the 10 most expensive flood disasters in Malaysian history have occurred since 2010\n\n'
          '**Why Is This Happening?**\n\n'
          'A warmer atmosphere holds more moisture. For every 1°C increase in temperature, the atmosphere holds ~7% more water vapour. When rain falls, it falls harder. Changing monsoon patterns are also concentrating rainfall over shorter, more intense periods.\n\n'
          '**The Urban Flooding Problem**\n\n'
          'Rapid urbanisation has replaced permeable land (forests, fields) with impermeable surfaces (roads, concrete). Water that once soaked into the ground now flows rapidly into drains and rivers, overwhelming urban drainage systems.\n\n'
          '**What You Can Do**\n\n'
          '• Plant vegetation around your home to improve water absorption\n'
          '• Avoid blocking neighbourhood drains with debris\n'
          '• Advocate for better urban planning in your local council',
      category: 'Climate',
      icon: Icons.eco_rounded,
      accentColor: Color(0xFF1B5E20),
      publishedAt: DateTime(2026, 2, 28),
      source: 'MetMalaysia / NAHRIM',
      readMinutes: 7,
    ),
  ];
}
