import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:http/http.dart' as http;
import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/PendingPage.dart';
import 'package:pfs_agent/pages/verify.dart';

import '../config/api_config.dart';
import 'login.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final Color orange = const Color(0xFFFF6600);

  // Background image to match system
  final String _backgroundImage = 'assets/images/back.jpeg';

  // page controllers
  final TextEditingController firstName = TextEditingController();
  final TextEditingController middleName = TextEditingController();
  final TextEditingController surnameName = TextEditingController();
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
  String?
  _region; // now will be one of: north, central-east, central-west, south-east, south-west

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  int pageNumber = 0; // 0..4
  bool isLoading = false;

  String result = "result";

  String? _selectedBank;

  final List<String> _banks = [
    "National Bank",
    "Standard Bank",
    "Unayo Standard Bank",
    "FCB",
    "FDH",
    "CDH",
    "Centenary Bank",
    "NBS",
    "Ecobank",
  ];

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
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
            if (navigateToVerify) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => VerifyPage(email: email.text.trim())),
              );
            }
          });
        }

        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: const EdgeInsets.all(24),
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

  // ---------- PAGE CONTROL ----------
  void nextPage() {
    setState(() {
      if (pageNumber < 4) {
        pageNumber++;
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PendingPage()),
        );
      }
    });
  }

  void previousPage() {
    setState(() {
      if (pageNumber > 0) pageNumber--;
    });
  }

  /// 🔒 VALIDATION: don't allow moving forward until step is valid
  bool _validateCurrentStep() {
    List<String> missing = [];

    switch (pageNumber) {
      // ---------- STEP 0: Personal details ----------
      case 0:
        if (firstName.text.trim().isEmpty) {
          missing.add("First Name");
        }
        if (surnameName.text.trim().isEmpty) {
          missing.add("Surname");
        }
        if (email.text.trim().isEmpty) {
          missing.add("Email");
        }

        if (missing.isNotEmpty) {
          _showWarningDialog(
            "Please fill the following fields:\n${missing.join(', ')}.",
          );
          return false;
        }

        // Extra: email format
        if (!email.text.contains('@') || !email.text.contains('.')) {
          _showWarningDialog("Please enter a valid email address.");
          return false;
        }
        return true;

      // ---------- STEP 1: Contact & security ----------
      case 1:
        if (phone.text.trim().isEmpty) {
          missing.add("Phone Number");
        }
        if (password.text.trim().isEmpty) {
          missing.add("Password");
        }
        if (confirmPassword.text.trim().isEmpty) {
          missing.add("Confirm Password");
        }
        if (_selectedGender == null) {
          missing.add("Gender");
        }

        if (missing.isNotEmpty) {
          _showWarningDialog(
            "Please fill the following fields:\n${missing.join(', ')}.",
          );
          return false;
        }

        if (password.text.trim().length < 8) {
          _showWarningDialog("Password should be at least 8 characters long.");
          return false;
        }
        if (password.text.trim() != confirmPassword.text.trim()) {
          _showWarningDialog("Password and confirm password do not match.");
          return false;
        }
        return true;

      // ---------- STEP 2: Identity information ----------
      case 2:
        if (idNumber.text.trim().isEmpty) {
          missing.add("Identity Number");
        }
        if (dateOfBirth.text.trim().isEmpty) {
          missing.add("Date Of Birth");
        }
        if (_maritalStatus == null) {
          missing.add("Marital Status");
        }

        if (missing.isNotEmpty) {
          _showWarningDialog(
            "Please fill the following fields:\n${missing.join(', ')}.",
          );
          return false;
        }
        return true;

      // ---------- STEP 3: Address information ----------
      case 3:
        if (_region == null) {
          missing.add("Region");
        }

        if (missing.isNotEmpty) {
          _showWarningDialog(
            "Please fill the following fields:\n${missing.join(', ')}.",
          );
          return false;
        }
        return true;

      // ---------- STEP 4: Banking information ----------
      case 4:
        if (bankAccountName.text.trim().isEmpty) {
          missing.add("Bank Account Name");
        }
        if (bankAccountNumber.text.trim().isEmpty) {
          missing.add("Bank Account Number");
        }
        if (branch.text.trim().isEmpty) {
          missing.add("Branch");
        }

        if (missing.isNotEmpty) {
          _showWarningDialog(
            "Please fill the following fields:\n${missing.join(', ')}.",
          );
          return false;
        }
        return true;

      default:
        return true;
    }
  }

  Future<void> sendData() async {
    // Final guard: ensure last step is valid
    if (!_validateCurrentStep()) return;

    const String url = ApiConfig.baseUrl + "/agent";

    // Map selections to backend-safe values
    String gender = (_selectedGender ?? 'Male').toLowerCase(); // male/female
    String identityType = _selectedId == null
        ? "national_id"
        : _selectedId!.toLowerCase();

    String marital;
    switch (_maritalStatus) {
      case "Married":
        marital = "married";
        break;
      case "Divorced":
        marital = "divorced";
        break;
      case "Widowed":
        marital = "widowed";
        break;
      default:
        marital = "single";
    }

    // 🔹 Region now comes directly from radio: north, central-east, central-west, south-east, south-west
    String region = _region ?? 'north';

    final Map<String, dynamic> data = {
      "first_name": firstName.text.trim(),
      "middle_name": middleName.text.trim(),
      "last_name": surnameName.text.trim(),
      "email": email.text.trim(),
      "phone": phone.text.trim(),
      "gender": gender,
      "identity_type": "national_id",
      "identity_type_number": idNumber.text.trim(),
      "marital_status": marital,
      "date_joined":
          "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}",
      "date_of_birth": dateOfBirth.text.trim(),
      "postal_code": postalCode.text.trim(),
      "postal_town": postalTown.text.trim(),
      "bank_account_name": bankAccountName.text.trim(),
      "bank_account_number": bankAccountNumber.text.trim(),
      "branch": branch.text.trim(),
      "region": region,
      "password": password.text.trim(),
      "password_confirmation": confirmPassword.text.trim(),
    };
    final String trimmedPostalAddress = postalAddress.text.trim();
    if (trimmedPostalAddress.isNotEmpty) {
      data["postal_address"] = trimmedPostalAddress;
    }

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
        body = jsonDecode(response.body);
      }

     

