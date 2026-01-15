import 'package:flutter/material.dart';

// --- 1. BRAND COLORS ---
const Color primaryColor = Color(0xFFF16831); // Deep Blue
const Color secondaryColor = Color(0xFF17A2B8); // Aqua/Teal
const Color accentColor = Color(0xFFF16831);// Coral/Orange
const Color lightBackgroundColor = Color(0xFFF4F7F9);
const Color cardColor = Colors.white;
const Color yellow=Color(0xFFF5A821);


class LeadsTasksPage extends StatelessWidget {
  const LeadsTasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Leads", style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white
          ),),
          backgroundColor: accentColor,
          centerTitle: true,
            automaticallyImplyLeading: false
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Tasks Due Summary Card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
                  ],
                  border: const Border(left: BorderSide(color: primaryColor, width: 4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tasks Due Today', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Text('12', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: primaryColor)),
                        const Text('2 overdue, 4 in progress', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    Icon(Icons.notifications_active, color: yellow, size: 30),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
        
              // Filters (Simulated tabs)
              Row(
                children: [
                  _buildFilterButton(context, 'Today (5)', true),
                  _buildFilterButton(context, 'Upcoming (18)', false),
                  _buildFilterButton(context, 'Completed (32)', false),
                ],
              ),
              const SizedBox(height: 24.0),
        
              const Text('Today\'s Focus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12.0),
        
              // Task List Item (Overdue)
              _buildTaskCard(
                context,
                'Aisha Khan',
                'Application Status: Pending Docs',
                Colors.red.shade600,
                'Site Visit & Verification',
                'Overdue: Yesterday at 4:00 PM',
                accentColor,
                Icons.access_time_filled,
                [
                  _buildActionButton('Call', Icons.phone, secondaryColor, Colors.white),
                  _buildActionButton('Message', Icons.mail, primaryColor, Colors.white),
                ],
              ),
        
              // Task List Item (Today)
              _buildTaskCard(
                context,
                'Ben Carter',
                'Application Status: Approved',
                Colors.green.shade600,
                'Final Contract Signing',
                'Due: Today at 10:30 AM',
                secondaryColor,
                Icons.calendar_month,
                [
                  _buildActionButton('Open Application', Icons.file_copy, secondaryColor, secondaryColor, isOutlined: true),
                  _buildActionButton('Add Note', Icons.add, primaryColor, Colors.white),
                ],
              ),
        
              const SizedBox(height: 20.0),
              Center(
                child: Text('No other high-priority tasks.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildFilterButton(BuildContext context, String text, bool isActive) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? primaryColor : Colors.grey.shade200,
            foregroundColor: isActive ? Colors.white : Colors.black87,
            elevation: isActive ? 4 : 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            minimumSize: Size.zero,
          ),
          child: Text(text, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildTaskCard(
      BuildContext context, String name, String status, Color statusColor,
      String task, String due, Color borderColor, IconData icon, List<Widget> actions) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border(left: BorderSide(color: borderColor, width: 4)),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                    ),
                  ],
                ),
                Icon(icon, color: borderColor),
              ],
            ),
            const SizedBox(height: 12.0),
            Text('Task: $task', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            Text(due, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: borderColor)),
            const SizedBox(height: 16.0),
            Row(children: actions),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, Color textColor, {bool isOutlined = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: OutlinedButton.icon(
          onPressed: () {},
          style: isOutlined
              ? OutlinedButton.styleFrom(
            side: BorderSide(color: color),
            foregroundColor: color,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10),
          )
              : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: textColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            elevation: 2,
          ),
          icon: Icon(icon, size: 16),
          label: Text(text, style: const TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}