import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/Home.dart';
import 'package:pfs_agent/pages/forgot_password.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'Sign Up.dart';
import 'package:pfs_agent/pages/verify.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();

  String result = "result";
  bool keepSignedIn = false;
  bool passwordVisible = false;
  bool isLoading = false;

  final String _backgroundImage = 'assets/images/back.jpeg';

  // ✅ ADD: timer to safely navigate after delay
  Timer? _verifyNavTimer;

  @override
  void dispose() {
    _verifyNavTimer?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  /// Saves user session data to SharedPreferences
  Future<void> _saveUserSession(Map<String, dynamic> responseData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString('token', responseData['token']);

    final String userJson = jsonEncode(responseData['user']);
    await prefs.setString('user_data', userJson);

    await prefs.setBool('keep_me_logged_in', keepSignedIn);

    // optional: store password if you really need it (security risk)
    await prefs.setString("password", password.text.trim());

    print("Session saved: Token and User Data stored locally.");
  }

  bool _validateLoginFields() {
    final e = email.text.trim();
    final p = password.text.trim();

    if (e.isEmpty) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        message: "Please enter your email address.",
      );
      return false;
    }

    if (!e.contains('@') || !e.contains('.')) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        message: "Please enter a valid email address.",
      );
      return false;
    }

    if (p.isEmpty) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        message: "Please enter your password.",
      );
      return false;
    }

    return true;
  }

  // ✅ ADD: helper to detect "email not verified" messages robustly
  bool _isEmailNotVerifiedMessage(String msg) {
    final m = msg.toLowerCase().trim();
    return m.contains('email') &&
        (m.contains('not verified') ||
            m.contains('unverified') ||
            m.contains('verify your email') ||
            m.contains('email verification') ||
            m.contains('verify email'));
  }

  // ✅ ADD ONLY LOGIC: hit resend-otp endpoint (no UI changes)
  Future<void> _resendOtpBeforeVerify(String enteredEmail) async {
    try {
      await http.post(
        Uri.parse("${ApiConfig.baseUrl}/resend-otp"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({"email": enteredEmail}),
      );
    } catch (e) {
      // Do not block navigation; requirement is just "must hit endpoint"
      print("resend-otp error: $e");
    }
  }

  // ✅ UPDATED: navigate to VerifyPage after 2 seconds (pass entered email)
  //            AND before navigation, hit resend-otp endpoint
  void _goToVerifyAfterDelay() {
    _verifyNavTimer?.cancel();

    final String enteredEmail = email.text.trim();

    _verifyNavTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;

      // ✅ Must hit resend-otp when navigating to verify
      await _resendOtpBeforeVerify(enteredEmail);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyPage(email: enteredEmail),
        ),
      );
    });
  }

  Future<void> sendData() async {
    if (!_validateLoginFields()) return;
    if (isLoading) return;

    const String url = ApiConfig.baseUrl + "/login";

    final Map<String, dynamic> data = {
      "email": email.text.trim(),
      "password": password.text.trim(),
    };

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      );

      Map<String, dynamic>? body;
      if (response.body.isNotEmpty) {
        try {
          body = jsonDecode(response.body);
        } catch (_) {
          body = null;
        }
      }

      if (body != null) {
        if (body['status'] == true && body['token'] != null) {
          await _saveUserSession(body);

          if (!mounted) return;

          await printUserInfo();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Home()),
          );
        } else {
          final msg = body?['message']?.toString() ?? "Login failed.";

          setState(() => result = msg);

          _showAlert(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            message: msg,
          );

          // ✅ if email not verified → go to VerifyPage after 2 seconds
          // (and that navigation will hit resend-otp)
          if (_isEmailNotVerifiedMessage(msg)) {
            _goToVerifyAfterDelay();
          }
        }
      } else {
        setState(() => result = "Request failed (${response.statusCode})");

        _showAlert(
          icon: Icons.error_outline,
          color: AppColors.danger,
          message: result,
        );
      }
    } catch (e) {
      setState(() => result = "Network error: $e");

      _showAlert(
        icon: Icons.error,
        color: AppColors.danger,
        message: result,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> printUserInfo() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('user_data');

    if (userJson != null) {
      final Map<String, dynamic> user = jsonDecode(userJson);

      print("--- User Profile ---");
      print("Full Name: ${user['first_name']} ${user['last_name']}");
      print("Email: ${user['email']}");
      print("Role: ${user['role']}");

      if (user['agent'] != null) {
        print("Agent Region: ${user['agent']['region']}");
        print("Bank Account: ${user['agent']['bank_account_name']}");
      }

      final bool keepIn = prefs.getBool('keep_me_logged_in') ?? false;
      print("Keep Logged In: $keepIn");
    } else {
      print("No user data found in storage.");
    }
  }

  void _showAlert({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 60),
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

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: AppColors.primary, size: 20)
          : null,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.textSecondary.withOpacity(0.18), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
            child: Stack(
              children: [
                Positioned(
                  top: 100,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Welcome Pinnacle Agent",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Sign in to access your PFS dashboard\nand manage your sales in one place.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: size.height * 0.26,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      height: 30,
                                      width: 30,
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
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
                                        'Sign in to PFS',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  "Email address",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: _inputDecoration(
                                    label: 'Email',
                                    prefixIcon: Icons.person_outline,
                                  ),
                                  onSubmitted: (_) =>
                                      FocusScope.of(context).nextFocus(),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  "Password",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: password,
                                  obscureText: !passwordVisible,
                                  decoration: _inputDecoration(
                                    label: 'Password',
                                    prefixIcon: Icons.lock_outline,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        passwordVisible
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () => setState(() =>
                                          passwordVisible = !passwordVisible),
                                    ),
                                  ),
                                  onSubmitted: (_) {
                                    if (!_validateLoginFields()) return;
                                    sendData();
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: keepSignedIn,
                                          activeColor: AppColors.primary,
                                          onChanged: (val) => setState(
                                              () => keepSignedIn = val ?? false),
                                        ),
                                        const Text(
                                          'Keep me logged in',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const ForgotPasswordPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                isLoading
                                    ? const Center(
                                        child: SizedBox(
                                          height: 32,
                                          width: 32,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.6,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: isLoading ? null : sendData,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: const Text('Login'),
                                        ),
                                      ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.grey.withOpacity(0.25),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "New to PFS?",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        height: 1,
                                        color: Colors.grey.withOpacity(0.25),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      "Don't have an account?",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const SignUpPage(),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Sign up',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
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
