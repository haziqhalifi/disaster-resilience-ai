import 'dart:async';
import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/services/chatbot_service.dart';
import 'package:disaster_resilience_ai/ui/quiz_page.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';

/// Educational content for each hazard type, split into Before / During / After.
class _PhaseContent {
  final String title;
  final List<String> points;
  const _PhaseContent({required this.title, required this.points});
}

class _ModuleContent {
  final String heroTitle;
  final String heroSubtitle;
  final IconData icon;
  final Color color;
  final _PhaseContent before;
  final _PhaseContent during;
  final _PhaseContent after;
  final List<String> chatSuggestions;
  const _ModuleContent({
    required this.heroTitle,
    required this.heroSubtitle,
    required this.icon,
    required this.color,
    required this.before,
    required this.during,
    required this.after,
    required this.chatSuggestions,
  });
}

final Map<String, _ModuleContent> _content = {
  'flood': _ModuleContent(
    heroTitle: 'Flood Preparedness',
    heroSubtitle:
        'Comprehensive guide to staying safe before, during and after a flood.',
    icon: Icons.water,
    color: const Color(0xFF1565C0),
    before: const _PhaseContent(
      title: 'Before a Flood',
      points: [
        'Monitor weather forecasts and river levels daily during monsoon season.',
        'Prepare a 3-day emergency kit: water (3L/person/day), non-perishable food, torch, batteries, first aid, medications.',
        'Store important documents (IC, passport, insurance) in a sealed waterproof bag.',
        'Know at least two evacuation routes from your home and your nearest relief centre.',
        'Move electrical appliances and valuables to upper floors if possible.',
        'Identify a family meeting point and share the plan with all household members.',
        'Clear drains and gutters around your home to reduce surrounding water levels.',
      ],
    ),
    during: const _PhaseContent(
      title: 'During a Flood',
      points: [
        'Follow evacuation orders immediately — do not wait for water to enter your home.',
        'Move to the highest point available (upper floor, rooftop) if trapped.',
        'Never attempt to walk or drive through floodwater — 15 cm of moving water can knock you down.',
        'Turn off electricity, gas and water at mains before evacuating if safe to do so.',
        'Stay informed through NADMA, Bernama, and local authorities\' alerts.',
        'Help neighbours, especially the elderly, disabled, and families with young children.',
        'Avoid contact with floodwater — it may be contaminated with sewage and chemicals.',
      ],
    ),
    after: const _PhaseContent(
      title: 'After a Flood',
      points: [
        'Return home only after authorities declare the area safe.',
        'Photograph all damage for insurance claims and NADMA relief applications.',
        'Wear gloves, boots and masks when cleaning — floodwater leaves bacteria and silt.',
        'Discard any food that came into contact with floodwater.',
        'Boil or use bottled water until the supply is confirmed safe by JKR/SPAN.',
        'Have a qualified electrician inspect wiring before turning the mains back on.',
        'Seek medical attention for injuries, skin rashes or waterborne illness symptoms.',
        'Replenish your emergency kit and update your family plan.',
      ],
    ),
    chatSuggestions: [
      'What should I pack in a flood kit?',
      'How deep is dangerous?',
      'Can I drive through floodwater?',
      'How to clean after a flood?',
      'Where are relief centres?',
    ],
  ),
  'landslide': _ModuleContent(
    heroTitle: 'Landslide Safety',
    heroSubtitle: 'Recognise warning signs and protect your family on slopes.',
    icon: Icons.terrain,
    color: const Color(0xFF795548),
    before: const _PhaseContent(
      title: 'Before a Landslide',
      points: [
        'Know if your area is on or near a slope classified as high-risk by JMG.',
        'Watch for early signs: new cracks in walls/ground, tilting trees, bulging slopes.',
        'Avoid building or planting heavy vegetation on steep cut slopes.',
        'Maintain proper drainage around your property to redirect rainwater.',
        'Plan an evacuation route that leads away from slopes and valleys.',
        'Register for NADMA and local civil defence alerts.',
      ],
    ),
    during: const _PhaseContent(
      title: 'During a Landslide',
      points: [
        'If you hear rumbling or see debris moving, evacuate immediately uphill or to stable ground.',
        'Move away from the path of the slide — never try to cross it.',
        'If indoors and escape is impossible, curl under a sturdy table and protect your head.',
        'Stay alert for secondary slides, which often follow the first.',
        'Avoid river valleys and low-lying areas where debris can funnel.',
      ],
    ),
    after: const _PhaseContent(
      title: 'After a Landslide',
      points: [
        'Stay away from the slide area — further slides are common.',
        'Check for injured or trapped neighbours and call 999 or BOMBA 994.',
        'Report broken utility lines (electricity, water, gas) to authorities.',
        'Watch for flooding, which may follow a landslide blocking a river.',
        'Document damage with photos and contact NADMA for relief assistance.',
      ],
    ),
    chatSuggestions: [
      'How to spot landslide warning signs?',
      'Is my area at risk?',
      'What to do if I see cracks?',
      'How to reinforce a slope?',
    ],
  ),
  'earthquake': _ModuleContent(
    heroTitle: 'Earthquake Response',
    heroSubtitle: 'Learn Drop, Cover, Hold On and post-quake safety.',
    icon: Icons.vibration,
    color: const Color(0xFFE65100),
    before: const _PhaseContent(
      title: 'Before an Earthquake',
      points: [
        'Secure heavy furniture, water heaters, and bookshelves to walls.',
        'Identify safe spots in every room: under sturdy tables, away from windows.',
        'Keep shoes and a torch beside your bed for nighttime quakes.',
        'Practice "Drop, Cover, Hold On" drills with your family regularly.',
        'Know how to shut off electricity, gas and water at mains.',
        'Store emergency supplies: water, food, medications, whistle, first aid.',
      ],
    ),
    during: const _PhaseContent(
      title: 'During an Earthquake',
      points: [
        'DROP to your hands and knees to prevent being knocked down.',
        'COVER your head and neck under a sturdy table or desk.',
        'HOLD ON to your shelter and be prepared to move with it.',
        'If no shelter is available, crouch against an interior wall and protect your head.',
        'Stay indoors until shaking stops — most injuries occur from falling debris when running.',
        'If outdoors, move to an open area away from buildings, trees and power lines.',
      ],
    ),
    after: const _PhaseContent(
      title: 'After an Earthquake',
      points: [
        'Expect aftershocks — drop, cover and hold on each time.',
        'Check yourself and others for injuries before moving.',
        'Exit buildings carefully — watch for broken glass and unstable structures.',
        'Do not use lifts. Do not re-enter damaged buildings.',
        'If you smell gas, leave immediately and call the fire department.',
        'Listen to official channels for instructions before returning home.',
      ],
    ),
    chatSuggestions: [
      'What is Drop Cover Hold On?',
      'How to earthquake-proof my home?',
      'What to do after an aftershock?',
      'Are tremors common in Malaysia?',
    ],
  ),
  'storm': _ModuleContent(
    heroTitle: 'Storm & Typhoon',
    heroSubtitle: 'Stay safe during tropical storms and monsoon surges.',
    icon: Icons.storm,
    color: const Color(0xFF37474F),
    before: const _PhaseContent(
      title: 'Before a Storm',
      points: [
        'Monitor MetMalaysia forecasts and NADMA warnings during monsoon season.',
        'Trim tree branches near your home and secure loose outdoor objects.',
        'Board up or shutter windows if a severe storm is expected.',
        'Stock up on water, food, batteries and charge all devices and power banks.',
        'Know the nearest public shelter and your evacuation route.',
        'Move vehicles to higher ground if flooding is expected.',
      ],
    ),
    during: const _PhaseContent(
      title: 'During a Storm',
      points: [
        'Stay indoors, away from windows and glass doors.',
        'Unplug electrical appliances to prevent damage from power surges.',
        'If power goes out, use torches — not candles — to prevent fire risk.',
        'Do not go outside to check on damage until the storm passes.',
        'Move to an interior room on the lowest floor if winds intensify.',
        'Listen to battery-powered radio or phone alerts for official updates.',
      ],
    ),
    after: const _PhaseContent(
      title: 'After a Storm',
      points: [
        'Avoid downed power lines and report them to TNB immediately.',
        'Watch for flooding and landslides in the hours after heavy rain.',
        'Check your home for structural damage before fully re-entering.',
        'Photograph damage for insurance and NADMA claims.',
        'Clear debris from drains to prevent secondary flooding.',
        'Check on neighbours and assist those in need.',
      ],
    ),
    chatSuggestions: [
      'How strong is monsoon wind?',
      'Should I board up windows?',
      'What if I lose power?',
      'When is monsoon season?',
    ],
  ),
  'tsunami': _ModuleContent(
    heroTitle: 'Tsunami Awareness',
    heroSubtitle: 'Recognise the signs and evacuate fast.',
    icon: Icons.waves,
    color: const Color(0xFF00838F),
    before: const _PhaseContent(
      title: 'Before a Tsunami',
      points: [
        'Learn the natural warning signs: strong earthquake near the coast, sudden sea withdrawal, unusual roaring sound.',
        'Know the tsunami evacuation routes and high-ground locations in your coastal area.',
        'If you live within 1 km of the coast, have a go-bag ready at all times.',
        'Register for national early-warning SMS and siren alerts.',
        'Practice evacuation drills with your family and community.',
      ],
    ),
    during: const _PhaseContent(
      title: 'During a Tsunami',
      points: [
        'Move immediately to high ground or inland — at least 30 metres elevation or 2 km from shore.',
        'Do not wait for official warnings if you feel a strong earthquake near the coast.',
        'Abandon belongings — your life is the priority.',
        'If caught in water, grab a floating object and try to stay on the surface.',
        'Do not return to the coast after the first wave — more waves may follow for hours.',
      ],
    ),
    after: const _PhaseContent(
      title: 'After a Tsunami',
      points: [
        'Stay away from the coast until authorities issue an all-clear.',
        'Avoid floodwater — it may contain debris, fuel and sewage.',
        'Help injured people and call emergency services (999).',
        'Do not enter damaged buildings.',
        'Document damage and contact NADMA for relief.',
      ],
    ),
    chatSuggestions: [
      'How fast does a tsunami travel?',
      'Where should I evacuate?',
      'Can Malaysia have a tsunami?',
      'What are the warning signs?',
    ],
  ),
  'haze': _ModuleContent(
    heroTitle: 'Haze & Air Quality',
    heroSubtitle: 'Protect your respiratory health during haze events.',
    icon: Icons.cloud,
    color: const Color(0xFF757575),
    before: const _PhaseContent(
      title: 'Before Haze Season',
      points: [
        'Keep a stock of N95 masks at home for each family member.',
        'Purchase an air purifier with HEPA filter for your main living room.',
        'Know the current Air Pollution Index (API) from DOE Malaysia site or app.',
        'Prepare medications if you or family members have asthma or respiratory conditions.',
        'Seal windows and doors to reduce particle entry when API rises.',
      ],
    ),
    during: const _PhaseContent(
      title: 'During Haze',
      points: [
        'Stay indoors as much as possible, especially when API > 200.',
        'Wear N95 mask when going outdoors — surgical masks are not effective.',
        'Reduce vigorous outdoor exercise and keep children inside during recess.',
        'Drink plenty of water to stay hydrated and soothe airways.',
        'Keep windows and doors closed; run the air purifier continuously.',
        'Seek medical help immediately if you experience breathing difficulty.',
      ],
    ),
    after: const _PhaseContent(
      title: 'After Haze Clears',
      points: [
        'Ventilate your home by opening windows once API drops below 50.',
        'Clean or replace air purifier filters and restock your N95 supply.',
        'Monitor your health — lingering coughs or tightness should be checked by a doctor.',
        'Clean surfaces that collected soot and dust.',
      ],
    ),
    chatSuggestions: [
      'What is a safe API level?',
      'N95 vs surgical mask?',
      'Is haze dangerous for children?',
      'When does haze season start?',
    ],
  ),
};

