import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:pfs_agent/pages/Home.dart';
import 'package:pfs_agent/pages/Splash.dart';
import 'package:pfs_agent/pages/login.dart';
import 'package:pfs_agent/pages/reset_password.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(241, 104, 49, 1)),
        useMaterial3: true,
      ),
      // home: ResetPasswordPage(email: "user@example.com"),
      home: Splash(), 
    );
  }
}