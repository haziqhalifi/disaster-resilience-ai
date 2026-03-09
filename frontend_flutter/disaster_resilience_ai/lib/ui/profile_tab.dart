import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/models/profile_model.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/theme/app_theme.dart';
import 'package:disaster_resilience_ai/ui/edit_profile_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({
    super.key,
    required this.accessToken,
    required this.username,
    required this.email,
    required this.onLogout,
  });

  final String accessToken;
  final String username;
  final String email;
  final VoidCallback onLogout;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final ApiService _api = ApiService();
  UserProfile? _profile;
  bool _loading = true;
  String? _error;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _selectLanguage() async {
    final languageController = AppLanguageScope.of(context);
    final selectedLanguage = languageController.label;
    final currentLanguage = languageController.language;
    String tr({required String en, required String ms, required String zh}) {
      return switch (currentLanguage) {
        AppLanguage.english => en,
        AppLanguage.malay => ms,
        AppLanguage.chinese => zh,
      };
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final subtitleColor = isDark
            ? const Color(0xFFA7B5A8)
            : const Color(0xFF64748B);
        final checkColor = isDark
            ? const Color(0xFFD1D5DB)
            : const Color(0xFF475569);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  tr(en: 'Choose Language', ms: 'Pilih Bahasa', zh: '选择语言'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                title: const Text('English'),
                subtitle: Text(
                  tr(
                    en: 'Use English across the app',
                    ms: 'Guna bahasa Inggeris dalam aplikasi',
                    zh: '在整个应用中使用英语',
                  ),
                  style: TextStyle(color: subtitleColor),
                ),
                trailing: selectedLanguage == 'English'
                    ? Icon(Icons.check, color: checkColor)
                    : null,
                onTap: () => Navigator.pop(context, 'English'),
              ),
              ListTile(
                title: const Text('Bahasa Melayu'),
                subtitle: Text(
                  tr(
                    en: 'Use Bahasa Melayu across the app',
                    ms: 'Guna Bahasa Melayu dalam aplikasi',
                    zh: '在整个应用中使用马来语',
                  ),
                  style: TextStyle(color: subtitleColor),
                ),
                trailing: selectedLanguage == 'Bahasa Melayu'
                    ? Icon(Icons.check, color: checkColor)
                    : null,
                onTap: () => Navigator.pop(context, 'Bahasa Melayu'),
              ),
              ListTile(
                title: const Text('Chinese (Mandarin)'),
                subtitle: Text(
                  tr(
                    en: 'Use Mandarin Chinese across the app',
                    ms: 'Guna Bahasa Cina Mandarin dalam aplikasi',
                    zh: '在整个应用中使用普通话',
                  ),
                  style: TextStyle(color: subtitleColor),
                ),
                trailing: selectedLanguage == 'Chinese (Mandarin)'
                    ? Icon(Icons.check, color: checkColor)
                    : null,
                onTap: () => Navigator.pop(context, 'Chinese (Mandarin)'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == selectedLanguage) return;
    if (selected == 'Bahasa Melayu') {
      await languageController.setLanguage(AppLanguage.malay);
      return;
    }
    if (selected == 'Chinese (Mandarin)') {
      await languageController.setLanguage(AppLanguage.chinese);
      return;
    }
    await languageController.setLanguage(AppLanguage.english);
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _api.fetchProfile(widget.accessToken);
      if (mounted) {
        setState(() {
          _profile = UserProfile.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          accessToken: widget.accessToken,
          profile: _profile ?? UserProfile(userId: ''),
        ),
      ),
    );

    if (result == true) {
      _fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primary = Color(0xFF2D5927);
    final theme = Theme.of(context);
    final themeController = AppThemeScope.of(context);
    final languageController = AppLanguageScope.of(context);
    final language = languageController.language;
    String tr({required String en, required String ms, required String zh}) {
      return switch (language) {
        AppLanguage.english => en,
        AppLanguage.malay => ms,
        AppLanguage.chinese => zh,
      };
    }

    final isDark = theme.brightness == Brightness.dark;
    final pageBg = theme.scaffoldBackgroundColor;
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final subtleSurface = isDark
        ? const Color(0xFF233124)
        : const Color(0xFFF1F5F9);
    final border = isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final secondaryText = isDark
        ? const Color(0xFFA7B5A8)
        : const Color(0xFF64748B);
    final tertiaryText = isDark
        ? const Color(0xFF8A9A8B)
        : const Color(0xFF94A3B8);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              tr(
                en: 'Error loading profile: $_error',
                ms: 'Ralat memuatkan profil: $_error',
                zh: '加载个人资料出错：$_error',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchProfile,
              child: Text(tr(en: 'Retry', ms: 'Cuba Lagi', zh: '重试')),
            ),
          ],
        ),
      );
    }

    final profile = _profile!;
    final hasEmergencyContact =
        (profile.emergencyContactName?.trim().isNotEmpty ?? false) ||
        (profile.emergencyContactPhone?.trim().isNotEmpty ?? false) ||
        (profile.emergencyContactRelationship?.trim().isNotEmpty ?? false);
    final displayName = profile.fullName?.isNotEmpty == true
        ? profile.fullName!
        : widget.username;
    final emergencyName = hasEmergencyContact
        ? ((profile.emergencyContactName?.trim().isNotEmpty ?? false)
              ? profile.emergencyContactName!
              : tr(
                  en: 'Emergency Contact',
                  ms: 'Kenalan Kecemasan',
                  zh: '紧急联系人',
                ))
        : tr(en: 'Not Set', ms: 'Belum Ditetapkan', zh: '未设置');
    final emergencyLabel = [
      if (profile.emergencyContactRelationship?.isNotEmpty == true)
        profile.emergencyContactRelationship!,
      if (profile.emergencyContactPhone?.isNotEmpty == true)
        profile.emergencyContactPhone!,
    ].join(' • ');
    final resilienceId =
        'RAI-${profile.userId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase().padLeft(4, '0').substring(0, 4)}';

    return Scaffold(
      backgroundColor: pageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primary.withAlpha(38),
                            width: 4,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFFE6EFE5),
                          child: Text(
                            widget.username.isNotEmpty
                                ? widget.username[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: primary,
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: InkWell(
                          onTap: _editProfile,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.location_on, size: 15, color: primary),
                      SizedBox(width: 4),
                      Text(
                        'Dengkil, Selangor',
                        style: TextStyle(
                          color: primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: primary.withAlpha(22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Resilience ID: $resilienceId',
                      style: const TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withAlpha(46),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr(
                                  en: 'Preparedness',
                                  ms: 'Kesiapsiagaan',
                                  zh: '应急准备',
                                ),
                                style: const TextStyle(
                                  color: Color(0xCCE8F5E9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.verified,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '85%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: 0.85,
                            minHeight: 5,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tr(en: 'Contacts', ms: 'Kenalan', zh: '联系人'),
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(Icons.emergency, color: primary, size: 14),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          hasEmergencyContact
                              ? tr(en: '1 Active', ms: '1 Aktif', zh: '1 个已设置')
                              : tr(
                                  en: 'Not Set',
                                  ms: 'Belum Ditetapkan',
                                  zh: '未设置',
                                ),
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          hasEmergencyContact
                              ? tr(
                                  en: 'Last verified: 2 days ago',
                                  ms: 'Terakhir disahkan: 2 hari lalu',
                                  zh: '最近验证：2 天前',
                                )
                              : tr(
                                  en: 'Add emergency contact',
                                  ms: 'Tambah kenalan kecemasan',
                                  zh: '添加紧急联系人',
                                ),
                          style: TextStyle(color: tertiaryText, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  tr(
                    en: 'Emergency Contacts',
                    ms: 'Kenalan Kecemasan',
                    zh: '紧急联系人',
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _editProfile,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    tr(en: 'Add New', ms: 'Tambah Baharu', zh: '新增'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: primary,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildContactTile(
              icon: Icons.person,
              title: emergencyName,
              subtitle: emergencyLabel.isNotEmpty
                  ? emergencyLabel
                  : tr(
                      en: 'Primary contact • Not available',
                      ms: 'Kenalan utama • Tiada maklumat',
                      zh: '主要联系人 • 暂无信息',
                    ),
              surface: surface,
              subtleSurface: subtleSurface,
              border: border,
              secondaryText: secondaryText,
              tertiaryText: tertiaryText,
            ),
            const SizedBox(height: 10),
            _buildContactTile(
              icon: Icons.health_and_safety,
              title: 'Local Community Center',
              subtitle: tr(
                en: 'Medical support • Emergency line',
                ms: 'Sokongan perubatan • Talian kecemasan',
                zh: '医疗支援 • 紧急热线',
              ),
              surface: surface,
              subtleSurface: subtleSurface,
              border: border,
              secondaryText: secondaryText,
              tertiaryText: tertiaryText,
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(en: 'Settings', ms: 'Tetapan', zh: '设置'),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingItem(
              icon: Icons.translate,
              tr(en: 'Language', ms: 'Bahasa', zh: '语言'),
              subtitle: languageController.label,
              onTap: _selectLanguage,
            ),
            _buildSettingItem(
              icon: Icons.notifications,
              tr(en: 'Notifications', ms: 'Pemberitahuan', zh: '通知'),
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
                activeTrackColor: primary.withAlpha(120),
                activeThumbColor: primary,
              ),
            ),
            _buildSettingItem(
              icon: Icons.dark_mode,
              tr(en: 'Dark Mode', ms: 'Mod Gelap', zh: '深色模式'),
              trailing: Switch(
                value: themeController.isDarkMode,
                onChanged: (value) {
                  themeController.setDarkMode(value);
                },
                activeTrackColor: primary.withAlpha(120),
                activeThumbColor: primary,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: widget.onLogout,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout, color: Color(0xFFDC2626)),
                    const SizedBox(width: 10),
                    Text(
                      tr(en: 'Log Out', ms: 'Log Keluar', zh: '退出登录'),
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color surface,
    required Color subtleSurface,
    required Color border,
    required Color secondaryText,
    required Color tertiaryText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: subtleSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, color: secondaryText, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: secondaryText),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: tertiaryText),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    String title, {
    required IconData icon,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? const Color(0xFFA7B5A8)
        : const Color(0xFF475569);
    final subtitleColor = isDark
        ? const Color(0xFFA7B5A8)
        : const Color(0xFF64748B);
    final tertiaryText = isDark
        ? const Color(0xFF8A9A8B)
        : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap ?? (trailing == null ? _editProfile : null),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: tertiaryText),
          ],
        ),
      ),
    );
  }
}
