import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisasterChecklistPage extends StatefulWidget {
  const DisasterChecklistPage({super.key});

  @override
  State<DisasterChecklistPage> createState() => _DisasterChecklistPageState();
}

class _ChecklistItem {
  final String id;
  final String title;
  final String subtitle;
  bool isDone;

  _ChecklistItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

class _DisasterChecklistPageState extends State<DisasterChecklistPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SharedPreferences _prefs;
  bool _loaded = false;

  final List<_ChecklistItem> _beforeItems = [
    _ChecklistItem(
      id: 'b1',
      title: 'Prepare emergency kit',
      subtitle: 'Water, food, torch, first aid, medications (3-day supply)',
    ),
    _ChecklistItem(
      id: 'b2',
      title: 'Store important documents',
      subtitle:
          'IC, passport copies, insurance & bank details in waterproof bag',
    ),
    _ChecklistItem(
      id: 'b3',
      title: 'Know your evacuation route',
      subtitle: 'Identify shelter locations and two exit routes from home',
    ),
    _ChecklistItem(
      id: 'b4',
      title: 'Charge backup power banks',
      subtitle: 'Keep at least one fully charged power bank at home',
    ),
    _ChecklistItem(
      id: 'b5',
      title: 'Save emergency contacts',
      subtitle: 'BOMBA 994, Civil Defence 991, Police 999, nearest hospital',
    ),
    _ChecklistItem(
      id: 'b6',
      title: 'Secure your home',
      subtitle: 'Move valuables upstairs, unplug appliances, close gas valves',
    ),
    _ChecklistItem(
      id: 'b7',
      title: 'Notify family members',
      subtitle: 'Share your plan and meeting point with all household members',
    ),
  ];

  final List<_ChecklistItem> _duringItems = [
    _ChecklistItem(
      id: 'd1',
      title: 'Stay calm and follow official instructions',
      subtitle: 'Monitor alerts from NADMA, Bernama and local authorities',
    ),
    _ChecklistItem(
      id: 'd2',
      title: 'Move to higher ground immediately',
      subtitle: 'Do not wait — leave as soon as evacuation order is given',
    ),
    _ChecklistItem(
      id: 'd3',
      title: 'Avoid floodwater or debris',
      subtitle: 'Even shallow moving water can knock you off your feet',
    ),
    _ChecklistItem(
      id: 'd4',
      title: 'Turn off utilities at main switches',
      subtitle: 'Electricity, gas and water if safe to do so',
    ),
    _ChecklistItem(
      id: 'd5',
      title: 'Take your emergency kit',
      subtitle: 'Grab your go-bag before leaving the house',
    ),
    _ChecklistItem(
      id: 'd6',
      title: 'Check on neighbours',
      subtitle: 'Especially elderly, disabled or families with young children',
    ),
    _ChecklistItem(
      id: 'd7',
      title: 'Stay off roads unless evacuating',
      subtitle: 'Roads may be blocked, washed out or flooded',
    ),
  ];

  final List<_ChecklistItem> _afterItems = [
    _ChecklistItem(
      id: 'a1',
      title: 'Wait for all-clear from authorities',
      subtitle: 'Do not return home until officially declared safe',
    ),
    _ChecklistItem(
      id: 'a2',
      title: 'Document damage with photos',
      subtitle: 'For insurance claims and disaster relief applications',
    ),
    _ChecklistItem(
      id: 'a3',
      title: 'Check for structural damage',
      subtitle: 'Inspect walls, roof and foundation before re-entering',
    ),
    _ChecklistItem(
      id: 'a4',
      title: 'Avoid contaminated water',
      subtitle: 'Boil or use bottled water until supply is confirmed safe',
    ),
    _ChecklistItem(
      id: 'a5',
      title: 'Clean and disinfect affected areas',
      subtitle: 'Use gloves and masks when handling flood-damaged items',
    ),
    _ChecklistItem(
      id: 'a6',
      title: 'Seek medical attention if needed',
      subtitle:
          'Injuries, stress or waterborne illness should be treated early',
    ),
    _ChecklistItem(
      id: 'a7',
      title: 'Replenish your emergency kit',
      subtitle: 'Replace used supplies and update documents',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();
    final allItems = [..._beforeItems, ..._duringItems, ..._afterItems];
    for (final item in allItems) {
      item.isDone = _prefs.getBool('checklist_${item.id}') ?? false;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _toggle(_ChecklistItem item) async {
    setState(() => item.isDone = !item.isDone);
    await _prefs.setBool('checklist_${item.id}', item.isDone);
  }

  int _doneCount(List<_ChecklistItem> items) =>
      items.where((i) => i.isDone).length;

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
          'Disaster Checklist',
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
                controller: _tabController,
                labelColor: const Color(0xFF2E7D32),
                unselectedLabelColor: isDark
                    ? const Color(0xFF9AA79B)
                    : Colors.grey,
                indicatorColor: const Color(0xFF2E7D32),
                tabs: const [
                  Tab(text: 'Before'),
                  Tab(text: 'During'),
                  Tab(text: 'After'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_beforeItems, isDark),
                _buildList(_duringItems, isDark),
                _buildList(_afterItems, isDark),
              ],
            ),
    );
  }

  Widget _buildList(List<_ChecklistItem> items, bool isDark) {
    final done = _doneCount(items);
    final total = items.length;
    final cardBg = isDark ? const Color(0xFF1B251B) : Colors.white;
    final subtitleColor = isDark ? const Color(0xFF9AA79B) : Colors.grey[600]!;
    final titleColor = isDark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1E293B);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$done of $total completed',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(done / total * 100).round()}%',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? const Color(0xFF2D5927).withAlpha(50)
                      : const Color(0xFFE8F5E9),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...items.map(
          (item) => _buildItem(item, cardBg, titleColor, subtitleColor),
        ),
      ],
    );
  }

  Widget _buildItem(
    _ChecklistItem item,
    Color cardBg,
    Color titleColor,
    Color subtitleColor,
  ) {
    return GestureDetector(
      onTap: () => _toggle(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isDone
                ? const Color(0xFF2E7D32).withAlpha(80)
                : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: item.isDone ? const Color(0xFF2E7D32) : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: item.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
