import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pfs_agent/Sing Up.dart';
import 'package:pfs_agent/verify.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Color orange = const Color(0xFFFF6600);
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool keepSignedIn = false;
  bool passwordVisible = false;
  bool isLoading = false;

  void _handleLogin() async {
    if (username.text.isEmpty || password.text.isEmpty) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        message: "Username and password must not be empty.",
      );
      return;
    }

    setState(() => isLoading = true);
    await Future.delayed(const Duration(seconds: 4));
    setState(() => isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VerifyPage()),
    );
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

  void _showAlert({
    required IconData icon,
    required Color color,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.of(dialogContext).pop();
        });

        return AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 80),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Background image (covers all phones)
          Positioned.fill(
            child: Image.asset(
              'assets/images/orange background.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // Overlay for readability
          Container(
            color: Colors.black.withOpacity(0.25),
          ),

          // Scrollable Login Form
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.08,
                vertical: screenHeight * 0.04,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 420,
                  minWidth: 280,
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PFS Login',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Username field
                      TextField(
                        controller: username,
                        decoration: const InputDecoration(
                          labelText: 'Username / Phone Number',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextField(
                        controller: password,
                        obscureText: !passwordVisible,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              passwordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                                () => passwordVisible = !passwordVisible),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ),

                      CheckboxListTile(
                        value: keepSignedIn,
                        onChanged: (val) =>
                            setState(() => keepSignedIn = val ?? false),
                        title: const Text('Keep me signed in'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 16),
                      isLoading
                          ? const CircularProgressIndicator()
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: orange,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                      const SizedBox(height: 24),
                      const Text(
                        'Or Sign In Using',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),

                      // Social login icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _handleSocialLogin,
                            child: Icon(Icons.facebook,
                                color: Colors.blue, size: 32),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: _handleSocialLogin,
                            child: Image.asset(
                              'assets/icons/google.png',
                              width: 32,
                              height: 32,
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: _handleSocialLogin,
                            child: Image.asset(
                              'assets/icons/x_logo.png',
                              width: 32,
                              height: 32,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: Colors.black),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(color: Colors.orange),
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
        ],
      ),
    );
  }
}
