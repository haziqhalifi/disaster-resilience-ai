import 'dart:async';

import 'package:flutter/material.dart';

import 'package:disaster_resilience_ai/models/family_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

class FamilyTab extends StatefulWidget {
  const FamilyTab({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<FamilyTab> createState() => _FamilyTabState();
}

class _FamilyTabState extends State<FamilyTab> {
  final ApiService _api = ApiService();
  final TextEditingController _identifierController = TextEditingController();

  bool _loading = true;
  bool _sendingInvite = false;
  String? _error;
  List<FamilyInvite> _invites = [];
  List<FamilyMemberLocation> _members = [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadData(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final invitesData = await _api.fetchFamilyInvites(
        accessToken: widget.accessToken,
      );
      final membersData = await _api.fetchFamilyLocations(
        accessToken: widget.accessToken,
      );

      final invitesJson = (invitesData['invites'] as List<dynamic>? ?? []);
      final membersJson = (membersData['members'] as List<dynamic>? ?? []);

      if (!mounted) return;
      setState(() {
        _invites = invitesJson
            .map((e) => FamilyInvite.fromJson(e as Map<String, dynamic>))
            .toList();
        _members = membersJson
            .map(
              (e) => FamilyMemberLocation.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendInvite() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return;

    setState(() {
      _sendingInvite = true;
      _error = null;
    });

    try {
      await _api.inviteFamilyMember(
        accessToken: widget.accessToken,
        identifier: identifier,
      );
      _identifierController.clear();
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _sendingInvite = false);
      }
    }
  }

  Future<void> _respondInvite(String inviteId, bool accept) async {
    try {
      await _api.respondFamilyInvite(
        accessToken: widget.accessToken,
        inviteId: inviteId,
        accept: accept,
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Never';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Family Live Location',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Invite family by username or email, then view their latest location updates.',
            style: TextStyle(color: Color(0xFF475569)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Family Member',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _identifierController,
                  decoration: const InputDecoration(
                    hintText: 'username or email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sendingInvite ? null : _sendInvite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_sendingInvite ? 'Sending...' : 'Send Invite'),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          const Text(
            'Pending Invites',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_invites.isEmpty)
            const Text('No pending invites.')
          else
            ..._invites.map(
              (invite) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invite.requesterUsername,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(invite.requesterEmail),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _respondInvite(invite.id, false),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _respondInvite(invite.id, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Family Members',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const SizedBox.shrink()
          else if (_members.isEmpty)
            const Text('No family members connected yet.')
          else
            ..._members.map(
              (member) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE8F5E9),
                    child: Text(
                      member.username.isNotEmpty
                          ? member.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(color: Color(0xFF2E7D32)),
                    ),
                  ),
                  title: Text(member.username),
                  subtitle: Text(
                    member.hasLocation
                        ? '${member.latitude!.toStringAsFixed(5)}, ${member.longitude!.toStringAsFixed(5)}\nUpdated ${_timeAgo(member.updatedAt)}'
                        : 'Location not available yet',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
