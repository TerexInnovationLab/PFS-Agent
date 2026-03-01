import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pfs_agent/pages/DigitalSignUp.dart';
import 'package:pfs_agent/pages/AnalogSignUp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:pfs_agent/services/client_status_summary_service.dart';

import 'package:pfs_agent/layouts/Colors.dart';
import 'package:pfs_agent/pages/ProfilePage.dart';
import 'package:pfs_agent/pages/Statistics.dart';
import 'package:pfs_agent/pages/CreateNewPasswordPage.dart';
import 'package:pfs_agent/pages/login.dart';

import 'TargetsService.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late TargetsService _targetsService;

  // ================== TARGETS / SUMMARY ==================
  String _category = "---";
  int _commission = 0;

  // ✅ transport amounts split into MID + END
  int _transportMidAmount = 0;
  int _transportEndAmount = 0;

  int _targetAmount = 0;

  // ✅ percentage MUST come from TargetsService payload ONLY (transport_incentive.percent)
  int percenta = 0;

  // ✅ show "--" while fetching/initial
  bool _percentLoaded = false;

  // ✅ totals (kept for compatibility, but ALWAYS derived from commission + mid + end)
  int total = 0; // commission + mid + end

  // ✅ single source-of-truth total (prevents mismatches anywhere in UI)
  int get _totalEarnings =>
      _commission + _transportMidAmount + _transportEndAmount;

  int totalclients = 0;
  int pendingclients = 0;
  int approvedclients = 0;
  int rejectedclients = 0;
  int bounceclients = 0;
  bool _clientStatsLoaded = false;

  bool showBalance = false;

  final List<String> _images = [
    'assets/images/back1.png',
    'assets/images/back2.jpg',
    'assets/images/back3.png',
  ];

  int _currentImageIndex = 0;
  Timer? _timer;
  Timer? _summaryTimer;
  bool _summaryUpdateInProgress = false;

  // ================== USER BASIC (TOP) ==================
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
  final ImagePicker _picker = ImagePicker(); // (kept; may be used elsewhere)

  // ================== MORE DETAILS ==================
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

  // ✅ lock/unlock behaviour ONLY for More Details
  bool _unlockingDetails = false;
  bool _detailsRequestInProgress = false;

  // ✅ prevent overlapping targets updates (keeps category/amount/target/% in sync)
  bool _targetsUpdateInProgress = false;

  // month/year display
  String _monthYear = "";

  // ================= MONEY FORMATTER =================
  // "1200000" -> "1,200,000"
  String _formatMoney(int amount) {
    final s = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(',');
    }
    final out = buf.toString();
    return amount < 0 ? "-$out" : out;
  }

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

  // ================= SAFE INT PARSER =================
  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.round();
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return 0;
      return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
    }
    return 0;
  }

  // ================= PERCENT PARSER (from TargetsService payload) =================
  int _toPercentInt(dynamic v) {
    if (v == null) return 0;

    if (v is int) return v.clamp(0, 9999);

    if (v is double || v is num) {
      final d = (v as num).toDouble();
      // supports 0.34 => 34%
      if (d > 0 && d <= 1) return (d * 100).round().clamp(0, 9999);
      return d.round().clamp(0, 9999);
    }

    if (v is String) {
      final s = v.trim().replaceAll('%', '');
      if (s.isEmpty) return 0;
      final d = double.tryParse(s);
      if (d == null) return 0;
      if (d > 0 && d <= 1) return (d * 100).round().clamp(0, 9999);
      return d.round().clamp(0, 9999);
    }

    return 0;
  }

  // ================= PROGRESS BAR COLOR RULES =================
  Color _progressColorForPercent(int pct) {
    if (pct < 50) return Colors.red;
    if (pct < 80) return Colors.amber;
    return Colors.green;
  }

  // ================= LOAD USER BASIC =================
  Future<void> printUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? userJson = prefs.getString('user_data');
    password = prefs.getString('password');

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

        if (!mounted) return;
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
        });
      }
    }
  }

  // ================= LOAD ALL DETAILS FROM PREFS =================
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

    if (!mounted) return;

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

  // ================= TARGETS SERVICE =================
  void Service() {
    _targetsService = TargetsService(
      onDataReceived: (data) {
        _handleTargetsPayload(data);
      },
      onError: (error) {
        debugPrint("Update Error: $error");
      },
    );

    _targetsService.startPolling();
  }

  // ✅ Reads:
  // - category
  // - commission
  // - transport_incentive.target
  // - transport_incentive.mid_month.amount  (MID)
  // - transport_incentive.end_month.amount  (END)  [supports fallbacks]
  // - transport_incentive.percent           (progress percent)
  //
  // ✅ TOTAL must be: commission + mid + end
  Future<void> _handleTargetsPayload(dynamic data) async {
    if (!mounted) return;
    if (_targetsUpdateInProgress) return;
    _targetsUpdateInProgress = true;

    try {
      String nextCategory = _category;
      int nextCommission = _commission;

      int nextMid = _transportMidAmount;
      int nextEnd = _transportEndAmount;

      int nextTargetAmount = _targetAmount;
      int nextTotal = total;

      String nextMonthYear = _monthYear;
      int nextPercent = percenta;

      if (data is Map) {
        nextCategory = data['category']?.toString() ?? "N/A";
        nextCommission = _toInt(data['commission']);
        nextMonthYear = "${data['month']} ${data['year']}".toUpperCase();

        final transport = data['transport_incentive'];
        if (transport is Map) {
          nextTargetAmount = _toInt(transport['target']);

          // MID
          final midMonth = transport['mid_month'];
          if (midMonth is Map) {
            nextMid = _toInt(midMonth['amount']);
          } else {
            // fallback if API ever sends it directly
            nextMid = _toInt(transport['mid_amount'] ?? transport['mid']);
          }

          // END (support several possible keys)
          final endMonth =
              transport['end_month'] ??
              transport['end'] ??
              transport['month_end'] ??
              transport['end_month_amount'];

          if (endMonth is Map) {
            nextEnd = _toInt(endMonth['amount']);
          } else {
            nextEnd = _toInt(endMonth);
          }

          // ✅ percent comes ONLY from TargetsService payload
          dynamic percentRaw = transport['percent'] ?? transport['percentage'];
          if (percentRaw == null && midMonth is Map) {
            percentRaw = midMonth['percent'] ?? midMonth['percentage'];
          }
          nextPercent = _toPercentInt(percentRaw);
        }

        // ✅ REQUIRED TOTAL: commission + mid + end
        nextTotal = nextCommission + nextMid + nextEnd;
      }

      if (!mounted) return;

      setState(() {
        _category = nextCategory;
        _commission = nextCommission;

        _transportMidAmount = nextMid;
        _transportEndAmount = nextEnd;

        _targetAmount = nextTargetAmount;

        // keep compatibility variable, but it is ALWAYS the same formula:
        total = _commission + _transportMidAmount + _transportEndAmount;

        _monthYear = nextMonthYear;

        percenta = nextPercent;
        _percentLoaded = true;
      });
    } finally {
      _targetsUpdateInProgress = false;
    }
  }

  Future<void> _loadSavedImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = p.join(directory.path, 'profile_picker_image.png');
    final savedFile = File(imagePath);

    if (await savedFile.exists()) {
      if (!mounted) return;
      setState(() {
        _profileImage = savedFile;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _percentLoaded = false;

    _loadSavedImage();
    const ClientStatusSummaryService().getCachedSummary().then((summary) {
      if (!mounted || summary == null) return;
      setState(() {
        totalclients = summary.total;
        pendingclients = summary.pending;
        approvedclients = summary.approved;
        rejectedclients = summary.rejected;
        bounceclients = summary.bounced;
        _clientStatsLoaded = true;
      });
    });
    _getCombinedStats();
    _summaryTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _getCombinedStats();
    });

    printUserInfo();
    _loadAllDetailsFromPrefs();

    Service();

    _timer = Timer.periodic(const Duration(seconds: 10), (Timer t) {
      if (!mounted) return;
      setState(() {
        _currentImageIndex = (_currentImageIndex + 1) % _images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _summaryTimer?.cancel();
    super.dispose();
  }

  // =========================================================
  // 🔐 EARNINGS PASSWORD DIALOG
  // =========================================================

  Future<void> _handleToggleBalance() async {
    if (!showBalance) {
      final bool? success = await _showPasswordDialog();
      if (success == true) {
        if (!mounted) return;
        setState(() {
          showBalance = true;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        showBalance = false;
      });
    }
  }

  Future<bool?> _showPasswordDialog() async {
    final TextEditingController _passwordController = TextEditingController();
    String? errorText;
    bool isPasswordVisible = false;

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
                    obscureText: !isPasswordVisible,
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
                        onPressed: () => setStateDialog(
                          () => isPasswordVisible = !isPasswordVisible,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
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
                    if (_passwordController.text.trim() == password) {
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

  Future<bool?> _showPasswordDialog2() async {
    final TextEditingController _passwordController = TextEditingController();
    String? errorText;
    bool isPasswordVisible = false;

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
                  const Text(
                    'Statistics locked',
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
                    'Enter your password to view your Statistics.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: !isPasswordVisible,
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
                        onPressed: () => setStateDialog(
                          () => isPasswordVisible = !isPasswordVisible,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
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
                    if (_passwordController.text.trim() == password) {
                      Navigator.of(context).pop(true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Statistics(),
                        ),
                      );
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

  // =========================================================
  // ✅ DETAILS LOCK + PERSONAL DETAILS POPUP
  // =========================================================

  Future<bool?> _showDetailsPasswordDialogDashboard() async {
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
              if (entered != (password ?? '')) {
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

  void _showPersonalDetailsSheet() {
    bool showMore = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> onMoreLessTap() async {
              if (showMore) {
                setStateDialog(() => showMore = false);
                return;
              }

              if (_detailsRequestInProgress) return;
              _detailsRequestInProgress = true;

              final ok = await _showDetailsPasswordDialogDashboard();

              _detailsRequestInProgress = false;

              if (ok == true && mounted) {
                setStateDialog(() => showMore = true);
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildAvatar(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                      _chip(
                                        _userRegion ?? "---",
                                        Icons.location_on_outlined,
                                      ),
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
                        _detailRow(Icons.phone_outlined, "Phone", _userPhone),
                        const SizedBox(height: 6),
                        _detailRow(Icons.email_outlined, "Email", _userEmail),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onMoreLessTap,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            child: Text(
                              showMore ? "Less Details" : "More Details",
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _moreDetailsBlock(),
                          ),
                          crossFadeState: showMore
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value == null || value.isEmpty ? "---" : value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moreDetailsBlock() {
    Widget item(IconData icon, String text) {
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

    return Column(
      children: [
        item(Icons.person_2_outlined, "Gender: ${_profileGender ?? '---'}"),
        item(Icons.badge_outlined, "ID Type: ${_profileIdType ?? '---'}"),
        item(Icons.badge_outlined, "ID Type No.: ${_profileIdNumber ?? '---'}"),
        item(
          Icons.family_restroom_outlined,
          "Marital Status: ${_profileMaritalStatus ?? '---'}",
        ),
        item(
          Icons.date_range_outlined,
          "Date Joined: ${_formatDate(_profileDateJoined)}",
        ),
        item(
          Icons.date_range_rounded,
          "Date of Birth: ${_formatDate(_profileDateOfBirth)}",
        ),
        item(
          Icons.local_post_office_outlined,
          "Postal Address: ${_profilePostalAddress ?? '---'}",
        ),
        item(
          Icons.numbers_rounded,
          "Postal Code: ${_profilePostalCode ?? '---'}",
        ),
        item(
          Icons.location_city_outlined,
          "Postal Town: ${_profilePostalTown ?? '---'}",
        ),
        item(
          Icons.verified_user_outlined,
          "Email verified at: ${_formatDate(_emailVerifiedAt)}",
        ),
        item(Icons.timer_outlined, "Created at: ${_formatDate(_createdAt)}"),
        item(Icons.timer_outlined, "Updated at: ${_formatDate(_updatedAt)}"),
        item(
          Icons.account_balance,
          "Bank Name: ${_bankAccountName ?? _userBank ?? '---'}",
        ),
        item(
          Icons.account_balance_wallet_outlined,
          "Acc No.: ${_bankAccountNumber ?? '---'}",
        ),
        item(Icons.account_balance_outlined, "Branch: ${_branch ?? '---'}"),
        item(Icons.map, "Region: ${_region ?? _userRegion ?? '---'}"),
        item(
          Icons.check_circle,
          "Status: ${_agentStatus ?? _userStatus ?? '---'}",
        ),
        item(Icons.work_outline, "Role: ${_profileRole ?? '---'}"),
      ],
    );
  }

  // =========================================================
  // UI BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    const double heroHeight = 220;
    const double sheetRadius = 24;
    const double sheetLift = 24;
    const double headerTop = 8;
    const double headerHeight = 160;
    const double gapHeaderToEarnings = 14;

    final double earningsTop = headerTop + headerHeight + gapHeaderToEarnings;

    const double earningsCardEstimatedHeight = 92;
    const double afterEarningsSpace = 36;

    final double sheetTop = heroHeight - sheetLift;
    final double topSectionHeight =
        earningsTop + earningsCardEstimatedHeight + afterEarningsSpace;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: heroHeight,
              child: Image.asset(
                _images[_currentImageIndex],
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: heroHeight,
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(
                    height: topSectionHeight,
                    child: Stack(
                      children: [
                        Positioned(
                          top: sheetTop,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(sheetRadius),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.10),
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _buildHeader(),
                        _buildEarningsSection(top: earningsTop),
                      ],
                    ),
                  ),
                  Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                'Personal Details',
                                Icons.person_outline_outlined,
                                onTap: _showPersonalDetailsSheet,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _actionButton(
                                'Statistics',
                                Icons.insert_chart_outlined,
                                onTap: () {
                                  _showPasswordDialog2();
                                },
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: _actionButton(
                                  'More',
                                  Icons.more_horiz,
                                  onTap: _showMorePanel,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _actionButton(
                                  'Add Clients',
                                  Icons.person_add_alt_outlined,
                                  onTap: _showSignUpOptionsDashboard,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _clientsSummaryCardDashboard(),
                        const SizedBox(height: 16),
                        _clientsFunnelCardDashboard(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= EARNINGS SECTION =================
  Widget _buildEarningsSection({required double top}) {
    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  onTap: _handleToggleBalance,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      showBalance ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _earningColumn(
                    title: "Commission",
                    amount: "K ${_formatMoney(_commission)}",
                  ),
                ),
                _divider(),

                // ✅ Transport (UNIFORM + REQUESTED BEHAVIOR)
                Expanded(
                  child: _earningColumnTransportUniform(
                    title: "Transport",
                    midMonthAmount: _transportMidAmount,
                    monthEndAmount: _transportEndAmount,
                  ),
                ),
                _divider(),

                Expanded(
                  child: _earningColumn(
                    title: "Total Amount",
                    // ✅ always commission + mid + end
                    amount: "K ${_formatMoney(_totalEarnings)}",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.grey.withOpacity(0.3),
    );
  }

  Widget _earningColumn({required String title, required String amount}) {
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

  // ✅ Transport (UNIFORM + REQUESTED BEHAVIOR)
  // Locked:
  //  - Top: KX,XXX.xx
  // Unlocked:
  //  - Line1: Mid: K <mid>
  //  - Line2: End: K <end>
  Widget _earningColumnTransportUniform({
    required String title,
    required int midMonthAmount,
    required int monthEndAmount,
  }) {
    final String midFmt = _formatMoney(midMonthAmount);
    final String endFmt = _formatMoney(monthEndAmount);

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

        // LOCKED: one line only
        if (!showBalance)
          Text(
            "KX,XXX.xx",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),

        // UNLOCKED: mid + end only
        if (showBalance) ...[
          Text(
            "Mid: K $midFmt",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "End: K $endFmt",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================
  // DB + STATS
  // =========================================================

  Future<void> _getCombinedStats() async {
    if (_summaryUpdateInProgress) return;
    _summaryUpdateInProgress = true;

    try {
      final summary = await const ClientStatusSummaryService().fetchSummary();
      if (!mounted || summary == null) return;

      setState(() {
        totalclients = summary.total;
        pendingclients = summary.pending;
        approvedclients = summary.approved;
        rejectedclients = summary.rejected;
        bounceclients = summary.bounced;
        _clientStatsLoaded = true;
      });
    } finally {
      _summaryUpdateInProgress = false;
    }
  }

  String _clientStatLabel(int value) {
    return _clientStatsLoaded ? value.toString() : "--";
  }

  Widget _pill(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clientsSummaryCardDashboard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  Icons.people_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Clients summary",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _pill(
                _clientStatLabel(totalclients),
                "Total",
                AppColors.secondary,
              ),
              const SizedBox(width: 6),
              _pill(
                _clientStatLabel(approvedclients),
                "Approved",
                AppColors.success,
              ),
              const SizedBox(width: 6),
              _pill(
                _clientStatLabel(pendingclients),
                "Pending",
                AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // reset percent loaded
    _percentLoaded = false;

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _showSignUpOptionsDashboard() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  "Client registration method",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                // const SizedBox(height: 6),
                // Text(
                //   "Choose how you would like to register this client.",
                //   style:
                //       TextStyle(fontSize: 14, color: AppColors.textSecondary),
                // ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(
                      Icons.phone_android,
                      color: AppColors.primary,
                    ),
                  ),
                  title: const Text("Digital registration"),
                  subtitle: const Text(
                    "Capture details directly in the application",
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DigitalSignUp(),
                      ),
                    );
                  },
                ),
                // const SizedBox(height: 8),
                // ListTile(
                //   leading: CircleAvatar(
                //     backgroundColor: AppColors.secondary.withOpacity(0.1),
                //     child:
                //         const Icon(Icons.camera_alt, color: AppColors.secondary),
                //   ),
                //   title: const Text("Forms upload"),
                //   subtitle:
                //       const Text("Upload scanned/photographed registration"),
                //   onTap: () {
                //     Navigator.pop(ctx);
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => const AnalogSignUp(),
                //       ),
                //     );
                //   },
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================== MORE PANEL ==================
  void _showMorePanel() {
    showGeneralDialog(
      context: context,
      barrierLabel: "More",
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        final width = MediaQuery.of(ctx).size.width;
        double panelWidth = width * 0.6;
        if (panelWidth > 340) panelWidth = 340;

        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Container(
                  width: panelWidth,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(-2, 6),
                      ),
                    ],
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "More options",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.lock_reset,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          "Change Password",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Createnewpasswordpage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.logout,
                          color: AppColors.danger,
                        ),
                        title: const Text(
                          "Log out",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await _handleLogout();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final tween = Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(position: anim.drive(tween), child: child);
      },
    );
  }

  Widget _clientsFunnelCardDashboard() {
    final int denom = !_clientStatsLoaded || totalclients == 0
        ? 1
        : totalclients;
    final double approvedPct = approvedclients / denom;
    final double pendingPct = pendingclients / denom;
    final double otherPct = (1 - approvedPct - pendingPct).clamp(0.0, 1.0);
    final otherCount = totalclients - approvedclients - pendingclients;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Clients funnel",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "From registration to approval",
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _funnelSegment(fraction: approvedPct, color: AppColors.success),
                _funnelSegment(fraction: pendingPct, color: AppColors.warning),
                _funnelSegment(
                  fraction: otherPct,
                  color: AppColors.textSecondary.withOpacity(0.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendItem(
                AppColors.success,
                "Approved (${_clientStatLabel(approvedclients)})",
              ),
              _legendItem(
                AppColors.warning,
                "Pending (${_clientStatLabel(pendingclients)})",
              ),
              _legendItem(
                AppColors.textSecondary.withOpacity(0.7),
                "Others (${_clientStatsLoaded ? otherCount.toString() : "--"})",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _funnelSegment({required double fraction, required Color color}) {
    if (fraction <= 0 || !fraction.isFinite) return const SizedBox.shrink();
    int flex = (fraction * 1000).round();
    if (flex <= 0) flex = 1;
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.20),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ================= HEADER AVATAR =================
  Widget _buildAvatar() {
    final double size = 40;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child:
            (_profileImage != null &&
                (_userImageAssetPath?.isNotEmpty ?? false))
            ? Image.file(_profileImage!, fit: BoxFit.cover)
            : Container(
                color: AppColors.accent,
                child: const Icon(Icons.person, color: Colors.white),
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
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            child: _buildAvatar(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
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
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? "Loading...",
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Agent ID: ${_userId ?? '---'}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Monthly Sales Target",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTargetProgressBar(),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "MWK ${_formatMoney(_targetAmount)}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showMorePanel,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ percent comes from service ONLY. No calculations.
  Widget _buildTargetProgressBar() {
    final bool showDash = !_percentLoaded || _targetAmount <= 0;

    final int pctForUi = showDash ? 0 : percenta;
    final String label = showDash ? "--" : "$percenta%";

    final Color barColor = showDash
        ? Colors.white.withOpacity(0.35)
        : _progressColorForPercent(pctForUi);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double fraction = showDash ? 0.0 : (pctForUi / 100.0);
        final double capped = fraction > 1 ? 1 : fraction;
        final double width = constraints.maxWidth * capped;

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
                color: barColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
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

  Widget _actionButton(String label, IconData icon, {VoidCallback? onTap}) {
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
            border: Border.all(color: AppColors.primary.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 16.0,
            ),
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
                  child: Icon(icon, size: 20, color: AppColors.primary),
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
                      color: AppColors.textSecondary.withOpacity(0.7),
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

  Widget _chip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
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
}

// (left as-is from your file)
class _ChartItem {
  final String label;
  final double value;
  final Color color;

  _ChartItem(this.label, this.value, this.color);
}

class PieChartPainter extends CustomPainter {
  final List<_ChartItem> data;
  final double total;

  PieChartPainter(this.data, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    double startAngle = -90 * 3.1415926 / 180;

    for (final item in data) {
      final sweepAngle = (item.value / total) * 2 * 3.1415926;
      paint.color = item.color;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
