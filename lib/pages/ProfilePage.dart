import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/login.dart';


import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'TargetsService.dart';
import 'database/digital_registration_db.dart';
import 'database_helper.dart';

import 'package:path/path.dart' as p;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {


  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final String _headerImage = 'assets/images/back1.png';

  int _imageVersion = 0; // Incremented to force Flutter to reload the file

  // TODO: replace this with your real user image path or network URL
  // Example for asset: "assets/images/user_profile.jpg"
  // Example for network: use Image.network instead in _buildAvatar
  String? _userImageAssetPath = "assets/images/user_profile.avif";

  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userRegion;
  String? _userBank;
  String? _userStatus;
  String? _userId;



  int totalclients=0;
  int pendingclients=0;
  int approvedclients=0;
  int rejectedclients=0;
  int bounceclients=0;


  // Load the image from the private app directory on startup
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

  // Pick image and save a copy to the private directory

  Future<void> _pickAndSaveImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'profile_picker_image.png'; // Consistent name to overwrite
      final savedImage = await File(pickedFile.path).copy(p.join(directory.path, fileName));

      setState(() {
        _profileImage = savedImage;
      });
    }
  }

  // Show zoomed image in a dialog
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


  Future<Map<String, int>> _getCombinedStats() async {
    int approved = 0;
    int rejected = 0;
    int bounce = 0;
    int pending = 0;
    int total = 0;

    // 1. Fetch from DigitalRegistrationDb
    final db1List = await DigitalRegistrationDb.instance.getAll();
    for (var item in db1List) {
      final s = item.status.toLowerCase();
      if (s == 'approved') approved++;
      else if (s == 'pending') pending++;
      else if (s == 'rejected' || s == 'denied') rejected++;
      else if (s == 'bounce') bounce++;
    }

    // 2. Fetch from DatabaseHelper
    final db2List = await DatabaseHelper.instance.getData();
    for (var item in db2List) {
      final s = (item[DatabaseHelper.columnStatus] as String? ?? '').toLowerCase();
      if (s == 'approved') approved++;
      else if (s == 'pending') pending++;
      else if (s == 'rejected' || s == 'denied') rejected++;
      else if (s == 'bounce') bounce++;
    }

    total = db1List.length + db2List.length;

    setState(() {

      totalclients=approved+pending+rejected+bounce;
      pendingclients=pending;
      approvedclients=approved;
      rejectedclients=rejected;
      bounceclients=bounce;

    });
    return {
      'Approved': approved,
      'Pending': pending,
      'Rejected': rejected,
      'Bounce': bounce,
      'Total': total,
    };
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


  Future<void> printUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 1. Retrieve the JSON string
    String? userJson = prefs.getString('user_data');

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


  Future<void> _handleLogout(BuildContext context) async {
    // 1. Clear SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // This removes user_data and any other saved keys

    // 2. Navigate and clear the navigation stack
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()), // Replace LoginPage() with your actual login class name
            (route) => false, // This condition 'false' ensures all previous routes are removed
      );
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _loadSavedImage();
    _getCombinedStats();
    Service();
    printUserInfo();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Hero background
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 260,
              child: Image.asset(
                _headerImage,
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Dark gradient overlay
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 260,
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
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 12),

                Expanded(
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
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileHeaderCard(),
                          const SizedBox(height: 16),
                          _buildPerformanceCard(),
                          const SizedBox(height: 16),
                          _buildAccountSection(context),
                          const SizedBox(height: 24),
                          _buildLogoutButton(context),
                        ],
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

  // ================= TOP BAR =================
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              "Profile",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          // This is your Edit Button
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.edit, color: Colors.white, size: 18),
            onPressed: _pickAndSaveImage, // Triggers the gallery pick and save
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _showZoomedImage, // Triggers the zoom dialog
      child: _profileImage != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Image.file(
          _profileImage!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
        ),
      )
          : Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppColors.primary.withOpacity(0.10),
        ),
        child: Icon(
          Icons.person,
          size: 32,
          color: AppColors.primary,
        ),
      ),
    );
  }
  // ================= PROFILE HEADER CARD =================

  Widget _buildProfileHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TODO: bind these to real user data
                    Text(
                      _userName ?? "name",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(

                      "Agent ID: ${_userId ?? '---'}",
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _chip(_category, Icons.verified_rounded),
                        const SizedBox(width: 6),
                        _chip(_userRegion ?? "---", Icons.location_on_outlined),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Contact details
          Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _userPhone??"----", // TODO: real phone from user data
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.email_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                _userEmail??"---", // TODO: real email
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= AVATAR (USER PICTURE) =================


  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ================= PERFORMANCE CARD =================

  Widget _buildPerformanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Performance overview",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(
                label: "Total clients",
                value: totalclients.toString(),
                icon: Icons.people_outline,
              ),
              const SizedBox(width: 10),
              _statTile(
                label: "Approved",
                value: approvedclients.toString(),
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statTile(
                label: "Pending",
                value: pendingclients.toString(),
                icon: Icons.hourglass_bottom_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(width: 10),
              _statTile(
                label: "Target progress",
                value: "${percenta}%",
                icon: Icons.trending_up_rounded,
                color: AppColors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final Color c = color ?? AppColors.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.withOpacity(0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= ACCOUNT SECTION =================

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Account",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        _settingsItem(
          icon: Icons.lock_outline,
          title: "Change password",
          subtitle: "Update your login credentials",
          onTap: () {
            // TODO: open change password page
          },
        ),

      ],
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= LOGOUT BUTTON =================

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => _handleLogout(context),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.danger.withOpacity(0.9),
          ),
          foregroundColor: AppColors.danger,
          padding:
          const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: const Icon(Icons.logout),
        label: const Text("Log out"),
      ),
    );
  }
}
