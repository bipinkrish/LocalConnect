// ignore_for_file: must_be_immutable

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/socket.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final DiscoveredDevice peer;
  final int port;

  const ChatScreen({Key? key, required this.peer, required this.port})
      : super(key: key);

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  List<Message> messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageNode = FocusNode();

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void listener() {
    providerContainer.listen(
      chatMessagesProvider,
      (previous, next) {
        setState(() {
          messages = providerContainer.read(chatMessagesProvider);
        });
        _scrollToBottom();
      },
    );
  }

  @override
  void initState() {
    listener();
    super.initState();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageNode.unfocus();
    _messageNode.dispose();

    super.dispose();
  }

  bool isComputer() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  bool isMobile() {
    return Platform.isAndroid || Platform.isIOS;
  }

  void _sendMessage(String message) {
    if (message.isNotEmpty) {
      sendMessage(widget.peer.ip, widget.port, message);
      final notifier = providerContainer.read(chatMessagesProvider.notifier);
      notifier.addMessage(message, true);
      _messageController.clear();
    } else {
      _messageNode.unfocus();
    }
  }

  void showExiting() {}

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        showExiting();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.peer.deviceName)),
        body: Column(
          children: <Widget>[
            const SizedBox(
              height: 10,
            ),
            buildMsgs(),
            Padding(
              padding: const EdgeInsets.only(
                  bottom: 10, left: 15, right: 10, top: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      autofocus: !isMobile(),
                      focusNode: _messageNode,
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Enter your message...',
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (message) {
                        _sendMessage(message);
                        _messageNode.requestFocus();
                      },
                      // onTapOutside: (event) => _messageNode.unfocus(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send_outlined,
                      color: mainColor,
                    ),
                    onPressed: () {
                      _sendMessage(_messageController.text);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Expanded buildMsgs() {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final isYou = message.isYou;

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
