import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';

/// Admin page for managing and triggering IoT community sirens.
class SirenManagementPage extends StatefulWidget {
  const SirenManagementPage({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<SirenManagementPage> createState() => _SirenManagementPageState();
}

class _SirenManagementPageState extends State<SirenManagementPage> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _sirens = [];
  bool _loading = true;
  String? _error;

  bool get _isMalay =>
      AppLanguageScope.of(context).language == AppLanguage.malay;
  bool get _isChinese =>
      AppLanguageScope.of(context).language == AppLanguage.chinese;

  String _tr({required String en, required String ms, String? zh}) {
    if (_isMalay) return ms;
    if (_isChinese) return zh ?? en;
    return en;
  }

  @override
  void initState() {
    super.initState();
    _fetchSirens();
  }

  Future<void> _fetchSirens() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchSirens();
      if (mounted) {
        setState(() {
          _sirens = data.cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _triggerSiren(Map<String, dynamic> siren) async {
    try {
      await _api.triggerSiren(
        accessToken: widget.accessToken,
        sirenId: siren['id'] as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                en: 'Siren "${siren['name']}" triggered',
                ms: 'Siren "${siren['name']}" diaktifkan',
                zh: '警报器 "${siren['name']}" 已触发',
              ),
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
      _fetchSirens();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _stopSiren(Map<String, dynamic> siren) async {
    try {
      await _api.stopSiren(
        accessToken: widget.accessToken,
        sirenId: siren['id'] as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                en: 'Siren "${siren['name']}" stopped',
                ms: 'Siren "${siren['name']}" dihentikan',
                zh: '警报器 "${siren['name']}" 已停止',
              ),
            ),
          ),
        );
      }
      _fetchSirens();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showRegisterDialog() {
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lonCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '5.0');
    final endpointCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _tr(en: 'Register New Siren', ms: 'Daftar Siren Baru', zh: '注册新警报器'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: _tr(
                    en: 'Name / Location',
                    ms: 'Nama / Lokasi',
                    zh: '名称/位置',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: radiusCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _tr(
                    en: 'Radius (km)',
                    ms: 'Radius (km)',
                    zh: '半径 (km)',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: endpointCtrl,
                decoration: InputDecoration(
                  labelText: _tr(
                    en: 'IoT Endpoint URL (optional)',
                    ms: 'URL Endpoint IoT (pilihan)',
                    zh: 'IoT端点URL (可选)',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_tr(en: 'Cancel', ms: 'Batal', zh: '取消')),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final lat = double.tryParse(latCtrl.text.trim());
              final lon = double.tryParse(lonCtrl.text.trim());
              final radius = double.tryParse(radiusCtrl.text.trim()) ?? 5.0;
              if (name.isEmpty || lat == null || lon == null) return;

              Navigator.pop(ctx);
              try {
                await _api.registerSiren(
                  accessToken: widget.accessToken,
                  name: name,
                  latitude: lat,
                  longitude: lon,
                  radiusKm: radius,
                  endpointUrl: endpointCtrl.text.trim().isNotEmpty
                      ? endpointCtrl.text.trim()
                      : null,
                );
                _fetchSirens();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Text(_tr(en: 'Register', ms: 'Daftar', zh: '注册')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _tr(
            en: 'IoT Siren Management',
            ms: 'Pengurusan Siren IoT',
            zh: 'IoT警报器管理',
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRegisterDialog,
        icon: const Icon(Icons.add),
        label: Text(_tr(en: 'Add Siren', ms: 'Tambah Siren', zh: '添加警报器')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _fetchSirens,
                    child: Text(_tr(en: 'Retry', ms: 'Cuba lagi', zh: '重试')),
                  ),
                ],
              ),
            )
          : _sirens.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.speaker_outlined,
                    size: 64,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tr(
                      en: 'No sirens registered yet',
                      ms: 'Tiada siren didaftarkan lagi',
                      zh: '尚未注册警报器',
                    ),
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      en: 'Tap + to register a community siren',
                      ms: 'Tekan + untuk mendaftar siren komuniti',
                      zh: '点击 + 注册社区警报器',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchSirens,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: _sirens.length,
                itemBuilder: (_, i) => _buildSirenCard(_sirens[i], isDark),
              ),
            ),
    );
  }

  Widget _buildSirenCard(Map<String, dynamic> siren, bool isDark) {
    final sirenStatus = siren['status'] as String? ?? 'idle';
    final isActive = sirenStatus == 'active';
    final isOffline = sirenStatus == 'offline' || sirenStatus == 'maintenance';

    final Color statusColor;
    final IconData statusIcon;
    switch (sirenStatus) {
      case 'active':
        statusColor = const Color(0xFFDC2626);
        statusIcon = Icons.campaign_rounded;
        break;
      case 'offline':
        statusColor = const Color(0xFF6B7280);
        statusIcon = Icons.cloud_off_rounded;
        break;
      case 'maintenance':
        statusColor = const Color(0xFFD97706);
        statusIcon = Icons.build_circle_rounded;
        break;
      default: // idle
        statusColor = const Color(0xFF16A34A);
        statusIcon = Icons.check_circle_rounded;
    }

    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334236)
        : statusColor.withAlpha(40);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  siren['name'] as String? ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sirenStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${(siren['latitude'] as num?)?.toStringAsFixed(4) ?? '-'}°N, '
            '${(siren['longitude'] as num?)?.toStringAsFixed(4) ?? '-'}°E  •  '
            '${(siren['radius_km'] as num?)?.toStringAsFixed(1) ?? '5.0'} km radius',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
            ),
          ),
          if (siren['endpoint_url'] != null &&
              (siren['endpoint_url'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _tr(
                      en: 'IoT endpoint configured',
                      ms: 'Endpoint IoT dikonfigurasi',
                      zh: 'IoT端点已配置',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!isActive && !isOffline)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _triggerSiren(siren),
                    icon: const Icon(Icons.campaign_rounded, size: 18),
                    label: Text(_tr(en: 'Trigger', ms: 'Aktifkan', zh: '触发')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  ),
                ),
              if (isActive) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _stopSiren(siren),
                    icon: const Icon(Icons.stop_circle_rounded, size: 18),
                    label: Text(_tr(en: 'Stop', ms: 'Hentikan', zh: '停止')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
              if (isOffline) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _api.updateSirenStatus(
                        accessToken: widget.accessToken,
                        sirenId: siren['id'] as String,
                        status: 'idle',
                      );
                      _fetchSirens();
                    },
                    icon: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _tr(en: 'Bring Online', ms: 'Aktifkan Semula', zh: '上线'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
