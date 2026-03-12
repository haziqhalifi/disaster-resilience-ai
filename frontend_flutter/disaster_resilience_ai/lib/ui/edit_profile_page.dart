import 'package:flutter/material.dart';
import 'package:disaster_resilience_ai/localization/app_language.dart';
import 'package:disaster_resilience_ai/models/profile_model.dart';
import 'package:disaster_resilience_ai/services/api_service.dart';

class EditProfilePage extends StatefulWidget {
  final String accessToken;
  final UserProfile profile;

  const EditProfilePage({
    super.key,
    required this.accessToken,
    required this.profile,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicalController;

  String? _selectedBloodType;
  bool _saving = false;

  final List<String> _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phoneNumber);
    _allergiesController = TextEditingController(
      text: widget.profile.allergies,
    );
    _medicalController = TextEditingController(
      text: widget.profile.medicalConditions,
    );
    _selectedBloodType = widget.profile.bloodType;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _allergiesController.dispose();
    _medicalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final updatedData = {
        'full_name': _fullNameController.text,
        'phone_number': _phoneController.text,
        'blood_type': _selectedBloodType,
        'allergies': _allergiesController.text,
        'medical_conditions': _medicalController.text,
      };

      await _api.updateProfile(
        accessToken: widget.accessToken,
        profileData: updatedData,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(content: Text(_tr(en: 'Error saving profile: $e', ms: 'Ralat menyimpan profil: $e', zh: '保存个人资料出错：$e'))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0F140F) : const Color(0xFFF0F2F5);
    final surface = isDark ? const Color(0xFF1B251B) : Colors.white;
    final border = isDark ? const Color(0xFF334236) : const Color(0xFFE2E8F0);
    final heading = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    final section = isDark ? const Color(0xFF86C77C) : const Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: pageBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        title: Text(
          _tr(en: 'Edit Profile', ms: 'Sunting Profil', zh: '编辑个人资料'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: border,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              _tr(en: 'Personal Information', ms: 'Maklumat Peribadi', zh: '个人信息'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: section,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _tr(en: 'Full Name', ms: 'Nama Penuh', zh: '全名'),
              _fullNameController,
              Icons.person_outline,
            ),
            _buildTextField(
              _tr(en: 'Phone Number', ms: 'Nombor Telefon', zh: '电话号码'),
              _phoneController,
              Icons.phone_android,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 24),
            Text(
              _tr(en: 'Medical Details', ms: 'Butiran Perubatan', zh: '医疗详情'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: section,
              ),
            ),
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: surface,
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedBloodType,
                dropdownColor: surface,
                style: TextStyle(color: heading),
                decoration: _inputDecoration(
                  _tr(en: 'Blood Type', ms: 'Jenis Darah', zh: '血型'),
                  Icons.bloodtype_outlined,
                ),
                items: _bloodTypes
                    .map(
                      (type) => DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedBloodType = val),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              _tr(en: 'Allergies', ms: 'Alahan', zh: '过敏'),
              _allergiesController,
              Icons.warning_amber,
              maxLines: 2,
            ),
            _buildTextField(
              _tr(en: 'Medical Conditions', ms: 'Keadaan Perubatan', zh: '健康状况'),
              _medicalController,
              Icons.medical_services_outlined,
              maxLines: 2,
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _saving
                    ? _tr(en: 'SAVING...', ms: 'MENYIMPAN...', zh: '保存中...')
                    : _tr(en: 'SAVE PROFILE', ms: 'SIMPAN PROFIL', zh: '保存个人资料'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _inputDecoration(label, icon),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF334236) : const Color(0xFFD1D5DB);
    final textColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    final fillColor = isDark ? const Color(0xFF1E2720) : Colors.white;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textColor.withAlpha(190)),
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
    );
  }

  String _tr({required String en, required String ms, required String zh}) {
    final language = AppLanguageScope.of(context).language;
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
}
