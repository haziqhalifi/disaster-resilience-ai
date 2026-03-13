import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:disaster_resilience_ai/models/profile_model.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';
import 'package:disaster_resilience_ai/theme/app_theme.dart';
import 'package:disaster_resilience_ai/services/notification_service.dart';
import 'package:disaster_resilience_ai/services/weather_service.dart';
import 'package:disaster_resilience_ai/ui/edit_profile_page.dart';
import 'package:disaster_resilience_ai/ui/family_tab.dart';
import 'package:disaster_resilience_ai/ui/my_submissions_page.dart';
import 'package:disaster_resilience_ai/utils/accessibility_settings.dart';

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
  static const _notificationsPrefKey = 'notifications_enabled';

  final ApiService _api = ApiService();
  final WeatherService _weatherService = WeatherService();
  UserProfile? _profile;
  bool _loading = true;
  bool _uploadingProfilePhoto = false;
  String? _error;
  bool _notificationsEnabled = true;
  bool _largeTextEnabled = false;
  bool _reducedMotionEnabled = false;
  bool _hapticOnlyAlertsEnabled = false;
  String _locationLabel = 'Locating...';
  double _currentLat = 3.8077;
  double _currentLon = 103.3260;
  double _preparednessProgress = 0.0;
  List<Map<String, dynamic>> _myReports = [];
  bool _loadingMyReports = true;

  static const List<String> _checklistIds = [
    'b1',
    'b2',
    'b3',
    'b4',
    'b5',
    'b6',
    'b7',
    'd1',
    'd2',
    'd3',
    'd4',
    'd5',
    'd6',
    'd7',
    'a1',
    'a2',
    'a3',
    'a4',
    'a5',
    'a6',
    'a7',
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadNotificationPreference();
    _loadAccessibilitySettings();
    _fetchCurrentLocation();
    _loadPreparedness();
    _loadMyReports();
  }

  Future<void> _loadAccessibilitySettings() async {
    final settings = await AccessibilitySettings.load();
    if (!mounted) return;
    setState(() {
      _largeTextEnabled = settings.largeTextEnabled;
      _reducedMotionEnabled = settings.reducedMotionEnabled;
      _hapticOnlyAlertsEnabled = settings.hapticOnlyAlertsEnabled;
    });
  }

  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool(_notificationsPrefKey) ?? true;
    });
  }

  Future<void> _loadMyReports() async {
    if (widget.accessToken.isEmpty) {
      if (mounted) setState(() => _loadingMyReports = false);
      return;
    }
    try {
      final payload = await _api.fetchMyReports(
        accessToken: widget.accessToken,
      );
      final rows = (payload['reports'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (mounted) {
        setState(() {
          _myReports = rows;
          _loadingMyReports = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMyReports = false);
    }
  }

  Future<void> _loadPreparedness() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final done = _checklistIds
          .where((id) => prefs.getBool('checklist_$id') ?? false)
          .length;
      final total = _checklistIds.length;
      final progress = total == 0 ? 0.0 : done / total;
      if (!mounted) return;
      setState(() {
        _preparednessProgress = progress.clamp(0.0, 1.0);
      });
    } catch (_) {
      // Keep default value when local checklist state can't be loaded.
    }
  }

  Future<void> _fetchCurrentLocation() async {
    double lat = 3.8077;
    double lon = 103.3260;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        lat = pos.latitude;
        lon = pos.longitude;
      }

      final place = await _weatherService.fetchLocationName(
        latitude: lat,
        longitude: lon,
      );
      if (!mounted) return;
      setState(() {
        _currentLat = lat;
        _currentLon = lon;
        _locationLabel = (place != null && place.isNotEmpty)
            ? place
            : 'Near ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLat = lat;
        _currentLon = lon;
        _locationLabel = 'Location unavailable';
      });
    }
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsPrefKey, value);

    if (value) {
      NotificationService.instance.startPolling(
        accessToken: widget.accessToken,
        latitude: _currentLat,
        longitude: _currentLon,
      );
    } else {
      NotificationService.instance.stopPolling();
    }

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _setLargeTextEnabled(bool value) async {
    await AccessibilitySettings.setLargeTextEnabled(value);
    if (!mounted) return;
    setState(() {
      _largeTextEnabled = value;
    });
  }

  Future<void> _setReducedMotionEnabled(bool value) async {
    await AccessibilitySettings.setReducedMotionEnabled(value);
    if (!mounted) return;
    setState(() {
      _reducedMotionEnabled = value;
    });
  }

  Future<void> _setHapticOnlyAlertsEnabled(bool value) async {
    await AccessibilitySettings.setHapticOnlyAlertsEnabled(value);
    if (!mounted) return;
    setState(() {
      _hapticOnlyAlertsEnabled = value;
    });
  }

  Future<void> _selectLanguage() async {
    final languageController = AppLanguageScope.of(context);
    final selectedLanguage = languageController.language;
    final currentLanguage = languageController.language;
    String tr({required String en, required String ms, required String zh}) {
      return switch (currentLanguage) {
        AppLanguage.english => en,
        AppLanguage.indonesian => (() {
          final id = indonesianText(en);
          return id == en ? ms : id;
        })(),
        AppLanguage.malay => ms,
        AppLanguage.chinese => zh,
      };
    }

    final selected = await showModalBottomSheet<AppLanguage>(
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
        final comingSoonBg = isDark
            ? const Color(0xFF1B251B)
            : const Color(0xFFF8FAFC);
        final comingSoonBorder = isDark
            ? const Color(0xFF334236)
            : const Color(0xFFE2E8F0);
        final comingSoonTitle = isDark
            ? const Color(0xFFE5E7EB)
            : const Color(0xFF0F172A);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(
                  tr(en: 'Choose Language', ms: 'Pilih Bahasa', zh: '选择语言'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...AppLanguage.values.map((lang) {
                return ListTile(
                  title: Text(lang.displayLabel),
                  subtitle: Text(
                    tr(
                      en: 'Use this language across the app',
                      ms: 'Guna bahasa ini dalam aplikasi',
                      zh: '在整个应用中使用此语言',
                    ),
                    style: TextStyle(color: subtitleColor),
                  ),
                  trailing: selectedLanguage == lang
                      ? Icon(Icons.check, color: checkColor)
                      : null,
                  onTap: () => Navigator.pop(context, lang),
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: comingSoonBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: comingSoonBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withAlpha(26),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                            child: const Text(
                              'ASEAN-Ready',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tr(
                                en: 'More languages coming soon',
                                ms: 'Lebih banyak bahasa akan datang',
                                zh: '更多语言即将推出',
                              ),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: comingSoonTitle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          en: 'Thai, Vietnamese, Filipino (Tagalog), Khmer, Lao, Burmese, and more.',
                          ms: 'Bahasa Thai, Vietnam, Filipina (Tagalog), Khmer, Lao, Burma dan lain-lain.',
                          zh: '泰语、越南语、菲律宾语（他加禄语）、高棉语、老挝语、缅甸语等。',
                        ),
                        style: TextStyle(color: subtitleColor, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null || selected == selectedLanguage) return;
    await languageController.setLanguage(selected);
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

  Future<void> _showProfileActions() async {
    final tr = AppLanguageScope.tr;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(
                  tr(
                    ctx,
                    en: 'Upload Profile Photo',
                    ms: 'Muat Naik Foto Profil',
                    zh: '上传头像照片',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadProfilePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(
                  tr(
                    ctx,
                    en: 'Edit Profile Details',
                    ms: 'Sunting Butiran Profil',
                    zh: '编辑个人资料详情',
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _editProfile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_uploadingProfilePhoto) return;
    setState(() => _uploadingProfilePhoto = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }

      final file = picked.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Unable to read selected image');
      }

      final fileName = file.name.isNotEmpty ? file.name : 'profile-photo.jpg';
      final lower = fileName.toLowerCase();
      final contentType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';

      await _api.uploadProfilePhoto(
        accessToken: widget.accessToken,
        bytes: bytes,
        filename: fileName,
        contentType: contentType,
      );

      await _fetchProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageScope.tr(
              context,
              en: 'Profile photo updated successfully.',
              ms: 'Foto profil berjaya dikemas kini.',
              zh: '头像照片更新成功。',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLanguageScope.tr(
              context,
              en: 'Unable to upload profile photo: $e',
              ms: 'Tidak dapat memuat naik foto profil: $e',
              zh: '无法上传头像照片：$e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingProfilePhoto = false);
    }
  }

  Future<void> _showCommunityCenterForm() async {
    final centerNameController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark
              ? const Color(0xFFE5E7EB)
              : const Color(0xFF111827);
          final borderColor = isDark
              ? const Color(0xFF334236)
              : const Color(0xFFE2E8F0);
          final fillColor = isDark
              ? const Color(0xFF1B251B)
              : const Color(0xFFF8FAFC);

          InputDecoration deco(String hint) => InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: fillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2D5927)),
            ),
          );

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLanguageScope.tr(
                      ctx,
                      en: 'Local Community Center',
                      ms: 'Pusat Komuniti Setempat',
                      zh: '本地社区中心',
                    ),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: centerNameController,
                    style: TextStyle(color: textColor),
                    decoration: deco(
                      AppLanguageScope.tr(
                        ctx,
                        en: 'Center name',
                        ms: 'Nama pusat',
                        zh: '中心名称',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: addressController,
                    style: TextStyle(color: textColor),
                    maxLines: 2,
                    decoration: deco(
                      AppLanguageScope.tr(
                        ctx,
                        en: 'Address',
                        ms: 'Alamat',
                        zh: '地址',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    style: TextStyle(color: textColor),
                    keyboardType: TextInputType.phone,
                    decoration: deco(
                      AppLanguageScope.tr(
                        ctx,
                        en: 'Contact phone',
                        ms: 'Telefon untuk dihubungi',
                        zh: '联系电话',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    style: TextStyle(color: textColor),
                    maxLines: 3,
                    decoration: deco(
                      AppLanguageScope.tr(
                        ctx,
                        en: 'Notes (optional)',
                        ms: 'Nota (pilihan)',
                        zh: '备注（可选）',
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLanguageScope.tr(
                                context,
                                en: 'Saved locally (not synced to backend yet).',
                                ms: 'Disimpan secara tempatan (belum disegerak ke backend).',
                                zh: '已在本地保存（尚未同步到后端）。',
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        AppLanguageScope.tr(
                          ctx,
                          en: 'Save',
                          ms: 'Simpan',
                          zh: '保存',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      centerNameController.dispose();
      addressController.dispose();
      phoneController.dispose();
      notesController.dispose();
    }
  }

  Future<void> _showEmergencyContactForm() async {
    final nameController = TextEditingController(
      text: _profile?.emergencyContactName ?? '',
    );
    final relationController = TextEditingController(
      text: _profile?.emergencyContactRelationship ?? '',
    );
    final phoneController = TextEditingController(
      text: _profile?.emergencyContactPhone ?? '',
    );
    bool saving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final textColor = isDark
              ? const Color(0xFFE5E7EB)
              : const Color(0xFF111827);
          final borderColor = isDark
              ? const Color(0xFF334236)
              : const Color(0xFFE2E8F0);
          final fillColor = isDark
              ? const Color(0xFF1B251B)
              : const Color(0xFFF8FAFC);

          InputDecoration deco(String hint, IconData icon) => InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF2D5927)),
            filled: true,
            fillColor: fillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2D5927)),
            ),
          );

          return StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLanguageScope.tr(
                        ctx,
                        en: 'Emergency Contact',
                        ms: 'Kenalan Kecemasan',
                        zh: '紧急联系人',
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: textColor),
                      decoration: deco(
                        AppLanguageScope.tr(
                          ctx,
                          en: 'Contact name',
                          ms: 'Nama kenalan',
                          zh: '联系人姓名',
                        ),
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: relationController,
                      style: TextStyle(color: textColor),
                      decoration: deco(
                        AppLanguageScope.tr(
                          ctx,
                          en: 'Relationship',
                          ms: 'Hubungan',
                          zh: '关系',
                        ),
                        Icons.people_outline,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      decoration: deco(
                        AppLanguageScope.tr(
                          ctx,
                          en: 'Contact phone',
                          ms: 'Telefon kenalan',
                          zh: '联系电话',
                        ),
                        Icons.phone_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() => saving = true);
                                try {
                                  await _api.updateProfile(
                                    accessToken: widget.accessToken,
                                    profileData: {
                                      'emergency_contact_name': nameController
                                          .text
                                          .trim(),
                                      'emergency_contact_relationship':
                                          relationController.text.trim(),
                                      'emergency_contact_phone': phoneController
                                          .text
                                          .trim(),
                                    },
                                  );
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                  await _fetchProfile();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLanguageScope.tr(
                                          context,
                                          en: 'Emergency contact updated successfully.',
                                          ms: 'Kenalan kecemasan berjaya dikemas kini.',
                                          zh: '紧急联系人更新成功。',
                                        ),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setSheetState(() => saving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLanguageScope.tr(
                                          context,
                                          en: 'Unable to update emergency contact: $e',
                                          ms: 'Tidak dapat mengemas kini kenalan kecemasan: $e',
                                          zh: '无法更新紧急联系人：$e',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          AppLanguageScope.tr(
                            ctx,
                            en: 'Save Contact',
                            ms: 'Simpan Kenalan',
                            zh: '保存联系人',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } finally {
      nameController.dispose();
      relationController.dispose();
      phoneController.dispose();
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
        AppLanguage.indonesian => (() {
          final id = indonesianText(en);
          return id == en ? ms : id;
        })(),
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
    final locationAccent = isDark ? const Color(0xFF9EDB94) : primary;
    final idChipBg = isDark
        ? const Color(0xFF2D5927).withAlpha(72)
        : primary.withAlpha(22);
    final editButtonColor = isDark ? const Color(0xFF9EDB94) : primary;
    final editButtonBg = isDark
        ? const Color(0xFF2D5927).withAlpha(56)
        : primary.withAlpha(14);
    final switchActiveTrack = isDark
        ? const Color(0xFF3E7041)
        : primary.withAlpha(120);
    final switchActiveThumb = isDark ? const Color(0xFFBEEAB6) : primary;
    final switchInactiveTrack = isDark
        ? const Color(0xFF3A463A)
        : const Color(0xFFE2E8F0);
    final switchInactiveThumb = isDark
        ? const Color(0xFF8FA08F)
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
    final preparednessDone = (_preparednessProgress * _checklistIds.length)
        .round();
    final preparednessPercent = (_preparednessProgress * 100).round();
    final landaId =
        'RAI-${profile.userId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase().padLeft(4, '0').substring(0, 4)}';
    final hasProfilePhoto = profile.profilePhotoUrl?.isNotEmpty ?? false;

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
                          backgroundImage: hasProfilePhoto
                              ? NetworkImage(profile.profilePhotoUrl!)
                              : null,
                          onBackgroundImageError: hasProfilePhoto
                              ? (exception, stackTrace) {
                                  // Fall back to initials when image fails to load.
                                  if (!mounted) return;
                                  final currentUrl = _profile?.profilePhotoUrl;
                                  if (currentUrl == null ||
                                      currentUrl.isEmpty) {
                                    return;
                                  }
                                  final safeProfile = _profile;
                                  if (safeProfile == null) return;
                                  setState(() {
                                    _profile = UserProfile(
                                      userId: safeProfile.userId,
                                      fullName: safeProfile.fullName,
                                      phoneNumber: safeProfile.phoneNumber,
                                      bloodType: safeProfile.bloodType,
                                      profilePhotoUrl: null,
                                      allergies: safeProfile.allergies,
                                      medicalConditions:
                                          safeProfile.medicalConditions,
                                      emergencyContactName:
                                          safeProfile.emergencyContactName,
                                      emergencyContactRelationship: safeProfile
                                          .emergencyContactRelationship,
                                      emergencyContactPhone:
                                          safeProfile.emergencyContactPhone,
                                    );
                                  });
                                }
                              : null,
                          child: hasProfilePhoto
                              ? null
                              : Text(
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
                          onTap: _showProfileActions,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                            child: _uploadingProfilePhoto
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt,
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
                    children: [
                      Icon(Icons.location_on, size: 15, color: locationAccent),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: locationAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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
                      color: idChipBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'LANDA ID: $landaId',
                      style: TextStyle(
                        color: locationAccent,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      en: 'Safety Overview',
                      ms: 'Ringkasan Keselamatan',
                      zh: '安全概览',
                    ),
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified, color: primary, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  tr(
                                    en: 'Preparedness',
                                    ms: 'Kesiapsiagaan',
                                    zh: '应急准备',
                                  ),
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$preparednessPercent%',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF111827),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(
                                en: '$preparednessDone/${_checklistIds.length} completed',
                                ms: '$preparednessDone/${_checklistIds.length} selesai',
                                zh: '已完成 $preparednessDone/${_checklistIds.length}',
                              ),
                              style: TextStyle(
                                color: tertiaryText,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 64,
                        color: border,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.emergency, color: primary, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  tr(en: 'Contacts', ms: 'Kenalan', zh: '联系人'),
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hasEmergencyContact
                                  ? tr(
                                      en: '1 Active',
                                      ms: '1 Aktif',
                                      zh: '1 个已设置',
                                    )
                                  : tr(
                                      en: 'Not Set',
                                      ms: 'Belum Ditetapkan',
                                      zh: '未设置',
                                    ),
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF111827),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasEmergencyContact
                                  ? tr(
                                      en: 'Saved on your safety profile',
                                      ms: 'Disimpan dalam profil keselamatan anda',
                                      zh: '已保存到您的安全资料',
                                    )
                                  : tr(
                                      en: 'Add emergency contact',
                                      ms: 'Tambah kenalan kecemasan',
                                      zh: '添加紧急联系人',
                                    ),
                              style: TextStyle(
                                color: tertiaryText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: _preparednessProgress,
                      minHeight: 6,
                      color: primary,
                      backgroundColor: subtleSurface,
                    ),
                  ),
                ],
              ),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _editProfile,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: editButtonColor,
                  ),
                  label: Text(
                    tr(en: 'Manage Contact', ms: 'Urus Kenalan', zh: '管理联系人'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: editButtonColor,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: editButtonColor,
                    backgroundColor: editButtonBg,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
              onTap: _showEmergencyContactForm,
            ),
            const SizedBox(height: 10),
            _buildContactTile(
              icon: Icons.health_and_safety,
              title: tr(
                en: 'Local Community Center',
                ms: 'Pusat Komuniti Tempatan',
                zh: '本地社区中心',
              ),
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
              onTap: _showCommunityCenterForm,
            ),
            const SizedBox(height: 24),
            _buildSettingItem(
              tr(en: 'My Submissions', ms: 'Penghantaran Saya', zh: '我的提交'),
              icon: Icons.flag_outlined,
              subtitle: _loadingMyReports
                  ? tr(
                      en: 'Loading your reports...',
                      ms: 'Memuatkan laporan anda...',
                      zh: '正在加载您的提交...',
                    )
                  : _myReports.isEmpty
                  ? tr(
                      en: 'No submissions yet',
                      ms: 'Tiada penghantaran lagi',
                      zh: '暂无提交',
                    )
                  : tr(
                      en: '${_myReports.length} report(s)',
                      ms: '${_myReports.length} laporan',
                      zh: '${_myReports.length} 条提交',
                    ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MySubmissionsPage(accessToken: widget.accessToken),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(en: 'Settings', ms: 'Tetapan', zh: '设置'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingItem(
              tr(en: 'Language', ms: 'Bahasa', zh: '语言'),
              icon: Icons.translate,
              subtitle:
                  '${languageController.label}  ·  ${tr(en: "ASEAN-Ready", ms: "Sedia ASEAN", zh: "东盟就绪")}  🇲🇾 🇮🇩 🇺🇸 🇨🇳',
              onTap: _selectLanguage,
            ),
            _buildSettingItem(
              tr(en: 'Notifications', ms: 'Pemberitahuan', zh: '通知'),
              icon: Icons.notifications,
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: _setNotificationsEnabled,
                activeTrackColor: switchActiveTrack,
                activeThumbColor: switchActiveThumb,
                inactiveTrackColor: switchInactiveTrack,
                inactiveThumbColor: switchInactiveThumb,
              ),
            ),
            _buildSettingItem(
              tr(en: 'Test Notification', ms: 'Uji Pemberitahuan', zh: '测试通知'),
              icon: Icons.notifications_active_outlined,
              subtitle: tr(
                en: 'Send a test alert after enabling notifications',
                ms: 'Hantar amaran ujian selepas mengaktifkan pemberitahuan',
                zh: '启用通知后发送测试提醒',
              ),
              onTap: () async {
                if (!_notificationsEnabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          en: 'Enable notifications first to run a test alert',
                          ms: 'Aktifkan pemberitahuan dahulu untuk menjalankan amaran ujian',
                          zh: '请先启用通知再发送测试提醒',
                        ),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                try {
                  await NotificationService.instance.showTestNotification(
                    title: tr(
                      en: 'TEST ALERT: Flood Warning - Dengkil',
                      ms: 'AMARAN UJIAN: Amaran Banjir - Dengkil',
                      zh: '测试警报：洪水预警 - Dengkil',
                    ),
                    description: tr(
                      en: 'Real emergency test alert for Dengkil flood response. Proceed to safe high ground and review evacuation route now.',
                      ms: 'Amaran ujian kecemasan sebenar untuk tindak balas banjir Dengkil. Bergerak ke kawasan tinggi yang selamat dan semak laluan pemindahan sekarang.',
                      zh: '用于 Dengkil 洪灾响应的真实紧急测试警报。请立即前往安全高地并查看疏散路线。',
                    ),
                    source: tr(en: 'Test Mode', ms: 'Mod Ujian', zh: '测试模式'),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          en: 'Test notification sent',
                          ms: 'Pemberitahuan ujian dihantar',
                          zh: '测试通知已发送',
                        ),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr(
                          en: 'Notifications are not supported on this platform',
                          ms: 'Pemberitahuan tidak disokong pada platform ini',
                          zh: '此平台不支持通知',
                        ),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
            _buildSettingItem(
              tr(en: 'Family', ms: 'Keluarga', zh: '家人'),
              icon: Icons.group_outlined,
              subtitle: tr(
                en: 'Manage family & live location sharing',
                ms: 'Urus keluarga & perkongsian lokasi langsung',
                zh: '管理家庭与实时位置共享',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FamilyTab(accessToken: widget.accessToken),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(en: 'Accessibility', ms: 'Kebolehcapaian', zh: '无障碍'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingItem(
              tr(en: 'Large text', ms: 'Teks besar', zh: '大号字体'),
              icon: Icons.text_increase,
              subtitle: tr(
                en: 'Increase readability across the app',
                ms: 'Tingkatkan kebolehbacaan di seluruh aplikasi',
                zh: '提高整个应用的可读性',
              ),
              trailing: Switch(
                value: _largeTextEnabled,
                onChanged: _setLargeTextEnabled,
                activeTrackColor: switchActiveTrack,
                activeThumbColor: switchActiveThumb,
                inactiveTrackColor: switchInactiveTrack,
                inactiveThumbColor: switchInactiveThumb,
              ),
            ),
            _buildSettingItem(
              tr(en: 'Reduce motion', ms: 'Kurangkan animasi', zh: '减少动态效果'),
              icon: Icons.motion_photos_off_outlined,
              subtitle: tr(
                en: 'Limit pulse and movement on emergency screens',
                ms: 'Hadkan kesan berdenyut dan pergerakan pada skrin kecemasan',
                zh: '减少紧急页面的闪烁与移动效果',
              ),
              trailing: Switch(
                value: _reducedMotionEnabled,
                onChanged: _setReducedMotionEnabled,
                activeTrackColor: switchActiveTrack,
                activeThumbColor: switchActiveThumb,
                inactiveTrackColor: switchInactiveTrack,
                inactiveThumbColor: switchInactiveThumb,
              ),
            ),
            _buildSettingItem(
              tr(
                en: 'Haptic-only emergency alerts',
                ms: 'Amaran kecemasan haptik sahaja',
                zh: '仅震动紧急警报',
              ),
              icon: Icons.vibration,
              subtitle: tr(
                en: 'Use vibration without alarm sound',
                ms: 'Gunakan getaran tanpa bunyi penggera',
                zh: '仅使用震动，不播放警报声',
              ),
              trailing: Switch(
                value: _hapticOnlyAlertsEnabled,
                onChanged: _setHapticOnlyAlertsEnabled,
                activeTrackColor: switchActiveTrack,
                activeThumbColor: switchActiveThumb,
                inactiveTrackColor: switchInactiveTrack,
                inactiveThumbColor: switchInactiveThumb,
              ),
            ),
            _buildSettingItem(
              tr(en: 'Dark Mode', ms: 'Mod Gelap', zh: '深色模式'),
              icon: Icons.dark_mode,
              trailing: Switch(
                value: themeController.isDarkMode,
                onChanged: (value) {
                  themeController.setDarkMode(value);
                },
                activeTrackColor: switchActiveTrack,
                activeThumbColor: switchActiveThumb,
                inactiveTrackColor: switchInactiveTrack,
                inactiveThumbColor: switchInactiveThumb,
              ),
            ),
            _buildDangerOptionItem(
              tr(en: 'Log Out', ms: 'Log Keluar', zh: '退出登录'),
              icon: Icons.logout,
              onTap: widget.onLogout,
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
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
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
              if (showChevron) Icon(Icons.chevron_right, color: tertiaryText),
            ],
          ),
        ),
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
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final border = isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final subtleSurface = isDark
        ? const Color(0xFF233124)
        : const Color(0xFFF1F5F9);
    final iconColor = isDark
        ? const Color(0xFFA7B5A8)
        : const Color(0xFF475569);
    final subtitleColor = isDark
        ? const Color(0xFFA7B5A8)
        : const Color(0xFF64748B);
    final tertiaryText = isDark
        ? const Color(0xFF8A9A8B)
        : const Color(0xFF94A3B8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? (trailing == null ? _editProfile : null),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: subtleSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(icon, color: iconColor, size: 19),
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
        ),
      ),
    );
  }

  Widget _buildDangerOptionItem(
    String title, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF4A2A2A) : const Color(0xFFFECACA);
    final bg = isDark ? const Color(0xFF2A1B1B) : const Color(0xFFFFF1F2);
    const fg = Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: fg.withAlpha(24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(Icons.logout, color: fg, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
