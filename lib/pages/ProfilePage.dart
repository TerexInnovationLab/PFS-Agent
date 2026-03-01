import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pfs_agent/config/api_config.dart';
import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/CreateNewPasswordPage.dart';
import 'package:pfs_agent/pages/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'TargetsService.dart';
import 'database/digital_registration_db.dart';
import 'database_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  ProfilePageState createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final String _headerImage = 'assets/images/back1.png';

  bool _isUploadingImage = false;

  // ✅ Loader only inside "Details locked" dialog (single row loader)
  bool _unlockingDetails = false;
  bool _detailsRequestInProgress = false;

  // server image url
  String? _profileImageUrl;

  // cached user fallback (top card)
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _userRegion;
  String? _userBank;
  String? _userStatus;
  String? _userId;

  // more details (loaded from SAVED user_data after unlock; no API fetch)
  String? _profileGender;
  String? _profileIdType;
  String? _profileIdNumber;
  String? _profileMaritalStatus;
  String? _profileDateJoined;
  String? _profileDateOfBirth;
  String? _profilePostalAddress;
  String? _profilePostalCode;
  String? _profilePostalTown;
  String? _profileRole;
  String? _emailVerifiedAt;
  String? _createdAt;
  String? _updatedAt;

  // agent details
  String? _agentCode;
  String? _bankAccountName;
  String? _bankAccountNumber;
  String? _branch;
  String? _region;
  String? _agentStatus;

  bool _showMoreDetails = false;
  String? _password;

  int totalclients = 0;
  int pendingclients = 0;
  int approvedclients = 0;
  int rejectedclients = 0;
  int bounceclients = 0;

  late TargetsService _targetsService;

  // Data variables mapped to your UI
  String _category = "---";
  int _commission = 0;
  int _transportIncentive = 0;
  int _targetAmount = 0;
  double _progressPercentage = 0.0;
  int _accumulated = 0;
  String _monthYear = "";
  int total = 0;
  int percenta = 0;

  // ================= DATE FORMATTER =================
  String _formatDate(String? raw) {
    if (raw == null) return '---';
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '---';

    final hasTime = s.contains('T') || s.contains(':');

    DateTime? dt;
    try {
      dt = DateTime.parse(s);
    } catch (_) {
      return s;
    }

    dt = dt.toLocal();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final day = dt.day.toString();
    final monthName = months[dt.month - 1];
    final year = dt.year.toString();

    if (!hasTime) return '$day $monthName, $year';

    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$day $monthName, $year at $hh:$mm';
  }

  // ================= IMAGE PREVIEW (MATCH ORIGINAL LOOK) =================
  void _showProfileImagePreview() {
    if (_isUploadingImage) return;

    final hasLocal = _profileImage != null;
    final hasNet =
        (_profileImageUrl != null && _profileImageUrl!.trim().isNotEmpty);

    if (!hasLocal && !hasNet) return;

    // cache-bust network url when showing preview
    final String? netUrl = hasNet
        ? Uri.parse(_profileImageUrl!)
              .replace(
                queryParameters: {
                  "v": DateTime.now().millisecondsSinceEpoch.toString(),
                },
              )
              .toString()
        : null;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final media = MediaQuery.of(ctx);

        Widget imageWidget;
        if (hasLocal) {
          imageWidget = Image.file(_profileImage!, fit: BoxFit.contain);
        } else {
          imageWidget = Image.network(
            netUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  height: 26,
                  width: 26,
                  child: CircularProgressIndicator(),
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              size: 120,
              color: Colors.white,
            ),
          );
        }

        // ✅ Keep the original-style simple dialog:
        // transparent background + image + Close button (no fullscreen overlay)
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: media.size.width * 0.92,
                  maxHeight: media.size.height * 0.60,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: imageWidget,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= TOKEN =================
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('token');
    if (raw == null) return null;
    return raw.trim().replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
  }

  // ================= LOCAL SAVED IMAGE =================
  Future<void> _loadSavedImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = p.join(directory.path, 'profile_picker_image.png');
      final savedFile = File(imagePath);

      if (await savedFile.exists()) {
        setState(() => _profileImage = savedFile);
      }
    } catch (_) {}
  }

  Future<void> _cachePickedImage(File picked) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'profile_picker_image.png';
      final dest = File(p.join(directory.path, fileName));
      await picked.copy(dest.path);
    } catch (_) {}
  }

  // ================= LOAD USER DETAILS FROM PREFS =================
  Future<void> _loadAllDetailsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');

    if (userJson == null || userJson.isEmpty) return;

    dynamic decoded;
    try {
      decoded = jsonDecode(userJson);
    } catch (_) {
      return;
    }

    if (decoded is! Map<String, dynamic>) return;

    final Map<String, dynamic> user = (decoded['user'] is Map<String, dynamic>)
        ? decoded['user']
        : decoded;

    final Map<String, dynamic>? agent = (user['agent'] is Map<String, dynamic>)
        ? user['agent']
        : null;

    setState(() {
      _userName = "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}"
          .trim();
      _userEmail = user['email']?.toString();
      _userPhone = user['phone']?.toString();

      _profileGender = user["gender"]?.toString();
      _profileIdType = user["identity_type"]?.toString();
      _profileIdNumber = user["identity_type_number"]?.toString();
      _profileMaritalStatus = user["marital_status"]?.toString();
      _profileDateJoined = user["date_joined"]?.toString();
      _profileDateOfBirth = user["date_of_birth"]?.toString();
      _profilePostalAddress = user["postal_address"]?.toString();
      _profilePostalCode = user["postal_code"]?.toString();
      _profilePostalTown = user["postal_town"]?.toString();
      _profileRole = user["role"]?.toString();
      _emailVerifiedAt = user["email_verified_at"]?.toString();
      _createdAt = user["created_at"]?.toString();
      _updatedAt = user["updated_at"]?.toString();

      final img = user["profile_image"]?.toString();
      if (img != null && img.isNotEmpty) _profileImageUrl = img;

      if (agent != null) {
        _agentCode = agent["agent_code"]?.toString();
        _region = agent["region"]?.toString();
        _agentStatus = agent["status"]?.toString();
        _bankAccountName = agent["bank_account_name"]?.toString();
        _bankAccountNumber = agent["bank_account_number"]?.toString();
        _branch = agent["branch"]?.toString();

        _userRegion = _region ?? _userRegion;
        _userId = _agentCode ?? _userId;
        _userStatus = _agentStatus ?? _userStatus;
        _userBank = _bankAccountName ?? _userBank;
      }
    });
  }

  // ================= API: FETCH PROFILE IMAGE =================
  Future<void> _fetchProfileImage() async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) return;

      final uri = Uri.parse("${ApiConfig.baseUrl}/profile-image");

      final res = await http
          .post(
            uri,
            headers: {
              "Accept": "application/json",
              "Authorization": "Bearer $token",
            },
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final url = decoded["profile_image"]?.toString();
          if (url != null && url.isNotEmpty) {
            if (mounted) setState(() => _profileImageUrl = url);
          }
        }
      } else {
        debugPrint("Fetch image failed: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("Fetch image error: $e");
    }
  }

  // ================= API: UPLOAD PROFILE IMAGE =================
  Future<void> _pickAndUploadImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final file = File(pickedFile.path);

    setState(() {
      _profileImage = file;
      _isUploadingImage = true;
    });

    await _cachePickedImage(file);

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        _showToastLike("Session expired. Please login again.");
        return;
      }

      final uri = Uri.parse("${ApiConfig.baseUrl}/profile-image");

      final request = http.MultipartRequest("POST", uri);
      request.headers.addAll({
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      });

      request.files.add(
        await http.MultipartFile.fromPath("profile_image", file.path),
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final url = decoded["profile_image"]?.toString();
          if (url != null && url.isNotEmpty) {
            if (mounted) setState(() => _profileImageUrl = url);
          }
        }

        await _fetchProfileImage();
        _showToastLike("Profile image updated.");
      } else {
        debugPrint("Upload failed: ${response.statusCode} ${response.body}");
        _showToastLike("Failed to upload image (${response.statusCode}).");
      }
    } on TimeoutException {
      _showToastLike("Upload timed out. Please try again.");
    } catch (e) {
      debugPrint("Upload error: $e");
      _showToastLike("Upload failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ================= BASIC MESSAGE =================
  void _showToastLike(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(
          msg,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop())
        Navigator.of(context).pop();
    });
  }

  // ================= DATA STATS =================
  Future<Map<String, int>> _getCombinedStats() async {
    int approved = 0;
    int rejected = 0;
    int bounce = 0;
    int pending = 0;

    final db1List = await DigitalRegistrationDb.instance.getAll();
    for (var item in db1List) {
      final s = item.status.toLowerCase();
      if (s == 'approved') {
        approved++;
      } else if (s == 'pending') {
        pending++;
      } else if (s == 'rejected' || s == 'denied') {
        rejected++;
      } else if (s == 'bounce') {
        bounce++;
      }
    }

    final db2List = await DatabaseHelper.instance.getData();
    for (var item in db2List) {
      final s = (item[DatabaseHelper.columnStatus] as String? ?? '')
          .toLowerCase();
      if (s == 'approved') {
        approved++;
      } else if (s == 'pending') {
        pending++;
      } else if (s == 'rejected' || s == 'denied') {
        rejected++;
      } else if (s == 'bounce') {
        bounce++;
      }
    }

    setState(() {
      totalclients = approved + pending + rejected + bounce;
      pendingclients = pending;
      approvedclients = approved;
      rejectedclients = rejected;
      bounceclients = bounce;
    });

    return {
      'Approved': approved,
      'Pending': pending,
      'Rejected': rejected,
      'Bounce': bounce,
      'Total': db1List.length + db2List.length,
    };
  }

  void Service() {
    _targetsService = TargetsService(
      onDataReceived: (data) {
        if (!mounted) return;
        setState(() {
          _category = data['category']?.toString() ?? "N/A";
          _commission = data['commission'] ?? 0;
          _monthYear = "${data['month']} ${data['year']}".toUpperCase();

          final transport = data['transport_incentive'];
          if (transport != null) {
            _targetAmount = transport['target'] ?? 0;
            final midMonth = transport['mid_month'];
            _transportIncentive = midMonth['amount'] ?? 0;
            _progressPercentage = (midMonth['percentage'] ?? 0.0).toDouble();
            _accumulated = transport['accumulated']?['mid_month'] ?? 0;
          }

          total = _transportIncentive + _commission;

          final int accumulated =
              (transport?['accumulated']?['mid_month'] as num?)?.toInt() ?? 0;
          final int target = (transport?['target'] as num?)?.toInt() ?? 0;

          percenta = target > 0 ? ((accumulated / target) * 100).round() : 0;
        });
      },
      onError: (error) {
        debugPrint("Update Error: $error");
      },
    );

    _targetsService.startPolling();
  }

  Future<void> printUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');
    _password = prefs.getString('password');

    if (userJson != null) {
      dynamic decoded;
      try {
        decoded = jsonDecode(userJson);
      } catch (_) {
        return;
      }

      if (decoded is Map<String, dynamic>) {
        final Map<String, dynamic> user =
            (decoded['user'] is Map<String, dynamic>)
            ? decoded['user']
            : decoded;

        setState(() {
          _userName = "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}"
              .trim();
          _userEmail = user['email']?.toString();
          _userPhone = user['phone']?.toString();

          if (user['agent'] != null && user['agent'] is Map<String, dynamic>) {
            final a = user['agent'] as Map<String, dynamic>;
            _userRegion = a['region']?.toString();
            _userId = a['agent_code']?.toString() ?? a['user_id']?.toString();
            _userStatus = a['status']?.toString();
            _userBank = a['bank_account_name']?.toString();
          }

          final img = user["profile_image"]?.toString();
          if (img != null && img.isNotEmpty) _profileImageUrl = img;
        });
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();

    _loadSavedImage();
    _getCombinedStats();
    Service();
    printUserInfo();

    _loadAllDetailsFromPrefs();
    _fetchProfileImage();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF7F3),
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: 260,
              child: Image.asset(_headerImage, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 260,
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
        children: const [
          Expanded(
            child: Text(
              "Profile",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= AVATAR =================
  Widget _buildAvatar() {
    Widget avatar;

    if (_profileImage != null) {
      avatar = Image.file(
        _profileImage!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      final bustedUrl = Uri.parse(_profileImageUrl!)
          .replace(
            queryParameters: {
              "v": DateTime.now().millisecondsSinceEpoch.toString(),
            },
          )
          .toString();

      avatar = Image.network(
        bustedUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackAvatar(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _fallbackAvatar(isLoading: true);
        },
      );
    } else {
      avatar = _fallbackAvatar();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _showProfileImagePreview, // ✅ preview on tap (original style)
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(width: 64, height: 64, child: avatar),
          ),
        ),
        if (_isUploadingImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 32,
          right: -16,
          child: IconButton(
            onPressed: _isUploadingImage ? null : _pickAndUploadImage,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(Icons.edit, color: AppColors.primary, size: 16),
            tooltip: "Edit profile photo",
          ),
        ),
      ],
    );
  }

  Widget _fallbackAvatar({bool isLoading = false}) {
    return Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: const Color(0xFFF16831).withOpacity(0.10),
      ),
      child: Center(
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.person, size: 32, color: AppColors.primary),
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
                    Text(
                      (_userName?.isNotEmpty ?? false) ? _userName! : "name",
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
                  _userPhone ?? "----",
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
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
                  _userEmail ?? "---",
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (_showMoreDetails) {
                    setState(() => _showMoreDetails = false);
                    return;
                  }

                  if (_detailsRequestInProgress) return;
                  _detailsRequestInProgress = true;

                  final ok = await _showDetailsPasswordDialog();

                  _detailsRequestInProgress = false;

                  if (ok == true && mounted) {
                    setState(() => _showMoreDetails = true);
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(_showMoreDetails ? 'Less Details' : 'More Details'),
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _moreDetailsSection(),
            ),
            crossFadeState: _showMoreDetails
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  // ================= MORE DETAILS =================
  Widget _moreDetailsSection() {
    return Column(
      children: [
        _detailRow(
          Icons.person_2_outlined,
          "Gender: ${_profileGender ?? '---'}",
        ),
        _detailRow(Icons.badge_outlined, "ID Type: ${_profileIdType ?? '---'}"),
        _detailRow(
          Icons.badge_outlined,
          "ID Type No.: ${_profileIdNumber ?? '---'}",
        ),
        _detailRow(
          Icons.family_restroom_outlined,
          "Marital Status: ${_profileMaritalStatus ?? '---'}",
        ),
        _detailRow(
          Icons.date_range_outlined,
          "Date Joined: ${_formatDate(_profileDateJoined)}",
        ),
        _detailRow(
          Icons.date_range_rounded,
          "Date of Birth: ${_formatDate(_profileDateOfBirth)}",
        ),
        _detailRow(
          Icons.local_post_office_outlined,
          "Postal Address: ${_profilePostalAddress ?? '---'}",
        ),
        _detailRow(
          Icons.numbers_rounded,
          "Postal Code: ${_profilePostalCode ?? '---'}",
        ),
        _detailRow(
          Icons.location_city_outlined,
          "Postal Town: ${_profilePostalTown ?? '---'}",
        ),
        _detailRow(
          Icons.verified_user_outlined,
          "Email verified at: ${_formatDate(_emailVerifiedAt)}",
        ),
        _detailRow(
          Icons.timer_outlined,
          "Created at: ${_formatDate(_createdAt)}",
        ),
        _detailRow(
          Icons.timer_outlined,
          "Updated at: ${_formatDate(_updatedAt)}",
        ),
        _detailRow(
          Icons.account_balance,
          "Bank Name: ${_bankAccountName ?? _userBank ?? '---'}",
        ),
        _detailRow(
          Icons.account_balance_wallet_outlined,
          "Acc No.: ${_bankAccountNumber ?? '---'}",
        ),
        _detailRow(
          Icons.account_balance_outlined,
          "Branch: ${_branch ?? '---'}",
        ),
        _detailRow(Icons.map, "Region: ${_region ?? _userRegion ?? '---'}"),
        _detailRow(
          Icons.check_circle,
          "Status: ${_agentStatus ?? _userStatus ?? '---'}",
        ),
        _detailRow(Icons.work_outline, "Role: ${_profileRole ?? '---'}"),
      ],
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ================= PASSWORD DIALOG (UPDATED: MATCHES YOUR DASHBOARD POPUP BEHAVIOUR) =================
  //
  // ✅ Uses AlertDialog + fixed paddings like your Dashboard
  // ✅ Does NOT expand/shrink when showing loader (reserved space)
  // ✅ Leaves EVERYTHING else intact
  //
  Future<bool?> _showDetailsPasswordDialog() async {
    final TextEditingController passwordController = TextEditingController();
    String? errorText;
    bool isPasswordVisible = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> unlockAndLoad() async {
              if (_unlockingDetails) return;

              final entered = passwordController.text.trim();
              if (entered != (_password ?? '')) {
                setStateDialog(() => errorText = 'Incorrect password');
                return;
              }

              setStateDialog(() {
                errorText = null;
                _unlockingDetails = true;
              });

              try {
                await _loadAllDetailsFromPrefs();
                if (!mounted) return;
                Navigator.of(context).pop(true);
              } catch (_) {
                setStateDialog(() {
                  errorText = 'Failed to load details. Try again.';
                  _unlockingDetails = false;
                });
              } finally {
                if (mounted) {
                  setStateDialog(() => _unlockingDetails = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                  const Expanded(
                    child: Text(
                      'Details locked',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your password to view more details.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    autofocus: true,
                    obscureText: !isPasswordVisible,
                    enabled: !_unlockingDetails,
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
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: _unlockingDetails
                            ? null
                            : () => setStateDialog(
                                () => isPasswordVisible = !isPasswordVisible,
                              ),
                      ),
                    ),
                    onSubmitted: (_) => unlockAndLoad(),
                  ),

                  // ✅ Reserve space so the dialog DOES NOT grow/shrink
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 22,
                    child: _unlockingDetails
                        ? Row(
                            children: const [
                              SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Loading... your details",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _unlockingDetails
                      ? null
                      : () => Navigator.of(context).pop(false),
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
                  onPressed: _unlockingDetails ? null : unlockAndLoad,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
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

  // ================= CHIP =================
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
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
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
          border: Border.all(color: c.withOpacity(0.12)),
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
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Createnewpasswordpage(),
              ),
            );
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
          side: BorderSide(color: AppColors.danger.withOpacity(0.9)),
          foregroundColor: AppColors.danger,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        icon: const Icon(Icons.logout),
        label: const Text("Log out"),
      ),
    );
  }
}
