// ignore_for_file: must_be_immutable, unused_import, depend_on_referenced_packages

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/socket.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Color meColor = defaultmeColor;
  Color youColor = defaultyouColor;
  bool markdown = defaultMarkdown;
  final notifier = providerContainer.read(chatMessagesProvider.notifier);
  bool isComputer = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  bool isMobile = Platform.isAndroid || Platform.isIOS;

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

  void initializeColors() async {
    List<String> temp = (await load(meColorKey, defaultMeColor)).split(",");
    List<int> intList = temp.map((str) => int.tryParse(str) ?? 0).toList();
    meColor = Color.fromARGB(intList[0], intList[1], intList[2], intList[3]);

    temp = (await load(youColorKey, defaultYouColor)).split(",");
    intList = temp.map((str) => int.tryParse(str) ?? 0).toList();
    youColor = Color.fromARGB(intList[0], intList[1], intList[2], intList[3]);

    if (mounted) {
      setState(() {});
    }
  }

  void initializeMarkdown() async {
    markdown = (await loadBool(markdownKey, defaultMarkdown));
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    listener();
    initializeColors();
    initializeMarkdown();
    Future(
      () {
        _sendMessage("${widget.me.deviceName} connected", info: true);
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

  void _sendMessage(String message, {bool info = false}) {
    if (message.isNotEmpty) {
      sendMessage(
          widget.peer.ip, widget.port, message.trim(), info ? "1" : "0");
      notifier.addMessage(message, true, info: info);
      _messageController.clear();
    } else if (isMobile) {
      _messageNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _sendMessage("${widget.me.deviceName} disconnected", info: true);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.peer.deviceName)),
        body: Column(
          children: [
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
                      focusNode: _messageNode,
                      controller: _messageController,
                      autofocus: isComputer,
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
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.send_outlined,
                      color: mainColor,
                    ),
                    onPressed: () {
                      _sendMessage(_messageController.text);
                      _messageNode.requestFocus();
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
    DateTime? prevMessageTime;

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final showTime = prevMessageTime == null ||
              message.time.minute != prevMessageTime?.minute;
          prevMessageTime = message.time;

          return Column(
            children: [
              if (showTime)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    "${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Align(
                alignment: message.isInfo
                    ? Alignment.center
                    : message.isYou
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 20),
                  padding: message.isInfo
                      ? const EdgeInsets.all(6)
                      : const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isInfo
                        ? Colors.grey
                        : message.isYou
                            ? meColor
                            : youColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: markdown
                      ? SizedBox(
                          child: MarkdownBody(
                            onTapLink: (text, href, title) async {
                              final url = Uri.parse(href!);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            data: message.text,
                            selectable: true,
                          ),
                        )
                      : SelectableText(message.text),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
