import 'package:flutter/material.dart';

// --- 1. BRAND COLORS ---
const Color primaryColor = Color(0xFFF16831); // Deep Blue
const Color secondaryColor = Color(0xFF17A2B8); // Aqua/Teal
const Color accentColor = Color(0xFFF16831); // Coral/Orange
const Color lightBackgroundColor = Color(0xFFF4F7F9);
const Color cardColor = Colors.white;


class DocumentVaultPage extends StatelessWidget {
  const DocumentVaultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text("Document Vault", style: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.white
          ),),
          backgroundColor: accentColor,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Search and Filter
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search documents or clients...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: const Icon(Icons.filter_list, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
      
              // Sync Indicator
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.amber.shade800),
                    const SizedBox(width: 8.0),
                    Text('Syncing 3 files... Please wait until completed.', style: TextStyle(color: Colors.amber.shade800, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
      
              const Text('Client Folders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12.0),
      
              // Folder Structure
              _buildFolderItem('Jackson, Michael - ID: 7890', '6 documents, last updated 2 hours ago'),
              _buildFolderItem('Patel, Neha - ID: 1234', '12 documents, fully synced'),
              _buildFolderItem('Smith, John - ID: 5678', '4 documents, last updated 2 days ago'),
      
              const SizedBox(height: 24.0),
              const Text('Documents for Patel, Neha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12.0),
      
              // File List Example
              _buildFileItem('Contract_Draft_v3.pdf', '2.1 MB, Encrypted', Icons.picture_as_pdf, Colors.red),
              _buildFileItem('Payslip_March_2025.jpg', '450 KB, Encrypted', Icons.image, Colors.blue),
            ],
          ),
        ),
        // Floating Upload Button
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: accentColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
          child: const Icon(Icons.upload, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildFolderItem(String title, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ListTile(
        leading: Icon(Icons.folder_open, color: primaryColor, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {},
      ),
    );
  }

  Widget _buildFileItem(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove_red_eye, color: secondaryColor),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}