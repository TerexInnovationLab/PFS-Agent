import 'package:flutter/material.dart';
import 'package:pfs_agent/pages/Home.dart';
import 'package:pfs_agent/pages/login.dart';

import 'package:shared_preferences/shared_preferences.dart';

class Splash extends StatefulWidget {
  @override
  SplashState createState() => SplashState();
}

class SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final int dotCount = 5;
  final Color dotColor = Colors.orange;
  final double dotSize = 14.0;

  @override
  void initState() {
    super.initState();

    // 1. Start the animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // 2. Start the initialization process
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for 3 seconds so the user sees your splash animation
    await Future.delayed(const Duration(seconds: 3));

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the preference (default to false if it doesn't exist)
    bool isKeepSignedIn = prefs.getBool('keep_me_logged_in') ?? false;
    String? token = prefs.getString('token');

    if (!mounted) return;

    // Navigate based on BOTH the checkbox AND the presence of a token
    if (isKeepSignedIn && token != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => Home()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Image.asset(
                "assets/images/logo.jpeg",
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 25),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(dotCount, (i) {
                    double t = (_controller.value * dotCount);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (t.floor() % dotCount == i)
                            ? dotColor.withOpacity(0.4)
                            : dotColor,
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
