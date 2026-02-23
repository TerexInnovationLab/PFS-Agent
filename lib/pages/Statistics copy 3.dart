import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pfs_agent/layouts/Colors.dart';

import 'TargetsService.dart';
import 'database/digital_registration_db.dart';
import 'database_helper.dart';

class Statistics extends StatefulWidget {
  const Statistics({super.key});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  late TargetsService _targetsService;

  // ================== TARGETS / SUMMARY ==================
  String _category = "---";
  int _commission = 0;
  int _accumulated = 0; // ✅ comes from transport_incentive.accumulated
  int _transportIncentive = 0;
  int _targetAmount = 0;

  // ✅ percentage MUST come from TargetsService payload ONLY
  int percenta = 0;

  // ✅ show "--" while fetching/initial
  bool _percentLoaded = false;

  String _monthYear = "";
  int total = 0;

  // ✅ UI listens to this only; it gets updated ONLY from TargetsService payload
  final ValueNotifier<int?> _progressPct = ValueNotifier<int?>(null);

  // ✅ prevent overlapping targets updates (keeps category/target/% in sync)
  bool _targetsUpdateInProgress = false;

  // ================== CLIENT STATS ==================
  int totalclients = 0;
  int pendingclients = 0;
  int approvedclients = 0;
  int rejectedclients = 0;
  int bounceclients = 0;

  late Future<Map<String, int>> _statsFuture;

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

  // ✅ Progress + Generated amount come ONLY from targets service payload.
  Future<void> _handleTargetsPayload(dynamic data) async {
    if (!mounted) return;
    if (_targetsUpdateInProgress) return;
    _targetsUpdateInProgress = true;

    try {
      String nextCategory = _category;
      int nextCommission = _commission;
      int nextTransportIncentive = _transportIncentive;
      int nextTargetAmount = _targetAmount;
      int nextAccumulated = _accumulated; // ✅ new
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

          // ✅ accumulated: allow both map and direct number
          final acc = transport['accumulated'];
          if (acc is Map) {
            // prefer mid_month if present, else month_end, else 0
            nextAccumulated = _toInt(acc['mid_month']);
            if (nextAccumulated == 0) {
              nextAccumulated = _toInt(acc['month_end']);
            }
          } else {
            nextAccumulated = _toInt(acc);
          }

          final midMonth = transport['mid_month'];
          if (midMonth is Map) {
            nextTransportIncentive = _toInt(midMonth['amount']);
          }

          // ✅ percent comes ONLY from TargetsService payload
          dynamic percentRaw = transport['percent'] ?? transport['percentage'];
          if (percentRaw == null && midMonth is Map) {
            percentRaw = midMonth['percent'] ?? midMonth['percentage'];
          }
          nextPercent = _toPercentInt(percentRaw);
        }

        nextTotal = nextTransportIncentive + nextCommission;
      }

      if (!mounted) return;

      setState(() {
        _category = nextCategory;
        _commission = nextCommission;
        _transportIncentive = nextTransportIncentive;
        _targetAmount = nextTargetAmount;
        _accumulated = nextAccumulated; // ✅ set generated from accumulated
        total = nextTotal;
        _monthYear = nextMonthYear;

        percenta = nextPercent;
        _percentLoaded = true;
      });

