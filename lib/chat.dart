// ignore_for_file: must_be_immutable, unused_import, depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/socket.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final DiscoveredDevice me;
  final DiscoveredDevice peer;
  final int port;

  const ChatScreen(
      {Key? key, required this.me, required this.peer, required this.port})
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
        final updatedMessages = providerContainer.read(chatMessagesProvider);
        final filteredMessages = updatedMessages.where((message) {
          return !(message.isYou && message.isInfo);
        }).toList();
        if (mounted) {
          setState(() {
            messages = filteredMessages;
          });
        }
        _scrollToBottom();
      },
    );
  }

  @override
  void initState() {
    listener();
    Future(
      () {
        _sendMessage("_${widget.me.deviceName} connected_", info: true);
      },
    );

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

  void _sendMessage(String message, {bool info = false}) {
    if (message.isNotEmpty) {
      sendMessage(widget.peer.ip, widget.port, message, info ? "1" : "0");
      final notifier = providerContainer.read(chatMessagesProvider.notifier);
      notifier.addMessage(message, true, info: info);
      _messageController.clear();
    } else {
      _messageNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _sendMessage("_${widget.me.deviceName} disconnected_", info: true);
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
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Enter your message...',
                        filled: true,
                        fillColor: Colors.black26,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
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

          return Align(
            alignment: message.isInfo
                ? Alignment.center
                : message.isYou
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
              padding: message.isInfo
                  ? const EdgeInsets.all(6)
                  : const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isInfo
                    ? Colors.grey
                    : message.isYou
                        ? Colors.blue
                        : Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                child: MarkdownBody(
                  data: message.text,
                  selectable: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
