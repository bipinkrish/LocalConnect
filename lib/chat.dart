// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:localconnect/data.dart';

class ChatScreen extends StatefulWidget {
  final DiscoveredDevice peer;

  const ChatScreen({Key? key, required this.peer}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(String message) {
    setState(() {
      _messages.add(message);
    });

    // Add code to send the message to the peer here
    // You can use the peer's IP address or any other identifier to send the message
    // For example: send(message, widget.peer.ip);

    // Clear the message input field
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.peer.deviceName)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_messages[index]),
                  // You can customize how the messages are displayed here
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20, left: 15, right: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter your message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final message = _messageController.text;
                    if (message.isNotEmpty) {
                      _sendMessage(message);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
