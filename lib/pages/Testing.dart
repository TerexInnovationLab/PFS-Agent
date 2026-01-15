import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pfs_agent/config/api_config.dart';


import 'database_helper.dart';

import 'package:intl/intl.dart'; // 👈 for date/time

class Testing extends StatefulWidget {
  const Testing({super.key});

  @override
  State<Testing> createState() => _TestingState();
}

class _TestingState extends State<Testing> {
  final TextEditingController agentCodeController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  bool isLoading = false;


  Future<void> storeChat() async {
    setState(() => isLoading = true);

    const String url = ApiConfig.baseUrl + "/chats";

    // Build message JSON (single source of truth)
    final Map<String, dynamic> messageData = {
      "sender_code": "011020",
      "user_name": messageController.text.trim(),
      "message": messageController.text.trim(),
      "links": null,
      "sender_type": "owner",
      "time": DateFormat("HH:mm").format(DateTime.now()),
      "date": DateFormat("dd/MM/yyyy").format(DateTime.now()),
    };

    final Map<String, dynamic> messageData2 = {
      "sender_code": "011020",
      "user_name": messageController.text.trim(),
      "message": messageController.text.trim(),
      "links": null,
      "sender_type": "owner",
      "time": DateFormat("HH:mm").format(DateTime.now()),
      "date": DateFormat("dd/MM/yyyy").format(DateTime.now()),
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "agent_code": agentCodeController.text.trim(),
          "message": messageData2,
        }),
      );

      if (response.statusCode == 201) {
        // ✅ SAVE LOCALLY ONLY AFTER SUCCESS
        await DatabaseHelper.instance.insertOrUpdateChat(
          agentCode: agentCodeController.text.trim(),
          messageData: messageData,
        );

        messageController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent & saved')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }

    setState(() => isLoading = false);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Testing"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: agentCodeController,
              decoration: const InputDecoration(
                labelText: "Agent Code",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: "Message",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: isLoading ? null : storeChat,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Send Message"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
