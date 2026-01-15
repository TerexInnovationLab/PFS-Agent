import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:http/http.dart' as http;
import 'package:pfs_agent/pages/PendingPage.dart';
import 'package:pfs_agent/pages/verify.dart';

import 'login.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final Color orange = const Color(0xFFFF6600);

  // page controllers
  final TextEditingController fullName = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();

  final TextEditingController idNumber = TextEditingController();
  final TextEditingController dateOfBirth = TextEditingController();

  final TextEditingController postalAddress = TextEditingController();
  final TextEditingController postalCode = TextEditingController();
  final TextEditingController postalTown = TextEditingController();

  final TextEditingController bankAccountName = TextEditingController();
  final TextEditingController bankAccountNumber = TextEditingController();
  final TextEditingController branch = TextEditingController();

  // selections
  String? _selectedGender;
  String? _selectedId;
  String? _maritalStatus;
  String? _region;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  int pageNumber = 1;
  bool isLoading = false;

  // ---------- ALERT ----------
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
          Future.delayed(const Duration(seconds: 2), () {
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
              Text(message,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }

  // ---------- PAGE CONTROL ----------
  void nextPage() {
    setState(() {
      pageNumber++;
      if (pageNumber == 5) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PendingPage()),
        );
      }
    });
  }

  void previousPage() {
    setState(() => pageNumber--);
  }

  // ---------- SUBMIT ----------
  Future<void> submitRegistration() async {
    if (
    fullName.text.isEmpty ||
        email.text.isEmpty ||
        phone.text.isEmpty ||
        password.text.isEmpty ||
        confirmPassword.text.isEmpty ||
        _selectedGender == null ||
        _selectedId == null ||
        idNumber.text.isEmpty ||
        dateOfBirth.text.isEmpty ||
        _maritalStatus == null ||
        postalAddress.text.isEmpty ||
        postalCode.text.isEmpty ||
        postalTown.text.isEmpty ||
        bankAccountName.text.isEmpty ||
        bankAccountNumber.text.isEmpty ||
        branch.text.isEmpty ||
        _region == null
    ) {
      _showAlert(
        icon: Icons.warning_amber_rounded,
        color: Colors.orange,
        message: "Please fill in all required fields.",
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

    setState(() => isLoading = true);

    final url =
    Uri.parse("https://terexlab.com/pinnacle-react/public/api/agent");

    final nameParts = fullName.text.trim().split(" ");
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.last : "";
    final middleName =
    nameParts.length > 2 ? nameParts.sublist(1, nameParts.length - 1).join(" ") : "";

    final data ={
      "first_name": "John",
      "middle_name": "Alexander",
      "last_name": "Doe",
      "email": "john.doe@example.com",
      "phone": "0999123456",
      "gender": "male",
      "identity_type": "national_id",
      "identity_type_number": "123456789",
      "marital_status": "single",
      "date_joined": "2025-01-15",
      "date_of_birth": "1995-04-20",
      "postal_address": "P.O. Box 123",
      "postal_code": "20100",
      "postal_town": "Lilongwe",
      "bank_account_name": "John A. Doe",
      "bank_account_number": "9876543210",
      "branch": "City Centre Branch",
      "region": "north",
      "password": "password123",
      "password_confirmation": "password123"
    };

    try {
      final response = await http.post(
        url,
        body: jsonEncode(data),
        headers: {"Content-Type": "application/json"},
      );

      setState(() => isLoading = false);

      if (response.statusCode == 201) {
        _showAlert(
          icon: Icons.check_circle,
          color: Colors.green,
          message: "Registration Successful",
          navigateToVerify: true,
        );
      } else {
        _showAlert(
          icon: Icons.error,
          color: Colors.red,
          message: "Failed to register. Code: ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() => isLoading = false);

      _showAlert(
        icon: Icons.error,
        color: Colors.red,
        message: "Network error: $e",
      );
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/orange background.jpg',
              fit: BoxFit.cover),

          if (pageNumber == 1)
            _scrollPage(_buildPage1(), screenHeight),

          if (pageNumber == 2)
            _scrollPage(_buildPage2(), screenHeight),

          if (pageNumber == 3)
            _scrollPage(_buildPage3(), screenHeight),

          if (pageNumber == 4)
            _scrollPage(_buildPage4(), screenHeight),
        ],
      ),
    );
  }

  Widget _scrollPage(Widget child, double height) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: height * 0.12,
      ),
      child: Center(child: child),
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

  // ---------- PAGE 1 ----------
  Widget _buildPage1() {
    return _card(
      Column(
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
          ),

          const SizedBox(height: 16),
          _passwordField(password, 'Password'),
          const SizedBox(height: 16),
          _confirmPasswordField(),

          const SizedBox(height: 20),
          _radioTitle("Gender"),

          _radio("Male", _selectedGender, (v) => setState(() => _selectedGender = v)),
          _radio("Female", _selectedGender, (v) => setState(() => _selectedGender = v)),

          const SizedBox(height: 24),
          _nextButton(),
        ],
      ),
    );
  }

  // ---------- PAGE 2 ----------
  Widget _buildPage2() {
    return _card(
      Column(
        children: [
          const Text('Identity Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          _radioTitle("Identity Type"),
          _radio("National ID", _selectedId, (v) => setState(() => _selectedId = v)),
          _radio("School ID", _selectedId, (v) => setState(() => _selectedId = v)),

          _inputField(idNumber, 'Identity Number', Icons.badge),
          _inputField(dateOfBirth, 'Date of Birth (YYYY-MM-DD)', Icons.calendar_today),

          _radioTitle("Marital Status"),
          _radio("Married", _maritalStatus, (v) => setState(() => _maritalStatus = v)),
          _radio("Not Married", _maritalStatus, (v) => setState(() => _maritalStatus = v)),

          const SizedBox(height: 20),
          _navButtons(),
        ],
      ),
    );
  }

  // ---------- PAGE 3 ----------
  Widget _buildPage3() {
    return _card(
      Column(
        children: [
          const Text('Address Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          _inputField(postalAddress, 'Postal Address', Icons.home),
          _inputField(postalCode, 'Postal Code', Icons.code),
          _inputField(postalTown, 'Postal Town', Icons.location_city),

          _radioTitle("Region"),
          _radio("Northen Region", _region, (v) => setState(() => _region = v)),
          _radio("Central Region", _region, (v) => setState(() => _region = v)),
          _radio("Southern Region", _region, (v) => setState(() => _region = v)),

          const SizedBox(height: 20),
          _navButtons(),
        ],
      ),
    );
  }

  // ---------- PAGE 4 ----------
  Widget _buildPage4() {
    return _card(
      Column(
        children: [
          const Text('Banking Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          _inputField(bankAccountName, 'Bank Account Name', Icons.account_balance),
          _inputField(bankAccountNumber, 'Bank Account Number', Icons.confirmation_number),
          _inputField(branch, 'Branch', Icons.location_on),

          const SizedBox(height: 20),
          _submitButtons(),
        ],
      ),
    );
  }

  // ---------- COMPONENTS ----------
  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10),
        ],
      ),
      child: child,
    );
  }

  Widget _passwordField(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock),
        border: OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() {
            _obscurePassword = !_obscurePassword;
          }),
        ),
      ),
    );
  }

  Widget _confirmPasswordField() {
    return TextFormField(
      controller: confirmPassword,
      obscureText: _obscureConfirmPassword,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        prefixIcon: Icon(Icons.lock_outline),
        border: OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() {
            _obscureConfirmPassword = !_obscureConfirmPassword;
          }),
        ),
      ),
    );
  }

  Widget _radioTitle(String text) =>
      Container(width: double.infinity, child: Text(text, style: TextStyle(fontSize: 20)));

  Widget _radio(String text, String? group, Function(String?) onChanged) {
    return RadioListTile<String>(
      title: Text(text),
      value: text,
      groupValue: group,
      onChanged: onChanged,
    );
  }

  Widget _navButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _smallButton("Previous", previousPage),
        _smallButton("Next", nextPage),
      ],
    );
  }

  Widget _nextButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: _smallButton("Next", nextPage),
    );
  }

  Widget _submitButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _smallButton("Previous", previousPage),
        _smallButton("Submit", submitRegistration),
      ],
    );
  }

  Widget _smallButton(String text, Function() action) {
    return GestureDetector(
      onTap: action,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: orange,
        ),
        child: Text(
          text,
          style:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
