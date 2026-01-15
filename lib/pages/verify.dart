import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layouts/Colors.dart';
import 'Home.dart';
import 'login.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  // 🔐 Hardcoded verification code (4 digits)
  final String verificationCode = "1234";

  // We only need 4 boxes, so 4 controllers & focus nodes
  final List<TextEditingController> controllers =
  List.generate(4, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(4, (_) => FocusNode());

  bool canResend = false;
  int countdown = 30;
  Timer? timer;

  // Single background image (same style as login/dashboard)
  final String _backgroundImage = 'assets/images/back.jpeg';

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() {
      canResend = false;
      countdown = 30;
    });

    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown > 0) {
        setState(() {
          countdown--;
        });
      } else {
        setState(() {
          canResend = true;
        });
        t.cancel();
      }
    });
  }

  void _checkCode() {
    String enteredCode = controllers.map((c) => c.text).join();

    if (enteredCode.isEmpty) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        message:
        "Verification code can't be empty.\nPlease enter the 4-digit code.",
      );
      return;
    }

    if (enteredCode.length < 4) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        message: "Verification code must be 4 digits.",
      );
      return;
    }

    bool isCorrect = enteredCode == verificationCode;

    _showAlert(
      icon: isCorrect ? Icons.check_circle : Icons.cancel,
      color: isCorrect ? AppColors.success : AppColors.danger,
      message:
      isCorrect ? "Verification successful." : "Incorrect verification code.",
      clearFieldsOnClose: !isCorrect,
      navigateToDashboard: isCorrect,
    );
  }

  void _showAlert({
    required IconData icon,
    required Color color,
    required String message,
    bool autoClose = true,
    bool clearFieldsOnClose = false,
    bool navigateToDashboard = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (autoClose) {
          Future.delayed(const Duration(seconds: 2), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            if (clearFieldsOnClose) {
              for (var controller in controllers) {
                controller.clear();
              }
              FocusScope.of(context).requestFocus(focusNodes[0]);
            }
            if (navigateToDashboard) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            }
          });
        }

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
                style: TextStyle(
                  fontSize: 16,
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

  Widget _codeBox(int index) {
    return SizedBox(
      width: 50,
      child: TextField(
        controller: controllers[index],
        focusNode: focusNodes[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: AppColors.cardBackground,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.textSecondary.withOpacity(0.25),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
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
              // 🔹 Hero background image (same as login)
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

              // 🔹 Dark gradient overlay
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 220,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xE6000000),
                        Color(0x00000000),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
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
                        // ===== HEADER: Logo + intro text =====
                        Positioned(
                          top: 24,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 46,
                                child: Text("")
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                "Verify your identity",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Enter the 4-digit code sent to your\nregistered phone number.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ===== MAIN CARD SECTION (bottom sheet style) =====
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              padding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 24),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Container(
                                    width: double.infinity,
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
                                      border: Border.all(
                                        color: AppColors.primary
                                            .withOpacity(0.08),
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 20, 20, 24),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                Icons.sms_outlined,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Text(
                                                "Enter verification code",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                  AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "We’ve sent a 4-digit code to your registered mobile number.",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 24),

                                        // Code boxes
                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.center,
                                          children: List.generate(
                                            4,
                                                (i) => Padding(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6),
                                              child: _codeBox(i),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 24),

                                        // Verify button
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _checkCode,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                              AppColors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding:
                                              const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              "Verify",
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        // Resend
                                        TextButton(
                                          onPressed:
                                          canResend ? _startCountdown : null,
                                          child: Text(
                                            canResend
                                                ? "Resend code"
                                                : "Resend in $countdown seconds",
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: canResend
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
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
