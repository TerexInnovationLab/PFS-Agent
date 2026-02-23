import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../layouts/Colors.dart';
import 'Home.dart';
import '../config/api_config.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String token;

  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.token,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isLoading = false;

  String? newPasswordError;
  String? confirmPasswordError;

  final String _backgroundImage = 'assets/images/back.jpeg';

  // ================= SAVE SESSION AFTER RESET =================
  Future<void> _saveUserSessionAfterReset(
    Map<String, dynamic> data,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Save token (fallback to OTP token if API token missing)
    final String token = data['token'] ?? widget.token;
    await prefs.setString('token', token);

    // ✅ Save full user object if present
    if (data['user'] != null) {
      await prefs.setString('user_data', jsonEncode(data['user']));
    } else {
      // fallback minimal user info
      await prefs.setString(
        'user_data',
        jsonEncode({"email": widget.email}),
      );
    }

    // ✅ Keep logged in
    await prefs.setBool('keep_me_logged_in', true);

    // ✅ Save password
    await prefs.setString("password", password);

    debugPrint("✅ Session saved after password reset.");
  }

  // ================= RESET PASSWORD =================
  Future<void> _resetPassword() async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    setState(() {
      newPasswordError = null;
      confirmPasswordError = null;
    });

    if (newPassword.isEmpty) {
      setState(() => newPasswordError = "Password is required");
      return;
    }

    if (newPassword.length < 8) {
      setState(() => newPasswordError = "Minimum 8 characters");
      return;
    }

    if (confirmPassword != newPassword) {
      setState(() => confirmPasswordError = "Passwords do not match");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/reset-password"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer ${widget.token}",
        },
        body: jsonEncode({
          "password": newPassword,
          "password_confirmation": confirmPassword,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      // ✅ Normalize success safely
      final bool isSuccess =
          data["status"].toString().toLowerCase() == "true";

      if (response.statusCode == 200 && isSuccess) {
        // ✅ Save session FIRST (non blocking UI)
        await _saveUserSessionAfterReset(data, newPassword);

        if (!mounted) return;
        _showSuccess(); // ✅ your working dialog + navigation
      } else {
        _showError(data["message"] ?? "Password reset failed");
      }
    } catch (e) {
      debugPrint("Reset error: $e");
      _showError("Network error. Please try again.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= SUCCESS (UNCHANGED WORKING VERSION) =================
  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Timer(const Duration(seconds: 2), () {
          if (!mounted) return;

          Navigator.of(dialogContext).pop();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => Home()),
          );
        });

        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircleAvatar(
                radius: 32,
                backgroundColor: Color(0x3322C55E),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 36,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Password reset successful",
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= ERROR =================
  void _showError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(dialogContext).pop();
        });

        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.danger.withOpacity(0.12),
                child: const Icon(
                  Icons.error_outline,
                  color: AppColors.danger,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= INPUT DECORATION =================
  InputDecoration _inputDecoration({
    required String label,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      isDense: true,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.18),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.danger, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 240,
              child: Image.asset(_backgroundImage, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 240,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xE6000000), Color(0x00000000)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 100),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Reset Password",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Reset your password to access your dashboard and manage your account securely.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 420),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(
                                18, 18, 18, 22),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: newPasswordController,
                                  obscureText: obscureNew,
                                  decoration: _inputDecoration(
                                    label: "New Password",
                                    errorText: newPasswordError,
                                    suffixIcon: IconButton(
                                      icon: Icon(obscureNew
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() =>
                                          obscureNew = !obscureNew),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller:
                                      confirmPasswordController,
                                  obscureText: obscureConfirm,
                                  decoration: _inputDecoration(
                                    label: "Confirm Password",
                                    errorText:
                                        confirmPasswordError,
                                    suffixIcon: IconButton(
                                      icon: Icon(obscureConfirm
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(() =>
                                          obscureConfirm =
                                              !obscureConfirm),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : _resetPassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            "Reset Password",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
