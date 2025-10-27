import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pfs_agent/dashboardpage.dart';
import 'package:pfs_agent/login.dart';

class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final String verificationCode = "123456";
  final Color orange = const Color(0xFFFF6600);

  final List<TextEditingController> controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  bool canResend = false;
  int countdown = 30;
  Timer? timer;

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
        color: Colors.orange,
        message: "Verification code can't be empty.\nPlease enter the code.",
      );
      return;
    }

    if (enteredCode.length < 6) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        message: "Verification code must be 6 digits.",
      );
      return;
    }

    bool isCorrect = enteredCode == verificationCode;

    _showAlert(
      icon: isCorrect ? Icons.check_circle : Icons.cancel,
      color: isCorrect ? Colors.green : Colors.red,
      message: isCorrect ? "Verification successful!" : "Incorrect verification code.",
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
          Future.delayed(const Duration(seconds: 3), () {
            Navigator.of(dialogContext).pop();
            if (clearFieldsOnClose) {
              for (var controller in controllers) {
                controller.clear();
              }
              FocusScope.of(context).requestFocus(focusNodes[0]);
            }
            if (navigateToDashboard) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardPage()),
              );
            }
          });
        }

        return AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 80),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
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
        keyboardType: TextInputType.phone,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          counterText: "",
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
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
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: Image.asset("assets/images/verify.jpg", fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Please enter the 6-digit verification code sent to your phone number",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Exo2",
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      6,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: _codeBox(i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _checkCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Enter", style: TextStyle(fontSize: 18, fontFamily: "Exo2")),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: canResend ? _startCountdown : null,
                    child: Text(
                      canResend ? "Resend Code" : "Resend in $countdown seconds",
                      style: TextStyle(
                        color: canResend ? orange : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
