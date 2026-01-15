import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pfs_agent/layouts/Colors.dart';

class EditProfilePage extends StatefulWidget {
  final String? fullName;
  final String? phone;
  final String? email;
  final String? region;
  final String? tier; // Bronze / Silver / Gold
  final String? agentId;
  final String? avatarPath; // optional local image path

  const EditProfilePage({
    super.key,
    this.fullName,
    this.phone,
    this.email,
    this.region,
    this.tier,
    this.agentId,
    this.avatarPath,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _regionCtrl;

  String? _selectedTier;
  File? _avatarFile;
  String? _avatarPath;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(text: widget.fullName ?? "Frank Botoman");
    _phoneCtrl = TextEditingController(text: widget.phone ?? "+265 999 000 000");
    _emailCtrl = TextEditingController(text: widget.email ?? "frank.botoman@pinnacle.mw");
    _regionCtrl = TextEditingController(text: widget.region ?? "Southern Region");

    _selectedTier = widget.tier ?? "Silver";
    _avatarPath = widget.avatarPath;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final XFile? picked =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
        _avatarPath = picked.path;
      });
    }
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final updated = {
      "fullName": _nameCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      "email": _emailCtrl.text.trim(),
      "region": _regionCtrl.text.trim(),
      "tier": _selectedTier,
      "agentId": widget.agentId ?? "00001",
      "avatarPath": _avatarPath,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Profile updated"),
        backgroundColor: AppColors.success,
      ),
    );

    // Return updated profile data to previous page
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        centerTitle: true,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Center(child: _buildAvatarSection()),
            const SizedBox(height: 18),

            // Form card
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _nameCtrl,
                      label: "Full name",
                      icon: Icons.person_outline,
                      validatorMessage: "Please enter your name",
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _phoneCtrl,
                      label: "Phone number",
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validatorMessage: "Please enter your phone number",
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _emailCtrl,
                      label: "Email address",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validatorMessage: "Please enter a valid email",
                      emailValidation: true,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _regionCtrl,
                      label: "Region",
                      icon: Icons.location_on_outlined,
                      validatorMessage: "Please enter your region",
                    ),
                    const SizedBox(height: 14),

                    // Tier (Bronze / Silver / Gold)
                    _buildTierSelector(),

                    const SizedBox(height: 16),

                    // Agent ID (read only)
                    if (widget.agentId != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Agent ID: ${widget.agentId}",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text("Save changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= AVATAR SECTION =================

  Widget _buildAvatarSection() {
    return Column(
      children: [
        Stack(
          children: [
            _buildAvatarCircle(),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Update profile picture",
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCircle() {
    const double size = 86;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: _avatarFile != null
            ? Image.file(
          _avatarFile!,
          fit: BoxFit.cover,
        )
            : (_avatarPath != null && _avatarPath!.isNotEmpty)
            ? Image.file(
          File(_avatarPath!),
          fit: BoxFit.cover,
        )
            : Container(
          color: AppColors.primary.withOpacity(0.15),
          child: const Icon(
            Icons.person,
            size: 40,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ================= TEXT FIELD BUILDER =================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String validatorMessage,
    TextInputType keyboardType = TextInputType.text,
    bool emailValidation = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return validatorMessage;
        }
        if (emailValidation) {
          final email = val.trim();
          final emailRegex = RegExp(
            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
          );
          if (!emailRegex.hasMatch(email)) {
            return 'Enter a valid email address';
          }
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        labelStyle: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.18),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: 1.4,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.danger,
            width: 1.4,
          ),
        ),
      ),
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
      ),
    );
  }

  // ================= TIER SELECTOR =================

  Widget _buildTierSelector() {
    final tiers = ["Bronze", "Silver", "Gold"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Category",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: tiers.map((tier) {
            final bool selected = _selectedTier == tier;
            return ChoiceChip(
              label: Text(
                tier,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
              selected: selected,
              onSelected: (value) {
                if (value) {
                  setState(() {
                    _selectedTier = tier;
                  });
                }
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary.withOpacity(0.16),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
