import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../layouts/Colors.dart';

class Messages extends StatefulWidget {
  final String contactName;
  final String contactNumber;

  const Messages({
    super.key,
    required this.contactName,
    required this.contactNumber,
  });

  @override
  MessagesState createState() => MessagesState();
}

class MessagesState extends State<Messages> {
  final TextEditingController _messageController = TextEditingController();

  List<Map<String, dynamic>> messages = [
    {
      "text": "Hello, how are you?",
      "isMe": false,
      "time": "09:30 AM",
    },
    {
      "text": "I'm good, thanks! How about you?",
      "isMe": true,
      "time": "09:31 AM",
    },
  ];

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      messages.add({
        "text": _messageController.text.trim(),
        "isMe": true,
        "time": "now",
      });
    });

    _messageController.clear();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      // For now we just show a "sent file" message.
      setState(() {
        messages.add({
          "text": "Sent file: ${file.name}",
          "isMe": true,
          "time": "now",
        });
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon:
          const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accent.withOpacity(0.3),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  widget.contactNumber,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
      body: Column(
        children: [
          // messages list
          Expanded(
            child: ListView.builder(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              physics: const BouncingScrollPhysics(),
              itemCount: messages.length,
              reverse: true,
              itemBuilder: (context, index) {
                final msg = messages[messages.length - 1 - index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // input bar above system nav bar
          SafeArea(
            top: false,
            child: _buildInputBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isMe = msg["isMe"];
    String text = msg["text"];
    String time = msg["time"];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFFCCCCCC),
              child: Icon(Icons.person, size: 14, color: Colors.white),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                isMe ? AppColors.primary.withOpacity(0.90) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey,
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

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // message field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.textSecondary.withOpacity(0.15),
                ),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // 📎 attach any file
          IconButton(
            icon: Icon(
              Icons.attach_file_rounded,
              color: AppColors.secondary,
              size: 24,
            ),
            onPressed: _pickFile,
          ),

          // send button
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.send, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