      _progressPct.value = nextPercent;
    } finally {
      _targetsUpdateInProgress = false;
    }
  }

  // ================= COMBINED STATS =================
  Future<Map<String, int>> _getCombinedStats() async {
    int approved = 0;
    int rejected = 0;
    int bounce = 0;
    int pending = 0;
    int totalLocal = 0;

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
      final s =
          (item[DatabaseHelper.columnStatus] as String? ?? '').toLowerCase();
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

    totalLocal = db1List.length + db2List.length;

    if (mounted) {
      setState(() {
        totalclients = approved + pending + rejected + bounce;
        pendingclients = pending;
        approvedclients = approved;
        rejectedclients = rejected;
        bounceclients = bounce;
      });
    }

    return {
      'Approved': approved,
      'Pending': pending,
      'Rejected': rejected,
      'Bounce': bounce,
      'Total': totalLocal,
    };
  }

  @override
  void initState() {
    super.initState();

    _statsFuture = _getCombinedStats();

    // show "--" until service loads
    _progressPct.value = null;

    Service();
  }

  @override
  void dispose() {
    _progressPct.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryRow(),
                    const SizedBox(height: 16),
                    _buildEarningsChartCard(),
                    const SizedBox(height: 16),
                    _buildClientsFunnelCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF16831), Color(0xFFE0521C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Statistics & Performance",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            "Monthly target progress",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // ✅ progress comes ONLY from targets service
          _buildTargetProgressBarStable(),

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Generated: K${_formatMoney(_accumulated.toDouble())}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Target: K${_formatMoney(_targetAmount.toDouble())}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ STABLE progress bar: listens to _progressPct (service-only)
  Widget _buildTargetProgressBarStable() {
    return ValueListenableBuilder<int?>(
      valueListenable: _progressPct,
      builder: (context, pctOrNull, _) {
        final bool loading =
            pctOrNull == null || !_percentLoaded || _targetAmount <= 0;

        final int pct = loading ? 0 : pctOrNull!.clamp(0, 9999);
        final double factor =
            loading ? 0.0 : (pct / 100.0).clamp(0.0, 1.0);

        final Color barColor = loading
            ? Colors.white.withOpacity(0.35)
            : _progressColorForPercent(pct);

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                widthFactor: factor,
                child: Container(
                  height: 18,
                  color: barColor.withOpacity(0.95),
                ),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  loading ? "--" : "$pct%",
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

  // ================= SUMMARY CARDS =================
  Widget _buildSummaryRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Overview",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                title: "Commission earned",
                value: "K${_formatMoney(_commission.toDouble())}",
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                title: "Transport incentive",
                value: "K${_formatMoney(_transportIncentive.toDouble())}",
                icon: Icons.directions_bus_filled_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.5 - 8,
            child: _statCard(
              title: "Total generated",
              value: "K${_formatMoney(total.toDouble())}",
              icon: Icons.trending_up_rounded,
              accentColor: AppColors.secondary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _clientsSummaryCard(),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    Color? accentColor,
  }) {
    final Color accent = accentColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.08)),
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
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientsSummaryCard() {
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _pill(totalclients.toString(), "Total", AppColors.secondary),
              const SizedBox(width: 6),
              _pill(approvedclients.toString(), "Approved", AppColors.success),
              const SizedBox(width: 6),
              _pill(pendingclients.toString(), "Pending", AppColors.warning),
            ],
          ),
        ],
      ),
    );
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

  // ================= EARNINGS CHART =================
  Widget _buildEarningsChartCard() {
    final data = [
      _ChartItem("Commission", _commission.toDouble(), AppColors.primary),
      _ChartItem("Transport", _transportIncentive.toDouble(),
          AppColors.secondary),
      _ChartItem("Total", total.toDouble(), AppColors.info),
    ];

    final double sum = data.fold(0, (prev, element) => prev + element.value);

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
          Row(
            children: [
              Text(
                "Earnings breakdown",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                "This month",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Center(
              child: CustomPaint(
                size: const Size(160, 160),
                painter: PieChartPainter(data, sum),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: data.map((item) {
              final percent = sum == 0 ? 0 : ((item.value / sum) * 100).round();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${item.label} ($percent%)",
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ================= CLIENTS FUNNEL =================
  Widget _buildClientsFunnelCard() {
    final int denom = totalclients == 0 ? 1 : totalclients;
    final double approvedPct = approvedclients / denom;
    final double pendingPct = pendingclients / denom;
    final double otherPct = (1 - approvedPct - pendingPct).clamp(0.0, 1.0);

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
              _legendItem(AppColors.success, "Approved ($approvedclients)"),
              _legendItem(AppColors.warning, "Pending ($pendingclients)"),
              _legendItem(
                AppColors.textSecondary.withOpacity(0.7),
                "Others (${totalclients - approvedclients - pendingclients})",
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

  // ================= HELPERS =================
  static String _formatMoney(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => "${m[1]},",
        );
  }
}

class PieChartPainter extends CustomPainter {
  final List<_ChartItem> data;
  final double total;

  PieChartPainter(this.data, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

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

class _ChartItem {
  final String label;
  final double value;
  final Color color;

  _ChartItem(this.label, this.value, this.color);
}
