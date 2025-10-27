import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:pfs_agent/verify.dart';
import 'package:pfs_agent/login.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final Color orange = const Color(0xFFFF6600);
  final _formKey = GlobalKey<FormState>();

  final TextEditingController fullName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  bool termsAccepted = false;
  bool isLoading = false;
  bool passwordVisible = false;
  bool confirmVisible = false;

  void _showAlert({
    required IconData icon,
    required Color color,
    required String message,
    bool autoClose = true,
    bool navigateToVerify = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        if (autoClose) {
          Future.delayed(const Duration(seconds: 3), () {
            Navigator.of(dialogContext).pop();
            if (navigateToVerify) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const VerifyPage()),
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

  void _handleRegister() {
    if (fullName.text.isEmpty ||
        email.text.isEmpty ||
        phone.text.isEmpty ||
        password.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        message: "All fields must be filled.",
      );
      return;
    }

    if (password.text != confirmPassword.text) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        message: "Passwords do not match.",
      );
      return;
    }

    if (!termsAccepted) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        message: "Please accept the Terms and Conditions.",
      );
      return;
    }

    setState(() => isLoading = true);
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => isLoading = false);
      _showAlert(
        icon: Icons.check_circle,
        color: Colors.green,
        message: "Registration successful!",
        navigateToVerify: true,
      );
    });
  }

  void _handleSocialLogin() {
    setState(() => isLoading = true);
    Future.delayed(const Duration(seconds: 3), () {
      setState(() => isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const VerifyPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/orange background.jpg', fit: BoxFit.cover),
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: screenHeight * 0.12, // adds dynamic top and bottom space
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PFS Agent Registration',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    _inputField(fullName, 'Full Name', Icons.person),
                    _inputField(email, 'Email', Icons.email),

                    IntlPhoneField(
                      controller: phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      initialCountryCode: 'MW',
                      keyboardType: TextInputType.phone,
                    ),

                    _passwordInput(password, 'Password', Icons.lock, passwordVisible, () {
                      setState(() => passwordVisible = !passwordVisible);
                    }),
                    _passwordInput(confirmPassword, 'Confirm Password', Icons.lock_outline,
                        confirmVisible, () {
                      setState(() => confirmVisible = !confirmVisible);
                    }),

                    CheckboxListTile(
                      value: termsAccepted,
                      onChanged: (val) => setState(() => termsAccepted = val ?? false),
                      title: const Text('I agree to the Terms and Conditions'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 16),
                    isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('REGISTER',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),

                    const SizedBox(height: 24),
                    const Text('Or Sign Up Using', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _handleSocialLogin,
                          child: Icon(Icons.facebook, color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _handleSocialLogin,
                          child: Image.asset('assets/icons/google.png', width: 32, height: 32),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: _handleSocialLogin,
                          child: Image.asset('assets/icons/x_logo.png', width: 32, height: 32),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?",
                            style: TextStyle(color: Colors.black)),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                          child: const Text('Login', style: TextStyle(color: Colors.orange)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _passwordInput(TextEditingController controller, String label, IconData icon,
      bool visible, VoidCallback toggle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: !visible,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
            onPressed: toggle,
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