// ─────────────────────────────────────────────────────────────────────────────

enum _Sender { user, bot }

class _ChatMsg {
  final String text;
  final _Sender sender;
  _ChatMsg({required this.text, required this.sender});
}

class LearnModulePage extends StatefulWidget {
  final String hazardType;
  const LearnModulePage({super.key, required this.hazardType});

  @override
  State<LearnModulePage> createState() => _LearnModulePageState();
}

class _LearnModulePageState extends State<LearnModulePage>
    with SingleTickerProviderStateMixin {
  late final _ModuleContent _mod;
  late final TabController _tabCtrl;
  final _chatbot = ChatbotService();
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _msgs = [];
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _mod = _content[widget.hazardType] ?? _content['flood']!;
    _tabCtrl = TabController(length: 4, vsync: this);
    // Welcome message in chatbot tab
    _msgs.add(
      _ChatMsg(
        text:
            '👋 Hi! I\'m your **${_mod.heroTitle}** assistant. Ask me anything about ${widget.hazardType} safety, preparedness or response.',
        sender: _Sender.bot,
      ),
    );
  }

  String _tr({required String en, required String ms, String? zh}) {
    final lang = AppLanguageScope.of(context).language;
    if (lang == AppLanguage.malay) return ms;
    if (lang == AppLanguage.chinese) return zh ?? en;
    return en;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _textCtrl.clear();
    setState(() {
      _msgs.add(_ChatMsg(text: trimmed, sender: _Sender.user));
      _typing = true;
    });
    _scrollDown();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final reply = _chatbot.getResponse(trimmed);
      setState(() {
        _msgs.add(_ChatMsg(text: reply, sender: _Sender.bot));
        _typing = false;
      });
      _scrollDown();
    });
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final barBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final divColor = isDark
        ? const Color(0xFF334236)
        : const Color(0xFF2D5927).withAlpha(26);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: barBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _mod.heroTitle,
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(height: 1, color: divColor),
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                labelColor: _mod.color,
                unselectedLabelColor: isDark
                    ? const Color(0xFF9AA79B)
                    : Colors.grey,
                indicatorColor: _mod.color,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Before'),
                  Tab(text: 'During'),
                  Tab(text: 'After'),
                  Tab(text: 'Ask AI'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildPhaseTab(_mod.before, isDark),
          _buildPhaseTab(_mod.during, isDark),
          _buildPhaseTab(_mod.after, isDark),
          _buildChatTab(isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuizPage(
              hazardType: widget.hazardType,
              hazardTitle: _mod.heroTitle,
              themeColor: _mod.color,
            ),
          ),
        ),
        backgroundColor: _mod.color,
        icon: const Icon(Icons.quiz_rounded, color: Colors.white),
        label: Text(
          _tr(en: 'Take Quiz', ms: 'Ambil Kuiz', zh: '参加测验'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─── Educational Content Tab ────────────────────────────────────────────

  Widget _buildPhaseTab(_PhaseContent phase, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);
    final bodyColor = isDark
        ? const Color(0xFFCCD3CD)
        : const Color(0xFF374151);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Phase header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _mod.color.withAlpha(isDark ? 30 : 15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(_mod.icon, color: _mod.color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  phase.title,
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Points
        ...phase.points.asMap().entries.map((entry) {
          final idx = entry.key;
          final point = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _mod.color.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        color: _mod.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        // CTA to chatbot
        GestureDetector(
          onTap: () => _tabCtrl.animateTo(3),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _mod.color.withAlpha(isDark ? 30 : 12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _mod.color.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.smart_toy_rounded, color: _mod.color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Have questions? Ask the AI assistant →',
                    style: TextStyle(
                      color: _mod.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Chatbot Tab ────────────────────────────────────────────────────────

  Widget _buildChatTab(bool isDark) {
    final inputBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final hintColor = isDark
        ? const Color(0xFF6B7C6B)
        : const Color(0xFF94A3B8);

    return Column(
      children: [
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            itemCount: _msgs.length + (_typing ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _msgs.length) return _buildTypingBubble(isDark);
              return _buildBubble(_msgs[i], isDark);
            },
          ),
        ),
        // Suggestions (show when only welcome message)
        if (_msgs.length == 1) _buildSuggestions(isDark),
        // Input bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          color: inputBg,
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    onSubmitted: _send,
                    textInputAction: TextInputAction.send,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask about ${widget.hazardType} safety…',
                      hintStyle: TextStyle(color: hintColor, fontSize: 14),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF263226)
                          : const Color(0xFFF1F5F1),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_textCtrl.text),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _mod.color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(_ChatMsg msg, bool isDark) {
    final isUser = msg.sender == _Sender.user;
    final bubbleBg = isUser
        ? _mod.color
        : (isDark ? const Color(0xFF1B251B) : const Color(0xFFF1F5F1));
    final textColor = isUser
        ? Colors.white
        : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1E293B));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: _buildRichText(msg.text, textColor),
      ),
    );
  }

  Widget _buildRichText(String text, Color baseColor) {
    final spans = <TextSpan>[];
    final boldRe = RegExp(r'\*\*(.+?)\*\*');
    int start = 0;
    for (final m in boldRe.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: baseColor, fontSize: 14, height: 1.5),
        children: spans,
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B251B) : const Color(0xFFF1F5F1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: SizedBox(
          width: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (i) => _Dot(delay: i * 150, color: _mod.color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(bool isDark) {
    final chipBg = isDark ? _mod.color.withAlpha(30) : _mod.color.withAlpha(15);
    final chipText = _mod.color;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: _mod.chatSuggestions.length,
        itemBuilder: (ctx, i) => ActionChip(
          label: Text(
            _mod.chatSuggestions[i],
            style: TextStyle(
              fontSize: 12,
              color: chipText,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: chipBg,
          side: BorderSide(color: _mod.color.withAlpha(60)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onPressed: () => _send(_mod.chatSuggestions[i]),
        ),
      ),
    );
  }
}

// ─── Animated typing dot ─────────────────────────────────────────────────────

class _Dot extends StatefulWidget {
  final int delay;
  final Color color;
  const _Dot({required this.delay, required this.color});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) =>
          Opacity(opacity: 0.3 + 0.7 * _anim.value, child: child),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
