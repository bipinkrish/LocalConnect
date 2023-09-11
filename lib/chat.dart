// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/socket.dart';

class ChatScreen extends StatefulWidget {
  final DiscoveredDevice peer;
  final int port;

  const ChatScreen({Key? key, required this.peer, required this.port})
      : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(String message) {
    sendMessage(widget.peer.ip, widget.port, message);
    final notifier = providerContainer.read(chatMessagesProvider.notifier);
    notifier.addMessage(message, true);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.peer.deviceName)),
      body: Column(
        children: <Widget>[
          const SizedBox(
            height: 10,
          ),
          const Msgs(),
          Padding(
            padding:
                const EdgeInsets.only(bottom: 10, left: 15, right: 10, top: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (message) {
                      if (message.isNotEmpty) {
                        _sendMessage(message);
                      }
                    },
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

class Msgs extends ConsumerStatefulWidget {
  const Msgs({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MsgsState();
}

class _MsgsState extends ConsumerState<Msgs> {
  List<Message> messages = [];

  @override
  Widget build(BuildContext context) {
    providerContainer.listen(
      chatMessagesProvider,
      (previous, next) {
        setState(() {
          messages = providerContainer.read(chatMessagesProvider);
        });
      },
    );
    return Expanded(
      child: ListView.builder(
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final isYou = message.you;

          return Align(
            alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isYou ? Colors.blue : Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
