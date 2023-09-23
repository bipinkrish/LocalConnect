// ignore_for_file: must_be_immutable, unused_import, depend_on_referenced_packages, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/network.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';

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
  late ProviderSubscription listenerObj;

  void _scrollToBottom() {
    try {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void listener() {
    listenerObj = providerContainer.listen(
      chatMessagesProvider,
      (previous, next) {
        final updatedMessages = providerContainer.read(chatMessagesProvider);
        final filteredMessages = updatedMessages.where((message) {
          return !(message.isYou && message.isInfo);
        }).toList();
        messages = filteredMessages;
        refresh();
        _scrollToBottom();
      },
      onError: (error, stackTrace) {
        debugPrint(error.toString());
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

    refresh();
  }

  void initializeMarkdown() async {
    markdown = (await loadBool(markdownKey, defaultMarkdown));
    refresh();
  }

  @override
  void initState() {
    listener();
    initializeColors();
    initializeMarkdown();
    Future(
      () {
        _sendTextMessage("${widget.me.deviceName} connected", info: true);
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
    listenerObj.close();
    super.dispose();
  }

  void _sendTextMessage(String message, {bool info = false}) {
    if (message.isNotEmpty) {
      sendText(widget.peer.ip, widget.port, message.trim(), info);
      notifier.addMessage(message.trim(), true, "TEXT", info: info);
      _messageController.clear();
    } else if (isMobile) {
      _messageNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _sendTextMessage("${widget.me.deviceName} disconnected", info: true);
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
                children: [
                  Expanded(
                    child: TextField(
                      focusNode: _messageNode,
                      controller: _messageController,
                      autofocus: isComputer,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Send a message...',
                        filled: true,
                        fillColor:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.brown.shade50
                                : Colors.black54,
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
                    color: mainColor,
                    icon: const Icon(
                      Icons.attach_file_outlined,
                    ),
                    onPressed: () {
                      _showAttachmentOptions();
                    },
                  ),
                  IconButton(
                    color: mainColor,
                    icon: const Icon(
                      Icons.send_outlined,
                    ),
                    onPressed: () {
                      _sendTextMessage(_messageController.text);
                      if (isComputer) _messageNode.requestFocus();
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
    String? prevMessageTime;

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          final showTime =
              prevMessageTime == null || message.time != prevMessageTime;
          prevMessageTime = message.time;

          return Column(
            children: [
              if (showTime)
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    message.time,
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
                        ? Theme.of(context).brightness == Brightness.light
                            ? Colors.brown.shade50
                            : Colors.grey
                        : message.isYou
                            ? meColor
                            : youColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: showMsgContent(message),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget showText(String content) {
    return markdown
        ? SizedBox(
            child: MarkdownBody(
              onTapLink: (text, href, title) async {
                final url = Uri.parse(href!);
                if (await canLaunchUrl(url)) {
                  launchUrl(url);
                }
              },
              data: content,
              selectable: true,
            ),
          )
        : SelectableText(content);
  }

  Widget showMsgContent(Message message) {
    switch (message.type) {
      case "TEXT":
        return showText(message.data);
      case "IMAGE":
        return Image.file(File(message.data));
      // case "AUDIO":
      //   return AudioPlayer(message.data);
      // case "VIDEO":
      //   return VideoPlayer(message.data);
      // case "FILE":
      //   return FileViewer(message.data);
      default:
        return const Icon(Icons.question_mark_outlined);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(10),
          height: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  IconButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.gallery);
                      Navigator.pop(context);
                      if (image != null) {
                        sendImage(widget.peer.ip, widget.port, image, false);
                        notifier.addMessage(image.path, true, "IMAGE");
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                  ),
                  const Text("Image")
                ],
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.videocam_outlined),
                  ),
                  const Text("Video")
                ],
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () async {
                      final XFile? file = await openFile();
                      Navigator.pop(context);
                      debugPrint("file ${file!.path}");
                    },
                    icon: const Icon(Icons.insert_drive_file_outlined),
                  ),
                  const Text("File")
                ],
              ),
              Column(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.folder_outlined),
                  ),
                  const Text("Folder")
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // show snackbar
  void showSnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content, context));
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
