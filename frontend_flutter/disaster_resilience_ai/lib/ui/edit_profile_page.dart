import 'package:flutter/material.dart';
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
  late TextEditingController _contactNameController;
  late TextEditingController _contactRelationController;
  late TextEditingController _contactPhoneController;

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
    _contactNameController = TextEditingController(
      text: widget.profile.emergencyContactName,
    );
    _contactRelationController = TextEditingController(
      text: widget.profile.emergencyContactRelationship,
    );
    _contactPhoneController = TextEditingController(
      text: widget.profile.emergencyContactPhone,
    );
    _selectedBloodType = widget.profile.bloodType;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _allergiesController.dispose();
    _medicalController.dispose();
    _contactNameController.dispose();
    _contactRelationController.dispose();
    _contactPhoneController.dispose();
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
        'emergency_contact_name': _contactNameController.text,
        'emergency_contact_relationship': _contactRelationController.text,
        'emergency_contact_phone': _contactPhoneController.text,
      };

      await _api.updateProfile(
        accessToken: widget.accessToken,
        profileData: updatedData,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        title: const Text('Edit Profile & Emergency Info'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFF2D5927).withAlpha(26),
          ),
        ),
        actions: [
          _saving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Full Name',
              _fullNameController,
              Icons.person_outline,
            ),
            _buildTextField(
              'Phone Number',
              _phoneController,
              Icons.phone_android,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 24),
            const Text(
              'Medical Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedBloodType,
              decoration: _inputDecoration(
                'Blood Type',
                Icons.bloodtype_outlined,
              ),
              items: _bloodTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedBloodType = val),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Allergies',
              _allergiesController,
              Icons.warning_amber,
              maxLines: 2,
            ),
            _buildTextField(
              'Medical Conditions',
              _medicalController,
              Icons.medical_services_outlined,
              maxLines: 2,
            ),

            const SizedBox(height: 24),
            const Text(
              'Emergency Contact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Contact Name',
              _contactNameController,
              Icons.contact_emergency,
            ),
            _buildTextField(
              'Relationship',
              _contactRelationController,
              Icons.people_outline,
            ),
            _buildTextField(
              'Contact Phone',
              _contactPhoneController,
              Icons.phone,
              keyboardType: TextInputType.phone,
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
              child: const Text(
                'SAVE PROFILE',
                style: TextStyle(fontWeight: FontWeight.bold),
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
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
    );
  }
}
