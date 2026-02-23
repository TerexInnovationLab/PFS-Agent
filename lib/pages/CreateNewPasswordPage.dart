import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/Home.dart';
import 'package:pfs_agent/utils/user_friendly_errors.dart';
import '../config/api_config.dart';

class Createnewpasswordpage extends StatefulWidget {
  const Createnewpasswordpage({super.key});

  @override
  State<Createnewpasswordpage> createState() => _CreatenewpasswordpageState();
}

class _CreatenewpasswordpageState extends State<Createnewpasswordpage> {
  final TextEditingController oldPassController = TextEditingController();
  final TextEditingController newPassController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  bool obscureOld = true;
  bool obscureNew = true;
  bool obscureConfirm = true;
  bool isSubmitting = false;

  String? oldPasswordError;
  String? newPasswordError;
  String? confirmPasswordError;

  final String _backgroundImage = 'assets/images/back.jpeg';

  @override
  void dispose() {
    oldPassController.dispose();
    newPassController.dispose();
    confirmController.dispose();
    super.dispose();
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircleAvatar(
                radius: 32,
                backgroundColor: Color(0x3322C55E),
                child: Icon(Icons.check_circle, color: Colors.green, size: 36),
              ),
              SizedBox(height: 16),
              Text(
                "Password updated successfully",
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

  void _showError(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.danger.withOpacity(0.12),
                child: const Icon(Icons.error_outline, color: AppColors.danger, size: 36),
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

  // ✅ FIXED (same as ResetPasswordPage)
  InputDecoration _inputDecoration({
    required String label,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      isDense: true,
      errorText: errorText,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
      ),
    );
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("token");
    if (raw == null) return null;

    // ✅ If someone saved "Bearer xxx" into prefs, strip it
    final cleaned = raw.trim().replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '');
    return cleaned;
  }

  Map<String, dynamic> _safeJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {"data": decoded};
    } catch (_) {
      return {};
    }
  }

  Future<void> _submit() async {
    if (isSubmitting) return;

    final oldPass = oldPassController.text.trim();
    final newPass = newPassController.text.trim();
    final confirm = confirmController.text.trim();

    setState(() {
      oldPasswordError = null;
      newPasswordError = null;
      confirmPasswordError = null;
    });

    if (oldPass.isEmpty) {
      setState(() => oldPasswordError = "Old password is required");
      return;
    }
    if (newPass.isEmpty) {
      setState(() => newPasswordError = "Password is required");
      return;
    }
    if (newPass.length < 8) {
      setState(() => newPasswordError = "Minimum 8 characters");
      return;
    }
    if (confirm != newPass) {
      setState(() => confirmPasswordError = "Passwords do not match");
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        _showError("Session expired. Please login again.");
        return;
      }

      final uri = Uri.parse("${ApiConfig.baseUrl}/password");

      // ✅ Debug: proves click -> submit -> URL -> token length
      debugPrint("✅ Submit clicked");
      debugPrint("➡️ Change password URL: $uri");
      debugPrint("➡️ Token length: ${token.length}");

      final response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode({
              "current_password": oldPass,
              "password": newPass,
              "password_confirmation": confirm,
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("⬅️ Status: ${response.statusCode}");
      debugPrint("⬅️ Body: ${response.body}");

      final data = _safeJsonMap(response.body);

      final ok = response.statusCode == 200 && (data["status"] == true);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("password", newPass);
        if (!mounted) return;
        _showSuccess();
        return;
      }

      final msg = friendlyErrorFromResponse(
        statusCode: response.statusCode,
        body: response.body,
        messageOverride: data["message"]?.toString(),
      );
      _showError(msg);
    } on TimeoutException catch (e) {
      _showError(friendlyErrorFromException(e));
    } catch (e) {
      // ✅ This catch is now for real exceptions (TLS/DNS/etc)
      _showError(friendlyErrorFromException(e));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
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
                    child: const Text(
                      "Update Your Credentials",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        height: 30,
                                        width: 30,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.lock_outline, size: 18, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        "Create New Password",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Update your password to keep your account secure.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 18),

                                  TextField(
                                    controller: oldPassController,
                                    obscureText: obscureOld,
                                    decoration: _inputDecoration(
                                      label: "Old Password",
                                      errorText: oldPasswordError,
                                      suffixIcon: IconButton(
                                        icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setState(() => obscureOld = !obscureOld),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  TextField(
                                    controller: newPassController,
                                    obscureText: obscureNew,
                                    decoration: _inputDecoration(
                                      label: "New Password",
                                      errorText: newPasswordError,
                                      suffixIcon: IconButton(
                                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setState(() => obscureNew = !obscureNew),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  TextField(
                                    controller: confirmController,
                                    obscureText: obscureConfirm,
                                    decoration: _inputDecoration(
                                      label: "Confirm Password",
                                      errorText: confirmPasswordError,
                                      suffixIcon: IconButton(
                                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: isSubmitting ? null : _submit,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      child: isSubmitting
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text(
                                              "Confirm",
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
      ),
    );
  }
}
