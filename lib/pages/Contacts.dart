import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../layouts/Colors.dart';
import '../pages/Messages.dart'; // 👈 make sure this import points to your Messages.dart file

class Contacts extends StatefulWidget {
  @override
  ContactsState createState() => ContactsState();
}

class ContactsState extends State<Contacts> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchContacts() async {
    if (await FlutterContacts.requestPermission()) {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission to access contacts denied')),
      );
    }
  }

  void _filterContacts() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((contact) {
        final name = contact.displayName.toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  void _openMessages(Contact contact) {
    final name = contact.displayName;
    final number = contact.phones.isNotEmpty ? contact.phones.first.number : 'No number';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Messages(
          contactName: name,
          contactNumber: number,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Contacts",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: AppColors.accent,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // 🔍 Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 🧾 Contacts list
          Expanded(
            child: _filteredContacts.isEmpty
                ? Center(child: Text("No contacts found"))
                : ListView.builder(
              itemCount: _filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = _filteredContacts[index];
                return ListTile(
                  onTap: () => _openMessages(contact),
                  leading: contact.photo != null
                      ? CircleAvatar(backgroundImage: MemoryImage(contact.photo!))
                      : CircleAvatar(child: Text(contact.displayName[0])),
                  title: Text(contact.displayName),
                  subtitle: Text(contact.phones.isNotEmpty
                      ? contact.phones.first.number
                      : 'No phone number'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
