import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pfs_agent/CustomerOnboardingPage.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF6600);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: orange,
        title: const Text('PFS Agent Dashboard'),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const AutoScrollingSummary(color: orange),
            const SizedBox(height: 24),

            const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton('New Customer', Icons.person_add, orange),
                _actionButton('Upload Doc', Icons.upload_file, orange),
                _actionButton('View Tasks', Icons.task, orange),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _notificationTile('Lead approved: John Doe'),
                _notificationTile('Document rejected: ID Scan'),
                _notificationTile('New message from supervisor'),
              ],
            ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statusIndicator('Geo-presence: Active', Icons.location_on, Colors.green),
                _statusIndicator('Sync: Online', Icons.sync, Colors.blue),
              ],
            ),

            const SizedBox(height: 24),
            

            const SizedBox(height: 32),
            const Text('Your Weekly Sales Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return Text(days[value.toInt()], style: const TextStyle(fontSize: 10));
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                  ),
                  barGroups: [
                    for (int i = 0; i < 7; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: (i + 2) * 1.5, color: orange, width: 14),
                      ]),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Lead Conversion Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(value: 55, color: orange, title: 'Converted'),
                    PieChartSectionData(value: 30, color: Colors.blue, title: 'Pending'),
                    PieChartSectionData(value: 15, color: Colors.grey, title: 'Dropped'),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),


             const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Go to Customer Onboarding'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerOnboardingPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color) {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          onPressed: () {},
          child: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _notificationTile(String message) {
    return ListTile(
      leading: const Icon(Icons.notifications, color: Colors.orange),
      title: Text(message),
    );
  }

  Widget _statusIndicator(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}

class AutoScrollingSummary extends StatefulWidget {
  final Color color;
  const AutoScrollingSummary({required this.color});

  @override
  State<AutoScrollingSummary> createState() => _AutoScrollingSummaryState();
}

class _AutoScrollingSummaryState extends State<AutoScrollingSummary> {
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _cards = [
    {'title': 'Active Leads', 'count': '12'},
    {'title': 'Tasks Today', 'count': '5'},
    {'title': 'Pending Verifications', 'count': '3'},
  ];

  late Timer _scrollTimer;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    const scrollStep = 1.0;
    const scrollInterval = Duration(milliseconds: 50);

    _scrollTimer = Timer.periodic(scrollInterval, (_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;

        if (currentScroll >= maxScroll) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.jumpTo(currentScroll + scrollStep);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollTimer.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _cards.length * 1000,
        itemBuilder: (context, index) {
          final card = _cards[index % _cards.length];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _summaryCard(card['title']!, card['count']!, widget.color),
          );
        },
      ),
    );
  }

  Widget _summaryCard(String title, String count, Color color) {
    return Card(
      elevation: 2,
      child: Container(
        height: 100,
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
