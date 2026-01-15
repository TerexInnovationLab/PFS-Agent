import 'package:flutter/material.dart';

// --- 1. BRAND COLORS ---
const Color primaryColor = Color(0xFF0047AB); // Deep Blue
const Color secondaryColor = Color(0xFF17A2B8); // Aqua/Teal
const Color accentColor = Color(0xFFFF7F50); // Coral/Orange
const Color lightBackgroundColor = Color(0xFFF4F7F9);
const Color cardColor = Colors.white;


class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: Scaffold(


        appBar: AppBar(
          title: Text("Reports", style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white
          ),),
          backgroundColor: accentColor,
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Header and Export Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('KPI Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
        
              // KPI Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16.0,
                crossAxisSpacing: 16.0,
                childAspectRatio: 1.2,
                children: <Widget>[
                  _buildKPICard(
                    'Leads Onboarded',
                    '28',
                    '+8% vs Previous',
                    primaryColor,
                    Colors.green,
                    Icons.arrow_upward,
                  ),
                  _buildKPICard(
                    'Tasks Completed',
                    '94',
                    '+12% vs Previous',
                    secondaryColor,
                    Colors.green,
                    Icons.arrow_upward,
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
        
              // Total Collections Card (Full Width)
              _buildKPICard(
                'Total Collections (USD)',
                '\$15,400',
                '-3% vs Previous',
                accentColor,
                Colors.red,
                Icons.arrow_downward,
                isFullWidth: true,
              ),
              const SizedBox(height: 24.0),
        
              // Chart Placeholder
              const Text('Monthly Progress (Leads)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12.0),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Bar Chart Visualization Placeholder
                      Container(
                        height: 180,
                        alignment: Alignment.bottomCenter,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBar(Colors.grey.shade300, 0.3),
                            _buildBar(Colors.grey.shade300, 0.5),
                            _buildBar(secondaryColor, 0.75),
                            _buildBar(secondaryColor, 1.0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      const Text('Jan - Apr 2025 (Aqua: Current Month)', style: TextStyle(fontSize: 13, color: Colors.grey)),
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

  Widget _buildKPICard(
      String title,
      String value,
      String comparison,
      Color borderColor,
      Color comparisonColor,
      IconData comparisonIcon, {
        bool isFullWidth = false,
      }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
        border: Border(bottom: BorderSide(color: borderColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Text(value, style: TextStyle(fontSize: isFullWidth ? 36 : 30, fontWeight: FontWeight.w900, color: borderColor)),
          ),
          Row(
            children: [
              Icon(comparisonIcon, color: comparisonColor, size: 12),
              const SizedBox(width: 4.0),
              Text(comparison, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: comparisonColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(Color color, double heightFactor) {
    return Container(
      width: 40,
      height: 180 * heightFactor,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
    );
  }
}