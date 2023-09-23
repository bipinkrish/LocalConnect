// ignore_for_file: must_be_immutable

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:localconnect/data.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

class Settings extends StatefulWidget {
  String initialDeviceName;
  Settings({super.key, required this.initialDeviceName});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  // device name
  late String initialname;
  final FocusNode _deviceNameNode = FocusNode();
  late TextEditingController _deviceNameController;
  bool _deviceNameValid = false;

  // port
  final FocusNode _portNode = FocusNode();
  final TextEditingController _portController =
      TextEditingController(text: "4321");

  // colors
  Color meColor = defaultmeColor;
  Color youColor = defaultyouColor;
  late Color tempMe;
  late Color tempYou;

  // markdown
  bool markdown = defaultMarkdown;

  // theme
  int thememode = defaultThemeMode;

  // destination
  String destination = "LocalConnect";

  // setting folder
  Future<void> setDestinationFolder() async {
    final String? path;
    path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
      destination = path.replaceAll('\\', '/');
      if (!destination.contains("LocalConnect")) {
        destination += "/LocalConnect";
      }
      final destinationFolder = Directory(destination);
      if (!await destinationFolder.exists()) {
        await destinationFolder.create(recursive: true);
      }
      save(destKey, destination);
      refresh();
    }
  }

  // initial device name
  void initailizeDevicename() {
    initialname = widget.initialDeviceName;
    _deviceNameController = TextEditingController(text: initialname);
    _deviceNameController.addListener(() {
      _deviceNameValid = _deviceNameController.text.isNotEmpty &&
          _deviceNameNode.hasFocus &&
          (initialname != _deviceNameController.text);
      refresh();
    });
  }

  // initial colors
  void initializeColors() async {
    List<String> temp = (await load(meColorKey, defaultMeColor)).split(",");
    List<int> intList = temp.map((str) => int.tryParse(str) ?? 0).toList();
    tempMe = Color.fromARGB(intList[0], intList[1], intList[2], intList[3]);

    temp = (await load(youColorKey, defaultYouColor)).split(",");
    intList = temp.map((str) => int.tryParse(str) ?? 0).toList();
    tempYou = Color.fromARGB(intList[0], intList[1], intList[2], intList[3]);

    meColor = tempMe;
    youColor = tempYou;
    refresh();
  }

  void initializeMarkdown() async {
    markdown = (await loadBool(markdownKey, defaultMarkdown));
    refresh();
  }

  void initializeThemeMode() async {
    thememode = (await loadInt(themeKey, defaultThemeMode));
    refresh();
  }

  void initialzeDestination() async {
    destination = await getDestination();
    refresh();
  }

  @override
  void initState() {
    // device name
    initailizeDevicename();
    // color
    initializeColors();
    // markdown
    initializeMarkdown();
    //theme mode
    initializeThemeMode();
    // destination
    initialzeDestination();

    super.initState();
  }

  @override
  void dispose() {
    // device name
    _deviceNameController.dispose();
    _deviceNameNode.unfocus();
    _deviceNameNode.dispose();

    // port
    _portController.dispose();
    _portNode.unfocus();
    _portNode.dispose();

    super.dispose();
  }

  // shoing snal
  void showSnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content, context));
  }

  // container for setting row
  ListTile getCont(
      {dynamic leading,
      title,
      dynamic subtitle,
      dynamic trailing,
      bool dense = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      dense: dense,
    );
  }

  // group settings
  Padding getGroup(String title, List<ListTile> members) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.brown.shade50
              : Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            for (ListTile mem in members) mem
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 60,
            ),
            getGroup(
              "General",
              [
                getThemeSet(),
                getCustomMeSet(),
                getCustomYouSet(),
                getMarkdownSet()
              ],
            ),
            getGroup(
              "Receive",
              [getDestSet()],
            ),
            getGroup(
              "Network",
              [
                getNameSet(),
                getDiscoerSet(),
              ],
            ),
            getGroup("Advanced", [
              getPortSet(),
              getIpv6Set(),
            ]),

            // about card
            Padding(
              padding: const EdgeInsets.all(10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: mainColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/logo.png",
                      height: 200,
                    ),
                    const Text(
                      "LocalConnect",
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const Text(
                      "Version: $version",
                      style: TextStyle(color: Colors.white),
                    ),
                    const Text(
                      copyright,
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () {
                        launchUrl(Uri.parse(
                            "https://github.com/bipinkrish/LocalConnect"));
                      },
                      child: const Text(
                        "Source Code (GitHub)",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // destination
  ListTile getDestSet() {
    final TextEditingController destController =
        TextEditingController(text: destination);
    final FocusNode destNode = FocusNode();

    return getCont(
      title: const Text(
        "Destination Folder",
        style: TextStyle(color: mainColor),
      ),
      subtitle: TextField(
        focusNode: destNode,
        controller: destController,
        readOnly: true,
        onTapOutside: (event) => destNode.unfocus(),
      ),
      trailing: IconButton(
        onPressed: () {
          setDestinationFolder();
        },
        icon: const Icon(
          Icons.folder_copy_outlined,
          color: Colors.grey,
        ),
      ),
    );
  }

  // device name
  ListTile getNameSet() {
    void pressed() {
      _deviceNameNode.unfocus();
      if (_deviceNameValid) {
        save(deviceNameKey, _deviceNameController.text);
        initialname = _deviceNameController.text;
        _deviceNameValid = false;
        refresh();
        showSnack("Device Name Updated");
      } else if (initialname != _deviceNameController.text) {
        showSnack("Please Enter a Valid Name");
      }
    }

    return getCont(
      title: const Text(
        "Device Name",
        style: TextStyle(color: mainColor),
      ),
      subtitle: TextField(
        controller: _deviceNameController,
        focusNode: _deviceNameNode,
        maxLines: 1,
        maxLength: 16,
        maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
        onTapOutside: (event) => _deviceNameNode.unfocus(),
        onSubmitted: (value) => pressed(),
      ),
      trailing: IconButton(
        onPressed: () => pressed(),
        icon: Icon(
          Icons.done_outline,
          color: !_deviceNameValid ? Colors.grey : mainColor,
        ),
      ),
    );
  }

  // port
  ListTile getPortSet() {
    return getCont(
      title: const Text(
        "Port",
        style: TextStyle(color: mainColor),
      ),
      subtitle: TextField(
        controller: _portController,
        focusNode: _portNode,
        enabled: false,
        onTapOutside: (event) => _portNode.unfocus(),
      ),
      trailing: IconButton(
        onPressed: () {
          _portNode.unfocus();
        },
        icon: const Icon(
          Icons.lock_outline,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ipv6
  ListTile getIpv6Set() {
    return getCont(
      title: const Text(
        "IPv6",
        style: TextStyle(color: mainColor),
      ),
      subtitle: const Text("not ready yet"),
      trailing: CupertinoSwitch(
        applyTheme: true,
        value: false,
        onChanged: (value) {},
      ),
    );
  }

  // discoverable
  ListTile getDiscoerSet() {
    return getCont(
      title: const Text(
        "Discoverable",
        style: TextStyle(color: mainColor),
      ),
      subtitle: const Text("not ready yet"),
      trailing: CupertinoSwitch(
        applyTheme: true,
        value: false,
        onChanged: (value) {},
      ),
    );
  }

  // Custom yme message color
  ListTile getCustomMeSet() {
    return getCont(
      title: const Text(
        "Me Color",
        style: TextStyle(color: mainColor),
      ),
      subtitle: const Text("your side messages"),
      trailing: IconButton(
        onPressed: () {
          showColorSelecter(isMe: true);
        },
        icon: getColorPre(meColor),
      ),
    );
  }

  // Custom you message color
  ListTile getCustomYouSet() {
    return getCont(
      title: const Text(
        "You Color",
        style: TextStyle(color: mainColor),
      ),
      subtitle: const Text("other side messages"),
      trailing: IconButton(
        onPressed: () {
          showColorSelecter(isMe: false);
        },
        icon: getColorPre(youColor),
      ),
    );
  }

  // markdown
  ListTile getMarkdownSet() {
    return getCont(
      title: const Text(
        "MarkDown",
        style: TextStyle(color: mainColor),
      ),
      subtitle: const Text("parse mode"),
      trailing: CupertinoSwitch(
        applyTheme: true,
        value: markdown,
        onChanged: (value) {
          saveBool(markdownKey, value);
          markdown = value;
          refresh();
        },
      ),
    );
  }

  // theme mode
  ListTile getThemeSet() {
    return getCont(
      title: const Text(
        "Theme Mode",
        style: TextStyle(color: mainColor),
      ),
      subtitle: const Text("switch between modes"),
      trailing: ToggleSwitch(
        initialLabelIndex: thememode,
        totalSwitches: 3,
        minHeight: 50,
        minWidth: 50,
        centerText: true,
        activeBgColor: const [mainColor],
        icons: const [
          Icons.light_mode_outlined,
          Icons.dark_mode_outlined,
          Icons.monitor_outlined
        ],
        onToggle: (index) {
          switch (index) {
            case 0:
              AdaptiveTheme.of(context).setLight();
              break;

            case 1:
              AdaptiveTheme.of(context).setDark();
              break;

            case 2:
              AdaptiveTheme.of(context).setSystem();
          }
          thememode = index!;
          saveInt(themeKey, index);
          refresh();
        },
      ),
    );
  }

  // color picker
  void showColorSelecter({bool isMe = true}) {
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ColorPicker(
                pickerColor: isMe ? meColor : youColor,
                onColorChanged: (value) {
                  if (isMe) {
                    meColor = value;
                  } else {
                    youColor = value;
                  }
                },
                colorPickerWidth: 200,
                labelTypes: const [ColorLabelType.rgb],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (isMe) {
                        meColor = tempMe;
                      } else {
                        youColor = tempYou;
                      }
                      Navigator.pop(context);
                      refresh();
                    },
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final selected = isMe ? meColor : youColor;
                      if (isMe) {
                        tempMe = meColor;
                      } else {
                        tempYou = youColor;
                      }
                      save(isMe ? meColorKey : youColorKey,
                          "${selected.alpha},${selected.red},${selected.green},${selected.blue}");
                      Navigator.pop(context);
                      refresh();
                      showSnack("Custom ${isMe ? 'Me' : 'You'} Color Updated");
                    },
                    child: const Text("Done"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // color preview
  Container getColorPre(Color clr) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: clr,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
