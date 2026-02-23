import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pfs_agent/pages/reset_password.dart';
import 'package:pfs_agent/utils/user_friendly_errors.dart';
import '../layouts/Colors.dart';
import '../config/api_config.dart';

class OTPResetCodePage extends StatefulWidget {
  final String email;

  const OTPResetCodePage({
    super.key,
    required this.email,
  });

  @override
  State<OTPResetCodePage> createState() => _OTPResetCodePageState();
}

class _OTPResetCodePageState extends State<OTPResetCodePage> {
  final TextEditingController otpController = TextEditingController();

  // ✅ 6 OTP boxes controllers
  final List<TextEditingController> otpBoxes =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> otpFocus =
      List.generate(6, (_) => FocusNode());

  bool isVerifying = false;
  bool isResending = false;

  String? errorText;

  int secondsRemaining = 120; // ✅ 2 minutes
  Timer? timer;

  final String _backgroundImage = 'assets/images/back.jpeg';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    otpController.dispose();
    for (final c in otpBoxes) {
      c.dispose();
    }
    for (final f in otpFocus) {
      f.dispose();
    }
    super.dispose();
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

  // ================= START TIMER =================
  void _startTimer() {
    timer?.cancel();

    setState(() {
      secondsRemaining = 120;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (secondsRemaining > 0) {
        setState(() => secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

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

  // ================= VERIFY OTP =================
  Future<void> _verifyOtp() async {
    if (otpController.text.trim().length < 6) {
      setState(() => errorText = "Enter the 6-digit OTP");
      return;
    }

    setState(() {
      isVerifying = true;
      errorText = null;
    });

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/verify-otp"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": widget.email,
          "otp": int.tryParse(otpController.text.trim()),
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

      if (response.statusCode == 200 && data["token"] != null) {
        final String token = data["token"].toString();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(
              email: widget.email,
              token: token,
            ),
          ),
        );
      } else {
        final msg = friendlyErrorFromResponse(
          statusCode: response.statusCode,
          body: response.body,
          messageOverride: data["message"]?.toString(),
        );
        _showError(msg);
      }
    } catch (e) {
      _showError(friendlyErrorFromException(e));
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  // ================= RESEND OTP =================
  Future<void> _resendOtp() async {
  if (secondsRemaining > 0 || isResending) return;

  setState(() => isResending = true);

  try {
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}/resend-otp"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({"email": widget.email}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      _startTimer(); // ✅ Start countdown ONLY after backend success
    } else {
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      } catch (_) {}

      final msg = friendlyErrorFromResponse(
        statusCode: response.statusCode,
        body: response.body,
        messageOverride: data["message"]?.toString(),
      );
      _showError(msg);
    }
  } catch (e) {
    _showError(friendlyErrorFromException(e));
  } finally {
    if (mounted) setState(() => isResending = false);
  }
}


  // ================= OTP BOX =================
  Widget _otpBox(int index) {
    return SizedBox(
      width: 38,
      child: TextField(
        controller: otpBoxes[index],
        focusNode: otpFocus[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: AppColors.textSecondary.withOpacity(0.18),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.4,
            ),
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) {
          if (value.isNotEmpty && index < otpBoxes.length - 1) {
            FocusScope.of(context).requestFocus(otpFocus[index + 1]);
          }

          if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(otpFocus[index - 1]);
          }

          otpController.text = otpBoxes.map((e) => e.text).join();
        },
      ),
    );
  }

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
                  colors: [
                    Color.fromARGB(240, 0, 0, 0),
                    Color.fromARGB(40, 0, 0, 0),
                  ],
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
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Verify OTP To Reset Password",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
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
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            padding:
                                const EdgeInsets.fromLTRB(18, 18, 18, 22),
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
                                    const Expanded(
                                      child: Text(
                                        'Verify OTP',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Enter the OTP sent to ${widget.email}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 12,
                                  children: List.generate(
                                    6,
                                    (index) => _otpBox(index),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: secondsRemaining == 0
                                        ? _resendOtp
                                        : null,
                                    child: isResending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child:
                                                CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary, // ✅ match verify button color
                                            ),
                                          )
                                        : Text(
                                            secondsRemaining > 0
                                                ? "Resend in ${_formatResendTime(secondsRemaining)}"
                                                : "Resend OTP",
                                            style: TextStyle(
                                              color: secondsRemaining > 0
                                                  ? Colors.grey
                                                  : AppColors.primary,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        isVerifying ? null : _verifyOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
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
            ),
          ),
        ],
      ),
    );
  }
}
