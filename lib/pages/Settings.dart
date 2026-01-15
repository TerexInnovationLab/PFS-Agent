import 'package:flutter/material.dart';

// --- 1. BRAND COLORS ---
const Color primaryColor = Color(0xFFF16831); // Deep Blue
const Color secondaryColor = Color(0xFF17A2B8); // Aqua/Teal
const Color accentColor = Color(0xFFF16831);// Coral/Orange
const Color lightBackgroundColor = Color(0xFFF4F7F9);
const Color cardColor = Colors.white;
const Color yellow=Color(0xFFF5A821);


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Settings", style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white
          ),),
          backgroundColor: accentColor,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Account Section
              _buildSettingsCard(
                context,
                'Account',
                primaryColor,
                [
                  _buildSettingItem(context, 'Update Password', true),
                  _buildSettingToggle(context, 'Enable Biometrics (Face ID)', true, primaryColor),
                ],
              ),
        
              // App Preferences Section
              _buildSettingsCard(
                context,
                'App Preferences',
                primaryColor,
                [
                  _buildSettingToggle(context, 'Push Notifications', true, primaryColor),
                  _buildSettingAction(context, 'Offline Cache (55 MB)', 'Clear', accentColor),
                  _buildSettingAction(context, 'Data Sync', 'Force Sync', primaryColor, isButton: true),
                ],
              ),
        
              // About App Section
              _buildSettingsCard(
                context,
                'About App',
                Colors.grey.shade500,
                [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pinnacle Agent Portal - Version 2.1.0', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  ),
                ],
              ),
        
              const SizedBox(height: 24.0),
        
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Simplified confirmation for Flutter
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to log out?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Logout', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, String title, Color titleColor, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: titleColor)),
            const Divider(height: 16, color: Colors.transparent),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, String title, bool hasChevron) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          if (hasChevron) const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSettingToggle(BuildContext context, String title, bool initialValue, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          Switch(
            value: initialValue,
            onChanged: (bool newValue) {}, // Dummy onChanged
            activeColor: activeColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingAction(BuildContext context, String title, String actionText, Color actionColor, {bool isButton = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          isButton
              ? ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(actionText, style: const TextStyle(fontSize: 12)),
          )
              : TextButton(
            onPressed: () {},
            child: Text(actionText, style: TextStyle(color: actionColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}