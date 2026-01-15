// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// import '../layouts/Colors.dart';
// import 'Home.dart';
// import '../config/api_config.dart';

// class ResetPasswordPage extends StatefulWidget {
//   final String email;

//   const ResetPasswordPage({super.key, required this.email});

//   @override
//   State<ResetPasswordPage> createState() => _ResetPasswordPageState();
// }

// class _ResetPasswordPageState extends State<ResetPasswordPage> {
//   final TextEditingController otpController = TextEditingController();
//   final TextEditingController newPasswordController = TextEditingController();
//   final TextEditingController confirmPasswordController = TextEditingController();

//   bool otpVerified = false;
//   bool obscureOtp = true;
//   bool obscureNew = true;
//   bool obscureConfirm = true;
//   bool isLoading = false;

//   String? newPasswordError;
//   String? confirmPasswordError;

//   final String _backgroundImage = 'assets/images/back.jpeg';

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _showOtpDialog();
//     });
//   }

//   // ================= OTP DIALOG =================
//   Future<void> _showOtpDialog() async {
//     String? errorText;

//     await showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return StatefulBuilder(builder: (context, setDialogState) {
//           return AlertDialog(
//             backgroundColor: AppColors.cardBackground,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(18),
//             ),
//             title: Row(
//               children: [
//                 Container(
//                   height: 32,
//                   width: 32,
//                   decoration: BoxDecoration(
//                     color: AppColors.primary.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Icon(
//                     Icons.lock_outline,
//                     size: 18,
//                     color: AppColors.primary,
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 const Text(
//                   'Verify OTP',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w700,
//                     color: AppColors.textPrimary,
//                   ),
//                 ),
//               ],
//             ),
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Enter the OTP sent to your email.',
//                   style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
//                 ),
//                 const SizedBox(height: 12),
//                 TextField(
//                   controller: otpController,
//                   keyboardType: TextInputType.number,
//                   obscureText: obscureOtp,
//                   cursorColor: AppColors.primary,
//                   decoration: _inputDecoration(
//                     label: "OTP",
//                     errorText: errorText,
//                     suffixIcon: IconButton(
//                       icon: Icon(
//                         obscureOtp ? Icons.visibility_off : Icons.visibility,
//                       ),
//                       onPressed: () => setDialogState(() => obscureOtp = !obscureOtp),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             actions: [
//               ElevatedButton(
//                 onPressed: () async {
//                   if (otpController.text.trim().isEmpty) {
//                     setDialogState(() {
//                       errorText = "OTP is required";
//                     });
//                     return;
//                   }

//                   // 🔹 Verify OTP with backend
//                   setDialogState(() => errorText = null);
//                   final otp = int.tryParse(otpController.text.trim());
//                   if (otp == null) {
//                     setDialogState(() {
//                       errorText = "Invalid OTP format";
//                     });
//                     return;
//                   }

//                   try {
//                     final response = await http.post(
//                       Uri.parse(ApiConfig.baseUrl + "/reset-password"),
//                       headers: {
//                         "Content-Type": "application/json",
//                         "Accept": "application/json",
//                       },
//                       body: jsonEncode({
//                         "email": widget.email,
//                         "otp": otp,
//                       }),
//                     );

//                     final data = jsonDecode(response.body);
//                     if (response.statusCode == 200 && data["status"] == true) {
//                       // OTP verified successfully
//                       setState(() => otpVerified = true);
//                       Navigator.of(context).pop();
//                     } else {
//                       // Show inline error without closing dialog
//                       setDialogState(() {
//                         errorText = data["message"] ?? "Invalid OTP";
//                       });
//                     }
//                   } catch (_) {
//                     setDialogState(() {
//                       errorText = "Network error. Please try again.";
//                     });
//                   }
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: AppColors.primary,
//                   foregroundColor: Colors.white,
//                   elevation: 0,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                 ),
//                 child: const Text("Verify"),
//               ),
//             ],
//           );
//         });
//       },
//     );
//   }

//   // ================= RESET PASSWORD =================
//   Future<void> _resetPassword() async {
//     final newPassword = newPasswordController.text.trim();
//     final confirmPassword = confirmPasswordController.text.trim();
//     final otp = otpController.text.trim();

//     setState(() {
//       newPasswordError = null;
//       confirmPasswordError = null;
//     });

//     if (newPassword.isEmpty) {
//       setState(() => newPasswordError = "Password is required");
//       return;
//     }
//     if (newPassword.length < 6) {
//       setState(() => newPasswordError = "Minimum 6 characters");
//       return;
//     }
//     if (confirmPassword != newPassword) {
//       setState(() => confirmPasswordError = "Passwords do not match");
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final response = await http.post(
//         Uri.parse(ApiConfig.baseUrl + "/reset-password"),
//         headers: {"Content-Type": "application/json", "Accept": "application/json"},
//         body: jsonEncode({
//           "email": widget.email,
//           "otp": int.parse(otp),
//           "password": newPassword,
//           "password_confirmation": confirmPassword,
//         }),
//       );

//       final data = jsonDecode(response.body);
//       if (response.statusCode == 200 && data["status"] == true) {
//         // ✅ Reset successful → login user automatically
//         await _loginUser(widget.email, newPassword);
//       } else {
//         _showErrorDialog(data["message"] ?? "Password reset failed");
//       }
//     } catch (_) {
//       _showErrorDialog("Network error. Please try again.");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // ================= LOGIN AFTER RESET =================
//   Future<void> _loginUser(String email, String password) async {
//     setState(() => isLoading = true);
//     try {
//       const String url = ApiConfig.baseUrl + "/login";
//       final Map<String, dynamic> data = {"email": email, "password": password};

//       final response = await http.post(
//         Uri.parse(url),
//         headers: {"Content-Type": "application/json", "Accept": "application/json"},
//         body: jsonEncode(data),
//       );

//       Map<String, dynamic>? body;
//       if (response.body.isNotEmpty) {
//         body = jsonDecode(response.body);
//       }

//       if (body != null && body['status'] == true && body['token'] != null) {
//         await _saveUserSession(body, password);
//         if (!mounted) return;
//         Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Home()));
//       } else {
//         _showErrorDialog(body?['message'] ?? "Login failed.");
//       }
//     } catch (e) {
//       _showErrorDialog("Network error: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   // ================= SAVE SESSION =================
//   Future<void> _saveUserSession(Map<String, dynamic> responseData, String password) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setString('token', responseData['token']);
//     await prefs.setString('user_data', jsonEncode(responseData['user']));
//     await prefs.setBool('keep_me_logged_in', true);
//     await prefs.setString("password", password);
//     print("Session saved: Token and User Data stored locally.");
//   }

//   // ================= ERROR DIALOG =================
//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (_) => AlertDialog(
//         backgroundColor: AppColors.cardBackground,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircleAvatar(
//               radius: 32,
//               backgroundColor: AppColors.danger.withOpacity(0.12),
//               child: const Icon(Icons.error, color: AppColors.danger, size: 36),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               message,
//               textAlign: TextAlign.center,
//               style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ================= INPUT DECORATION =================
//   InputDecoration _inputDecoration({required String label, String? errorText, Widget? suffixIcon}) {
//     return InputDecoration(
//       labelText: label,
//       labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
//       isDense: true,
//       errorText: errorText,
//       filled: true,
//       fillColor: AppColors.background,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       suffixIcon: suffixIcon,
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: BorderSide(color: AppColors.textSecondary.withOpacity(0.18), width: 1),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
//       ),
//       errorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
//       ),
//       focusedErrorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
//       ),
//     );
//   }

//   // ================= UI =================
//   @override
//   Widget build(BuildContext context) {
//     return AnnotatedRegion<SystemUiOverlayStyle>(
//       value: SystemUiOverlayStyle.light,
//       child: Scaffold(
//         backgroundColor: AppColors.background,
//         body: Stack(
//           children: [
//             SizedBox(height: 220, width: double.infinity, child: Image.asset(_backgroundImage, fit: BoxFit.cover)),
//             SafeArea(
//               child: Column(
//                 children: [
//                   const SizedBox(height: 100),
//                   Expanded(
//                     child: Container(
//                       padding: const EdgeInsets.all(20),
//                       decoration: const BoxDecoration(
//                         color: AppColors.background,
//                         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//                       ),
//                       child: otpVerified
//                           ? Card(
//                               color: AppColors.cardBackground,
//                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                               elevation: 2,
//                               child: Padding(
//                                 padding: const EdgeInsets.all(20),
//                                 child: Column(
//                                   mainAxisSize: MainAxisSize.min,
//                                   children: [
//                                     TextField(
//                                       controller: newPasswordController,
//                                       obscureText: obscureNew,
//                                       decoration: _inputDecoration(
//                                         label: "New Password",
//                                         errorText: newPasswordError,
//                                         suffixIcon: IconButton(
//                                           icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
//                                           onPressed: () => setState(() => obscureNew = !obscureNew),
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 16),
//                                     TextField(
//                                       controller: confirmPasswordController,
//                                       obscureText: obscureConfirm,
//                                       decoration: _inputDecoration(
//                                         label: "Confirm Password",
//                                         errorText: confirmPasswordError,
//                                         suffixIcon: IconButton(
//                                           icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
//                                           onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 24),
//                                     SizedBox(
//                                       width: double.infinity,
//                                       child: ElevatedButton(
//                                         onPressed: isLoading ? null : _resetPassword,
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: AppColors.primary,
//                                           foregroundColor: Colors.white,
//                                           padding: const EdgeInsets.symmetric(vertical: 14),
//                                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                                         ),
//                                         child: isLoading
//                                             ? const SizedBox(
//                                                 height: 20,
//                                                 width: 20,
//                                                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
//                                               )
//                                             : const Text(
//                                                 "Reset Password",
//                                                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                                               ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             )
//                           : const SizedBox(),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
