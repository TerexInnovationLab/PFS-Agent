import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/Home.dart';
import 'package:pfs_agent/pages/OTPResetCodePage.dart';
import 'package:pfs_agent/pages/Splash.dart';
import 'package:pfs_agent/pages/login.dart';
import 'package:pfs_agent/pages/reset_password.dart';
import 'package:pfs_agent/pages/verify.dart';

void main() {
  // 2. Ensure bindings are initialized
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  
  // 3. Preserve the native splash screen while the app loads
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    initialization();
  }

  void initialization() async {
    // 4. Set your 2-second delay here
    await Future.delayed(const Duration(seconds: 2));
    
    // 5. Remove the native splash screen to reveal the app
    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PFS Agent',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF16831)),
        useMaterial3: true,

















        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFFDE1D6),

        )
      ),
      // home: ResetPasswordPage(email: "user@example.com", token: "your_token_here"),
      home: Splash(), 
    //  home: OTPResetCodePage(email: "user@example.com"),
    //  home: VerifyPage(email: "user@example.com"), 

    //  home: ResetPasswordPage(),
    );
  }
} 