if (response.statusCode == 201) {
  final message = body?['message'] ??
      "Account created successfully. Please verify your email.";

  _showAlert(
    icon: Icons.check_circle,
    color: Colors.green,
    message: message,
    autoClose: true,
    navigateToVerify: true,
  );



        
      } else {
        result = "Request failed (\${response.statusCode})";
        _showWarningDialog(result);
      }
    } catch (e) {
      result = "Connect to the internet and try again.";
      _showWarningDialog(result);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------- WARNING DIALOG ----------
  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Warning",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                "OK",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------- FIELD DECORATION ----------
  InputDecoration _fieldDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.primary, size: 20)
          : null,
      isDense: true,
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.textSecondary.withOpacity(0.18),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero background
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 220,
              child: Image.asset(_backgroundImage, fit: BoxFit.cover),
            ),
          ),

          // Dark gradient overlay
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 220,
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
                // HEADER TEXT
                Positioned(
                  top: 100,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Become a Pinnacle Agent",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Complete the registration in a few simple steps.\nYour details help us manage your profile and payouts.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // MAIN CONTENT (bottom sheet)
                Positioned(
                  top: size.height * 0.26,
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
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _buildCard(),
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

  // ---------- MAIN CARD ----------
  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon + title
          Row(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _pageTitle(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                "Step ${pageNumber + 1} of 5",
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStepIndicator(),
          const SizedBox(height: 16),
          Text(
            _pageSubtitle(),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Page content
          _buildPageContent(),

          const SizedBox(height: 18),

          // Bottom nav buttons / submit / loading
          if (pageNumber < 4) _buildNavButtons() else _buildSubmitRow(),
        ],
      ),
    );
  }

  // ---------- STEP INDICATOR ----------
  Widget _buildStepIndicator() {
    const int totalSteps = 5;

    return Row(
      children: List.generate(totalSteps, (index) {
        final bool isActive = index == pageNumber;
        final bool isCompleted = index < pageNumber;

        Color color;
        if (isCompleted) {
          color = AppColors.primary;
        } else if (isActive) {
          color = AppColors.primary.withOpacity(0.9);
        } else {
          color = AppColors.textSecondary.withOpacity(0.25);
        }

        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  String _pageTitle() {
    switch (pageNumber) {
      case 0:
        return "Personal details";
      case 1:
        return "Contact & security";
      case 2:
        return "Identity information";
      case 3:
        return "Address information";
      case 4:
        return "Banking information";
      default:
        return "Registration";
    }
  }

  String _pageSubtitle() {
    switch (pageNumber) {
      case 0:
        return "Tell us who you are so we can create your profile.";
      case 1:
        return "Provide your contact details and secure your account.";
      case 2:
        return "We use your identity information for KYC verification.";
      case 3:
        return "Address details help us assign you to the right region.";
      case 4:
        return "Banking details are used only for your commission payouts.";
      default:
        return "";
    }
  }

  // ---------- PAGE CONTENT SWITCH ----------
  Widget _buildPageContent() {
    switch (pageNumber) {
      case 0:
        return _buildPage0();
      case 1:
        return _buildPage1();
      case 2:
        return _buildPage2();
      case 3:
        return _buildPage3();
      case 4:
        return _buildPage4();
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------- PAGE 0 ----------
  Widget _buildPage0() {
    return Column(
      children: [
        _textField(firstName, 'First Name', Icons.person_outline),
        const SizedBox(height: 12),
        _textField(middleName, 'Middle Name (optional)', Icons.person_outline),
        const SizedBox(height: 12),
        _textField(surnameName, 'Surname', Icons.person_outline),
        const SizedBox(height: 12),
        _textField(email, 'Email', Icons.email_outlined),
      ],
    );
  }

  // ---------- PAGE 1 ----------
  Widget _buildPage1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntlPhoneField(
          controller: phone,
          decoration: _fieldDecoration(
            'Phone Number',
            icon: Icons.phone_outlined,
          ),
          initialCountryCode: 'MW',
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        _passwordField(password, 'Password'),
        const SizedBox(height: 12),
        _confirmPasswordField(),
        const SizedBox(height: 18),
        _sectionTitle("Gender"),
        const SizedBox(height: 4),
        _radio(
          "Male",
          _selectedGender,
          (v) => setState(() => _selectedGender = v),
        ),
        _radio(
          "Female",
          _selectedGender,
          (v) => setState(() => _selectedGender = v),
        ),
      ],
    );
  }

  // ---------- PAGE 2 ----------
  Widget _buildPage2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(idNumber, 'Identity Number', Icons.badge_outlined),
        const SizedBox(height: 12),
        _dateOfBirthField(),
        const SizedBox(height: 16),
        _sectionTitle("Marital Status"),
        const SizedBox(height: 4),
        _radio(
          "Single",
          _maritalStatus,
          (v) => setState(() => _maritalStatus = v),
          value: "single",
        ),
        _radio(
          "Married",
          _maritalStatus,
          (v) => setState(() => _maritalStatus = v),
          value: "married",
        ),
        _radio(
          "Divorced",
          _maritalStatus,
          (v) => setState(() => _maritalStatus = v),
          value: "divorced",
        ),
        _radio(
          "Widowed",
          _maritalStatus,
          (v) => setState(() => _maritalStatus = v),
          value: "widowed",
        ),
      ],
    );
  }

  // ---------- PAGE 3 ----------
  Widget _buildPage3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(postalAddress, 'Postal Address (optional)', Icons.home_outlined),
        const SizedBox(height: 12),
        _textField(
          postalCode,
          'Postal Code (optional)',
          Icons.local_post_office_outlined,
        ),
        const SizedBox(height: 12),
        _textField(
          postalTown,
          'Postal Town (optional)',
          Icons.location_city_outlined,
        ),
        const SizedBox(height: 16),
        _sectionTitle("Region"),
        const SizedBox(height: 4),
        // 🔹 New region options: values are exactly what backend expects
        _radio(
          "North",
          _region,
          (v) => setState(() => _region = v),
          value: "north",
        ),
        _radio(
          "Central-East",
          _region,
          (v) => setState(() => _region = v),
          value: "central-east",
        ),
        _radio(
          "Central-West",
          _region,
          (v) => setState(() => _region = v),
          value: "central-west",
        ),
        _radio(
          "South-East",
          _region,
          (v) => setState(() => _region = v),
          value: "south-east",
        ),
        _radio(
          "South-West",
          _region,
          (v) => setState(() => _region = v),
          value: "south-west",
        ),
      ],
    );
  }

  // ---------- PAGE 4 ----------

  Widget _dropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.textSecondary,
      ),
      decoration: _fieldDecoration(label, icon: icon),
      dropdownColor: AppColors.cardBackground,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      borderRadius: BorderRadius.circular(14),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildPage4() {
    return Column(
      children: [
        _dropdownField(
          label: 'Bank Name',
          value: _selectedBank,
          items: _banks,
          icon: Icons.account_balance_outlined,
          onChanged: (value) {
            setState(() {
              _selectedBank = value;
              bankAccountName.text = value ?? "";
            });
          },
        ),
        const SizedBox(height: 12),

        _textField(
          bankAccountNumber,
          'Bank Account Number',
          Icons.confirmation_number_outlined,
        ),
        const SizedBox(height: 12),

        _textField(branch, 'Branch', Icons.location_on_outlined),
      ],
    );
  }

  // ---------- FIELD BUILDERS ----------
  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      textCapitalization: TextCapitalization.words,
      controller: controller,
      decoration: _fieldDecoration(label, icon: icon),
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
    );
  }

  Widget _passwordField(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      obscureText: _obscurePassword,
      decoration: _fieldDecoration(label, icon: Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: AppColors.textSecondary,
          ),
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
      decoration: _fieldDecoration('Confirm Password', icon: Icons.lock_outline)
          .copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: () => setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              }),
            ),
          ),
    );
  }

  Widget _dateOfBirthField() {
    return TextFormField(
      controller: dateOfBirth,
      readOnly: true,
      decoration: _fieldDecoration(
        'Date Of Birth (YYYY-MM-DD)',
        icon: Icons.calendar_today_outlined,
      ),
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime(1995, 1, 1),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );

        if (pickedDate != null) {
          setState(() {
            dateOfBirth.text =
                "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
          });
        }
      },
    );
  }

  // ---------- RADIO HELPERS ----------
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _radio(
    String displayText,
    String? group,
    Function(String?) onChanged, {
    String? value,
  }) {
    final val = value ?? displayText;
    return RadioListTile<String>(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        displayText,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
      ),
      value: val,
      groupValue: group,
      activeColor: AppColors.primary,
      onChanged: onChanged,
    );
  }

  // ---------- NAV / SUBMIT BUTTON ROWS ----------
  Widget _buildNavButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (pageNumber > 0)
          OutlinedButton(
            onPressed: previousPage,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: BorderSide(color: AppColors.textSecondary.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text("Previous"),
          )
        else
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text(
              "Back to login",
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            if (_validateCurrentStep()) {
              nextPage();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text("Next"),
        ),
      ],
    );
  }

  Widget _buildSubmitRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton(
          onPressed: previousPage,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: BorderSide(color: AppColors.textSecondary.withOpacity(0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          child: const Text("Previous"),
        ),
        isLoading
            ? const SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppColors.primary,
                ),
              )
            : ElevatedButton(
                onPressed: () {
                  if (_validateCurrentStep()) {
                    sendData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text("Submit"),
              ),
      ],
    );
  }
}
