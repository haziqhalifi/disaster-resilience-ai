import 'dart:async';
import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:geolocator/geolocator.dart';

class FamilyCheckinPage extends StatefulWidget {
  const FamilyCheckinPage({super.key, required this.accessToken});
  final String accessToken;
  @override
  State<FamilyCheckinPage> createState() => _FamilyCheckinPageState();
}

class _FamilyCheckinPageState extends State<FamilyCheckinPage> {
  final ApiService _api = ApiService();

  bool _loading = true;
  List<dynamic> _groups = [];
  String? _error;
  List<dynamic> _nearbyFloods = [];
  Timer? _refreshTimer;

  // Controllers for create/edit
  final _groupNameCtrl = TextEditingController();
  final _memberNameCtrl = TextEditingController();
  final _memberPhoneCtrl = TextEditingController();
  final _memberRelCtrl = TextEditingController();
  List<Map<String, String>> _pendingMembers = [];

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh every 15 s so SMS replies (SAFE/DANGER) appear without manual pull-to-refresh
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _groupNameCtrl.dispose();
    _memberNameCtrl.dispose();
    _memberPhoneCtrl.dispose();
    _memberRelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final groups = await _api.fetchFamilyGroups(widget.accessToken);
      if (mounted) setState(() { _groups = groups; _loading = false; });
    } catch (e) {
      if (mounted && !silent) setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
    _loadNearbyFloods();
  }

  Future<void> _loadNearbyFloods() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      final result = await _api.fetchNearbyReports(
        accessToken: widget.accessToken,
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusKm: 10.0,
        statusFilter: 'validated',
      );
      final reports = (result['reports'] as List<dynamic>? ?? []);
      final floods = reports.where((r) => (r as Map)['report_type'] == 'flood').toList();
      if (mounted) setState(() { _nearbyFloods = floods; });
    } catch (_) {
      // Silently ignore — flood banner is best-effort
    }
  }

  // ─── Snack helpers ──────────────────────────────────────────────────────────

  void _snack(String msg, {Color color = Colors.green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Check-in ───────────────────────────────────────────────────────────────

  Future<void> _checkin(String memberId, String status) async {
    try {
      await _api.familyCheckin(accessToken: widget.accessToken, memberId: memberId, status: status);
      _snack('Status updated to ${status.replaceAll('_', ' ').toUpperCase()}',
          color: _statusColor(status));
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), color: Colors.red);
    }
  }

  // ─── Create Group ───────────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    final name = _groupNameCtrl.text.trim();
    if (name.isEmpty) { _snack('Enter a group name', color: Colors.orange); return; }
    if (_pendingMembers.isEmpty) {
      _snack('Add at least one member before creating', color: Colors.orange);
      return;
    }
    try {
      await _api.createFamilyGroup(
        accessToken: widget.accessToken,
        name: name,
        members: List<Map<String, String>>.from(_pendingMembers),
      );
      _snack('Family group created!');
      _groupNameCtrl.clear(); _memberNameCtrl.clear();
      _memberPhoneCtrl.clear(); _memberRelCtrl.clear();
      _pendingMembers = [];
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), color: Colors.red);
    }
  }

  // ─── Delete Group ───────────────────────────────────────────────────────────

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Family Group'),
        content: Text('Delete "${group['name']}" and all its members? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteFamilyGroup(accessToken: widget.accessToken, groupId: group['id'] as String);
      _snack('Family group deleted');
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), color: Colors.red);
    }
  }

  // ─── Rename Group ────────────────────────────────────────────────────────────

  Future<void> _renameGroup(Map<String, dynamic> group) async {
    final ctrl = TextEditingController(text: group['name'] as String);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rename', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (newName == null || newName.isEmpty) return;
    try {
      await _api.renameFamilyGroup(
          accessToken: widget.accessToken, groupId: group['id'] as String, name: newName);
      _snack('Group renamed to "$newName"');
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), color: Colors.red);
    }
  }

  // ─── Add Member to existing group ───────────────────────────────────────────

  Future<void> _showAddMemberDialog(String groupId) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Name *')),
          const SizedBox(height: 8),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)')),
          const SizedBox(height: 8),
          TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final n = nameCtrl.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _api.addFamilyMember(
                  accessToken: widget.accessToken, groupId: groupId,
                  name: n, phoneNumber: phoneCtrl.text.trim(), relationship: relCtrl.text.trim(),
                );
                _snack('Member added!');
                _load();
              } catch (e) { _snack(e.toString().replaceFirst('Exception: ', ''), color: Colors.red); }
            },
            child: const Text('Add', style: TextStyle(color: Color(0xFF2E7D32))),
          ),
        ],
      ),
    );
    nameCtrl.dispose(); phoneCtrl.dispose(); relCtrl.dispose();
  }

  // ─── Delete Member ───────────────────────────────────────────────────────────

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove "${member['name']}" from this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteFamilyMember(
          accessToken: widget.accessToken, memberId: member['id'] as String);
      _snack('Member removed');
      _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), color: Colors.red);
    }
  }

  // ─── Create group dialog ─────────────────────────────────────────────────────

  void _showCreateGroupDialog() {
    setState(() {
      _pendingMembers = [];
      _groupNameCtrl.clear(); _memberNameCtrl.clear();
      _memberPhoneCtrl.clear(); _memberRelCtrl.clear();
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                const Icon(Icons.family_restroom, color: Color(0xFF2E7D32), size: 24),
                const SizedBox(width: 8),
                const Text('Create Family Group',
                    style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
              const SizedBox(height: 16),

              // Group name
              TextField(
                controller: _groupNameCtrl,
                decoration: _inputDecoration('Group name (e.g. My Family)'),
              ),
              const SizedBox(height: 16),

              // Add members section
              const Text('Add Members',
                  style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              const Text('At least 1 member required',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(controller: _memberNameCtrl, decoration: _inputDecoration('Name *'))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _memberPhoneCtrl,
                    keyboardType: TextInputType.phone, decoration: _inputDecoration('Phone'))),
                const SizedBox(width: 6),
                Expanded(child: TextField(controller: _memberRelCtrl, decoration: _inputDecoration('Relation'))),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF2E7D32), size: 32),
                  onPressed: () {
                    final n = _memberNameCtrl.text.trim();
                    if (n.isEmpty) return;
                    setModalState(() {
                      _pendingMembers.add({
                        'name': n,
                        'phone_number': _memberPhoneCtrl.text.trim(),
                        'relationship': _memberRelCtrl.text.trim(),
                      });
                      _memberNameCtrl.clear(); _memberPhoneCtrl.clear(); _memberRelCtrl.clear();
                    });
                  },
                ),
              ]),

              // Pending member list
              if (_pendingMembers.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._pendingMembers.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '${e.value['name']!}${e.value['relationship']!.isNotEmpty ? ' (${e.value['relationship']!})' : ''}',
                      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
                    )),
                    GestureDetector(
                      onTap: () => setModalState(() => _pendingMembers.removeAt(e.key)),
                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ]),
                )),
              ],

              if (_pendingMembers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Add at least one family member', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ]),
                  ),
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _pendingMembers.isEmpty ? null : () async {
                    Navigator.pop(ctx);
                    await _createGroup();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Create Group',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Family Check-in',
            style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF2E7D32)),
            onPressed: _showCreateGroupDialog,
            tooltip: 'Create group',
          ),
        ],
      ),
      body: Column(children: [
        if (_nearbyFloods.isNotEmpty) _buildFloodBanner(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
              : _error != null
                  ? _buildError()
                  : _groups.isEmpty
                      ? _buildEmpty()
                      : _buildGroupList(),
        ),
      ]),
    );
  }

  Widget _buildFloodBanner() {
    final flood = _nearbyFloods.first as Map<String, dynamic>;
    final locationName = flood['location_name'] as String? ?? 'nearby area';
    final distKm = flood['distance_km'] as num?;
    final distText = distKm != null ? ' (${distKm.toStringAsFixed(1)} km away)' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.red.shade50,
      child: Row(children: [
        const Icon(Icons.water_damage, color: Colors.red, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('FLOOD ZONE WARNING',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
          Text(
            'Flood confirmed near $locationName$distText',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ])),
        if (_nearbyFloods.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${_nearbyFloods.length}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
      ]),
    );
  }

  Widget _buildError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _load,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
          child: const Text('Retry', style: TextStyle(color: Colors.white)),
        ),
      ]),
    ));
  }

  Widget _buildEmpty() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
          child: const Icon(Icons.family_restroom, size: 64, color: Color(0xFF2E7D32)),
        ),
        const SizedBox(height: 24),
        const Text('No Family Groups Yet',
            style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text(
          "Create a family group to track your loved ones' safety status during disasters.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _showCreateGroupDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Create Family Group',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ]),
    ));
  }

  Widget _buildGroupList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF2E7D32),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        itemBuilder: (_, i) => _buildGroupCard(_groups[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final members = (group['members'] as List<dynamic>?) ?? [];
    final groupName = group['name'] as String? ?? 'Family';
    final safeCount = members.where((m) => m['safety_status'] == 'safe').length;
    final helpCount = members.where((m) => m['safety_status'] == 'needs_help').length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // ── Group header with edit/delete ──────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.family_restroom, color: Color(0xFF2E7D32), size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(groupName,
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 15)),
              Text(
                '${members.length} member${members.length != 1 ? 's' : ''}'
                ' • $safeCount safe'
                '${helpCount > 0 ? ' • $helpCount in danger' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ])),
            // Add member button
            IconButton(
              icon: const Icon(Icons.person_add_outlined, color: Color(0xFF2E7D32), size: 20),
              tooltip: 'Add member',
              onPressed: () => _showAddMemberDialog(group['id'] as String),
              visualDensity: VisualDensity.compact,
            ),
            // 3-dot menu for rename/delete
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
              onSelected: (val) {
                if (val == 'rename') _renameGroup(group);
                if (val == 'delete') _deleteGroup(group);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Row(children: [
                  Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2E7D32)),
                  SizedBox(width: 8), Text('Rename'),
                ])),
                const PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 8), Text('Delete Group', style: TextStyle(color: Colors.red)),
                ])),
              ],
            ),
          ]),
        ),

        // ── Members list ───────────────────────────────────────────────────
        if (members.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              const Expanded(child: Text('No members added yet. Tap + to add one.',
                  style: TextStyle(color: Colors.grey, fontSize: 13))),
            ]),
          )
        else
          ...members.map((m) => _buildMemberRow(m as Map<String, dynamic>)),
      ]),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member) {
    final name = member['name'] as String? ?? '';
    final relationship = member['relationship'] as String? ?? '';
    final status = member['safety_status'] as String? ?? 'unknown';
    final memberId = member['id'] as String;

    return Dismissible(
      key: ValueKey(memberId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.shade50,
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        await _deleteMember(member);
        return false; // We reload, so don't auto-remove from list
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
        ),
        child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14)),
            Row(children: [
              Text(_statusLabel(status),
                  style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
              if (relationship.isNotEmpty) ...[
                const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text(relationship, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ]),
          ])),
          // Status buttons
          _statusBtn(memberId, 'safe', Icons.check_circle_outline, Colors.green),
          const SizedBox(width: 4),
          _statusBtn(memberId, 'needs_help', Icons.warning_amber_rounded, Colors.red),
          const SizedBox(width: 4),
          _statusBtn(memberId, 'unknown', Icons.help_outline, Colors.grey),
          const SizedBox(width: 4),
          // Delete button
          GestureDetector(
            onTap: () => _deleteMember(member),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 18),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statusBtn(String memberId, String status, IconData icon, Color color) {
    return GestureDetector(
      onTap: () => _checkin(memberId, status),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration:
            BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'safe': return Colors.green;
      case 'needs_help': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'safe': return 'Safe';
      case 'needs_help': return 'Danger';
      default: return 'Unknown';
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF4CAF50))),
    );
  }
}
