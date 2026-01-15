import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/MyClients.dart';
import 'package:pfs_agent/pages/ProfilePage.dart';
import 'package:pfs_agent/pages/Statistics.dart';

import 'Chats.dart';
import 'CustomerOnboardingPage.dart';
import 'Leads.dart';
import 'Notification.dart';
import 'Reports.dart';
import 'Settings.dart';
import 'TargetsService.dart';
import 'Vault.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path/path.dart' as p;


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

  late TargetsService _targetsService;

  // Data variables mapped to your UI
  String _category = "---";
  int _commission = 0;
  int _transportIncentive = 0;
  int _targetAmount = 0;
  double _progressPercentage = 0.0;
  int _accumulated = 0;
  String _monthYear = "";
  int total=0;
  int percenta=0;



  bool showBalance = false;

  /// 👉 Simple hardcoded password for earnings.
  /// Change this to whatever you want, or connect it to your auth logic.
  final String _earningsPassword = '1234';

  final List<String> _images = [
    'assets/images/back1.png',
    'assets/images/back2.jpg',
    'assets/images/back3.png',
  ];

  int _currentImageIndex = 0;
  Timer? _timer;

  // 🔹 User profile image (replace with real asset or logic)
  String? _userImageAssetPath = 'assets/images/user_profile.avif';
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userRegion;
  String? _userBank;
  String? _userStatus;
  String? _userId;
  String? password;


  File? _profileImage;
  final ImagePicker _picker = ImagePicker();



  Future<void> printUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 1. Retrieve the JSON string
    String? userJson = prefs.getString('user_data');
    password=prefs.getString('password');

    if (userJson != null) {
      // 2. Decode the string
      Map<String, dynamic> user = jsonDecode(userJson);

      // 3. Update the state variables
      setState(() {
        _userName = "${user['first_name']} ${user['last_name']}";
        _userEmail = "${user['email']}";
        _userPhone = "${user['phone']}";

        // Accessing nested agent data
        if (user['agent'] != null) {
          _userRegion = "${user['agent']['region']}";
          // Using agent_id if available, otherwise falling back to user_id
          _userId = user['agent']['agent_code']?.toString() ?? user['agent']['user_id'].toString();
          _userStatus = "${user['agent']['status']}";
          _userBank = "${user['agent']['bank_account_name']}";
        }
      });

      print("Dashboard Data Loaded: $_userName (ID: $_userId)");
    } else {
      print("No user data found in storage.");
    }
  }


  void Service(){
    _targetsService = TargetsService(
      onDataReceived: (data) {
        if (mounted) {
          setState(() {
            // 1. Assign General Data
            _category = data['category']?.toString() ?? "N/A";
            _commission = data['commission'] ?? 0;
            _monthYear = "${data['month']} ${data['year']}".toUpperCase();

            // 2. Assign Transport and Progress Data
            var transport = data['transport_incentive'];
            if (transport != null) {
              _targetAmount = transport['target'] ?? 0;

              // Using mid_month as the primary tracker
              var midMonth = transport['mid_month'];
              _transportIncentive = midMonth['amount'] ?? 0;
              _progressPercentage = (midMonth['percentage'] ?? 0.0).toDouble();

              _accumulated = transport['accumulated']?['mid_month'] ?? 0;


            }


            total=_transportIncentive+_commission;

            // 1. Assign values using safe casting to 'num'
            int accumulated = (transport['accumulated']?['mid_month'] as num?)?.toInt() ?? 0;
            int target = (transport['target'] as num?)?.toInt() ?? 0;

// 2. Calculate percentage
// We check if target > 0 to avoid "Division by zero" errors
            if (target > 0) {
              // Multiply by 100.0 to ensure double precision before rounding
              percenta = ((accumulated / target) * 100).round();
            } else {
              percenta = 0;
            }
            print(_accumulated);

          });
        }
      },
      onError: (error) {
        debugPrint("Update Error: $error");
      },
    );

    // Start polling every 10 seconds
    _targetsService.startPolling();

  }

  Future<void> _loadSavedImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = p.join(directory.path, 'profile_picker_image.png');
    final savedFile = File(imagePath);

    if (await savedFile.exists()) {
      setState(() {
        _profileImage = savedFile;
      });
    }
  }

  @override
  void initState() {
    super.initState();


    _loadSavedImage();
    setState(() {

      printUserInfo();

    });

    Service();

    // Change image every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (Timer t) {
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel timer when widget is disposed
    super.dispose();
  }

  // =========================================================
  // 🔐 PASSWORD DIALOG & TOGGLE HANDLER
  // =========================================================

  Future<void> _handleToggleBalance() async {
    // If balance is currently hidden and user wants to show it -> ask for password
    if (!showBalance) {
      final bool? success = await _showPasswordDialog();

      if (success == true) {
        setState(() {
          showBalance = true;
        });
      }
    } else {
      // If it's already visible and they tap again -> hide without password
      setState(() {
        showBalance = false;
      });
    }
  }

  Future<bool?> _showPasswordDialog() async {
    final TextEditingController _passwordController = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              actionsPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Row(
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Earnings locked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your password to view the earnings summary.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      isDense: true,
                      errorText: errorText,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.18),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.danger,
                          width: 1.4,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.danger,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_passwordController.text.trim() ==
                        password) {
                      Navigator.of(context).pop(true);
                    } else {
                      setStateDialog(() {
                        errorText = 'Incorrect password';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _showPasswordDialog2() async {
    final TextEditingController _passwordController = TextEditingController();
    String? errorText;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              actionsPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Row(
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Earnings locked',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your password to view the earnings summary.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    cursorColor: AppColors.primary,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      isDense: true,
                      errorText: errorText,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textSecondary.withOpacity(0.18),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.danger,
                          width: 1.4,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.danger,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_passwordController.text.trim() ==
                        password) {


                      Navigator.of(context).pop(true);
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>Statistics()));
                    } else {
                      setStateDialog(() {
                        errorText = 'Incorrect password';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🔹 Rotating background hero image
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 320,
              child: Image.asset(
                _images[_currentImageIndex],
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🔹 Dark gradient overlay
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 320,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xE6000000),
                    Color(0x00000000),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                // 🔹 User info + target card + notifications
                _buildHeader(),

                // 🔹 Earnings cards
                _buildEarningsSection(),

                // 🔹 Main content (Quick Actions)
                _buildMainContent(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= EARNINGS SECTION =================
  Widget _buildEarningsSection() {
    return Positioned(
      top: 175,
      left: 16,
      right: 16,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔹 Header row: title + single eye icon
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
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Earnings summary",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await _handleToggleBalance();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      showBalance
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 🔹 Three columns: Commission | Transport | Amount
            Row(
              children: [
                Expanded(
                  child: _earningColumn(
                    title: "Commission",
                    amount: "K "+_commission.toString(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin:
                  const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.grey.withOpacity(0.3),
                ),
                Expanded(
                  child: _earningColumn(
                    title: "Transport",
                    amount: "K "+_transportIncentive.toString(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  margin:
                  const EdgeInsets.symmetric(horizontal: 8),
                  color: Colors.grey.withOpacity(0.3),
                ),
                Expanded(
                  child: _earningColumn(
                    title: "Total Amount",
                    amount: "K "+ total.toString()
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _earningColumn({
    required String title,
    required String amount,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          showBalance ? amount : 'KX,XXX.xx',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _earningTile({
    required String title,
    required String amount,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min, // 👈 important: no overflow
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      showBalance ? amount : 'KX,XXX.xx',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () async {
                      await _handleToggleBalance();
                    },
                    child: Icon(
                      showBalance
                          ? Icons.visibility
                          : Icons.visibility_off,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ================= HEADER =================

  // avatar builder reused logic
  // ================= HEADER AVATAR =================

  void _showZoomedImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _profileImage != null
                ? Image.file(_profileImage!, fit: BoxFit.contain)
                : const Icon(Icons.person, size: 200, color: Colors.white),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final double size = 40;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white,
          width: 1, // 👈 white border of about 1 size
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: (_profileImage != null &&
            _userImageAssetPath!.isNotEmpty)
            ? Image.file(_profileImage!, fit: BoxFit.contain)
            : Container(
          color: AppColors.accent,
          child: const Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
      ),
    );
  }


  Widget _buildHeader() {
    return Positioned(
      top: 8,
      left: 16,
      right: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ProfilePage()),
              );
            },
            child: _buildAvatar(),
          ),

          const SizedBox(width: 10),

          // Agent info + progress
          Expanded(
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border:
                Border.all(color: Colors.white.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? "Loading...",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Agent ID: ${_userId ?? '---'}",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Monthly Sales Target",
                      style: TextStyle(
                        color:
                        Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTargetProgressBar(),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _category ?? "----",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "MWK "+_targetAmount.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Notification Icon
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Notification1()),
              );
            },
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 30,
                ),
                Positioned(
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                        minWidth: 16, minHeight: 16),
                    child: const Text(
                      '7',
                      style: TextStyle(
                          color: Colors.white, fontSize: 11),
                      textAlign: TextAlign.center,
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

  Widget _buildTargetProgressBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * percenta/100;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Container(
              height: 18,
              width: width,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  percenta.toString()+"%",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================= MAIN CONTENT =================

  Widget _buildMainContent(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.4,
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
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding:
          const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Static "Quick Actions" label
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // 🔹 Only this part scrolls
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              'My Clients',
                              Icons.people_outline,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        MyClients(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionButton(
                              'Chats',
                              Icons.chat_bubble_outline,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                    const Chats(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _actionButton(
                              'Statistics',
                              Icons.insert_chart_outlined,
                              onTap: () {
                                _showPasswordDialog2();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _actionButton(
                              'More',
                              Icons.more_horiz,
                              onTap: () {
                                // Future expansion
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ================= ACTION BUTTON WIDGET =================

  Widget _actionButton(
      String label,
      IconData icon, {
        VoidCallback? onTap,
      }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(18),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppColors.textSecondary
                          .withOpacity(0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
