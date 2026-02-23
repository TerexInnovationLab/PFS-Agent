import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../layouts/Colors.dart';
import '../config/api_config.dart';
import 'login.dart';
import 'package:pfs_agent/utils/user_friendly_errors.dart';

class VerifyPage extends StatefulWidget {
  final String email;

  const VerifyPage({
    super.key,
    required this.email,
  });

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  // ✅ 6 OTP boxes
  final List<TextEditingController> controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes =
      List.generate(6, (_) => FocusNode());

  bool canResend = false;
  bool isVerifying = false;
  bool isResending = false;

  int countdown = 120; // ✅ 2 minutes
  Timer? timer;

  final String _backgroundImage = 'assets/images/back.jpeg';

  @override
  void initState() {
    super.initState();
    _startCountdown(); // first OTP already sent
  }

  // ================= FORMAT TIMER TEXT =================
  String _formatResendTime(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')} min';
    } else {
      return '${seconds.toString().padLeft(2, '0')} sec';
    }
  }

  // ================= START COUNTDOWN =================
  void _startCountdown() {
    timer?.cancel();

    setState(() {
      canResend = false;
      countdown = 120;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (countdown > 0) {
        setState(() => countdown--);
      } else {
        setState(() => canResend = true);
        t.cancel();
      }
    });
  }

  // ================= RESEND OTP USING API =================
  Future<void> _resendOtp() async {
    if (!canResend || isResending) return;

    // ✅ Show loader immediately
    setState(() => isResending = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/resend-otp"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": widget.email,
        }),
      );

      // ✅ Only start countdown AFTER backend success
      if (response.statusCode == 200 || response.statusCode == 201) {
        _startCountdown();
      } else {
        Map<String, dynamic> data = {};
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        } catch (_) {
          // ignore JSON parse errors, handle below
        }

        // ❌ Backend failed → allow resend again
        setState(() => canResend = true);

        _showAlert(
          icon: Icons.error_outline,
          color: AppColors.danger,
          message: friendlyErrorFromResponse(
            statusCode: response.statusCode,
            body: response.body,
            messageOverride: data["message"]?.toString(),
          ),
        );
      }
    } catch (e) {
      // ❌ Network error → allow resend again
      setState(() => canResend = true);

      _showAlert(
        icon: Icons.error_outline,
        color: AppColors.danger,
        message: friendlyErrorFromException(e),
      );
    } finally {
      if (mounted) setState(() => isResending = false);
    }
  }

  // ================= VERIFY OTP USING API =================
  Future<void> _checkCode() async {
    String enteredCode = controllers.map((c) => c.text).join();

    if (enteredCode.isEmpty || enteredCode.length < 6) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        message: "Please enter the 6-digit verification code.",
      );
      return;
    }

    setState(() => isVerifying = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/verify-email"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": widget.email,
          "otp": int.tryParse(enteredCode),
        }),
      );

      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {
        // ignore JSON parse errors, handle below
      }

      if (response.statusCode == 200) {
        if (!mounted) return;

        _showAlert(
          icon: Icons.check_circle,
          color: AppColors.success,
          message:
              "Email verified successfully. Wait for the admin to activate your account.",
          navigateToLogin: true,
        );
      } else {
        _showAlert(
          icon: Icons.error_outline,
          color: AppColors.danger,
          message: friendlyErrorFromResponse(
            statusCode: response.statusCode,
            body: response.body,
            messageOverride: data["message"]?.toString(),
          ),
          clearFieldsOnClose: true,
        );
      }
    } catch (e) {
      _showAlert(
        icon: Icons.error_outline,
        color: AppColors.danger,
        message: friendlyErrorFromException(e),
      );
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  // ================= ALERT DIALOG =================
  void _showAlert({
    required IconData icon,
    required Color color,
    required String message,
    bool clearFieldsOnClose = false,
    bool navigateToLogin = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;

          Navigator.of(dialogContext).pop();

          if (clearFieldsOnClose) {
            for (var controller in controllers) {
              controller.clear();
            }
            FocusScope.of(context).requestFocus(focusNodes[0]);
          }

          if (navigateToLogin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          }
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
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 36),
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

  // ================= OTP BOX =================
 Widget _codeBox(int index) {
  return SizedBox(
    width: 38, // ✅ smaller (was 44)
    child: TextField(
      controller: controllers[index],
      focusNode: focusNodes[index],
      keyboardType: TextInputType.number,
      maxLength: 1,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18, // ✅ slightly smaller (was 20)
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        counterText: "",
        filled: true,
        fillColor: AppColors.cardBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 8), // ✅ smaller (was 10)
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // ✅ slightly smaller
          borderSide: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.25),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.6,
          ),
        ),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (value) {
        if (value.length == 1 && index < controllers.length - 1) {
          FocusScope.of(context).requestFocus(focusNodes[index + 1]);
        }
        if (value.isEmpty && index > 0) {
          FocusScope.of(context).requestFocus(focusNodes[index - 1]);
        }
      },
    ),
  );
}


  @override
  void dispose() {
    timer?.cancel();
    for (var c in controllers) {
      c.dispose();
    }
    for (var f in focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        return false;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                  height: 220,
                  child: Image.asset(
                    _backgroundImage,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 220,
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
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 124),
                  child: const Text(
                    "Verify Your Registered Email",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = MediaQuery.of(context).size;

                    return Stack(
                      children: [
                        Positioned(
                          top: size.height * 0.32,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
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
                                        20, 20, 20, 24),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBackground,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              height: 30,
                                              width: 30,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.lock_outline,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Text(
                                              "Enter 6-digit code",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 6),

                                        Text(
                                          "Enter the code that was sent to ${widget.email}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),

                                        const SizedBox(height: 20),

                                        Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: 10,
                                          runSpacing: 12,
                                          children: List.generate(
                                            6,
                                            (i) => _codeBox(i),
                                          ),
                                        ),

                                        const SizedBox(height: 20),

                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: (canResend && !isResending)
                                                ? _resendOtp
                                                : null,
                                            child: isResending
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          AppColors.primary,
                                                    ),
                                                  )
                                                : Text(
                                                    canResend
                                                        ? "Resend code"
                                                        : "Resend in ${_formatResendTime(countdown)}",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: canResend
                                                          ? AppColors.primary
                                                          : AppColors
                                                              .textSecondary,
                                                    ),
                                                  ),
                                          ),
                                        ),

                                        const SizedBox(height: 6),

                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: isVerifying
                                                ? null
                                                : _checkCode,
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
                                            child: isVerifying
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text("Verify"),
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
