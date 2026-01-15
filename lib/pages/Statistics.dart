import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pfs_agent/layouts/Colors.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'TargetsService.dart';
import 'database/digital_registration_db.dart';
import 'database_helper.dart';

class Statistics extends StatefulWidget {
  const Statistics({super.key});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  // Dummy data for now – later you can fetch this from API / DB



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



  int totalclients=0;
  int pendingclients=0;
  int approvedclients=0;
  int rejectedclients=0;
  int bounceclients=0;



  late Future<Map<String, int>> _statsFuture;

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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();


    _statsFuture = _getCombinedStats();
    Service();

  }
  @override
  Widget build(BuildContext context) {
    final double targetProgress = (_accumulated / _targetAmount).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(targetProgress),
            Expanded(
              child: SingleChildScrollView(
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
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _buildHeader(double targetProgress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF16831),
            Color(0xFFE0521C),
          ],
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
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: back + title
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
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
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
              )
            ],
          ),
          const SizedBox(height: 18),

          // Target progress
          const Text(
            "Monthly target progress",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildTargetProgressBar(targetProgress),
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

  Widget _buildTargetProgressBar(double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth * percenta/100;
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              height: 18,
              width: width,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  "${percenta}%",
                  style: TextStyle(
                    color: progress > 0.55
                        ? AppColors.primary
                        : Colors.white,
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

        // Row 1: Commission + Transport
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

        // Row 2: Total Generated (full width)
        _statCard(
          title: "Total generated",
          value: "K${_formatMoney(total.toDouble())}",
          icon: Icons.trending_up_rounded,
          accentColor: AppColors.secondary,
        ),

        const SizedBox(height: 10),

        // Row 3: Clients Summary (full width)
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
        border: Border.all(
          color: accent.withOpacity(0.08),
        ),
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
            child: Icon(
              icon,
              size: 18,
              color: accent,
            ),
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
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
        ),
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
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Clients summary",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
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
      _ChartItem("Transport", _transportIncentive.toDouble(), AppColors.secondary),
      _ChartItem("Total", total.toDouble(), AppColors.info),
    ];

    final double maxValue =
    data.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.06),
        ),
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
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((item) {
                final double heightFactor = maxValue == 0
                    ? 0.0
                    : (item.value / maxValue).clamp(0.1, 1.0);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "K${_formatShort(item.value)}",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 120 * heightFactor,
                            decoration: BoxDecoration(
                              color: item.color.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: item.color.withOpacity(0.6),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ================= CLIENTS FUNNEL =================

  Widget _buildClientsFunnelCard() {
    final int total = totalclients == 0 ? 1 : totalclients;
    final double approvedPct = approvedclients / totalclients;
    final double pendingPct = pendingclients / totalclients;
    final double otherPct = (1 - approvedPct - pendingPct).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.06),
        ),
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
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
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
                _funnelSegment(
                  fraction: approvedPct,
                  color: AppColors.success,
                ),
                _funnelSegment(
                  fraction: pendingPct,
                  color: AppColors.warning,
                ),
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
                  "Others (${totalclients - approvedclients - pendingclients})"
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _funnelSegment({required double fraction, required Color color}) {
    if (fraction <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: (fraction * 1000).round(),
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
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ================= HELPERS =================

  static String _formatMoney(double value) {
    // K 883,200.00 -> 883,200
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => "${m[1]},",
    );
  }

  static String _formatShort(double value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(1)}M";
    } else if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(1)}K";
    }
    return value.toStringAsFixed(0);
  }
}

class _ChartItem {
  final String label;
  final double value;
  final Color color;

  _ChartItem(this.label, this.value, this.color);
}
