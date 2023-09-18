// ignore_for_file: must_be_immutable

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:localconnect/data.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:toggle_switch/toggle_switch.dart';

class Settings extends StatefulWidget {
  String initialDeviceName;
  Settings({super.key, required this.initialDeviceName});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  // device name
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

  // initial device name
  void initailizeDevicename() {
    _deviceNameController =
        TextEditingController(text: widget.initialDeviceName);
    _deviceNameController.addListener(() {
      _deviceNameValid = _deviceNameController.text.isNotEmpty &&
          _deviceNameNode.hasFocus &&
          (widget.initialDeviceName != _deviceNameController.text);
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
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content));
  }

  // container for setting row
  Padding getCont(
      {dynamic leading,
      title,
      dynamic subtitle,
      dynamic trailing,
      bool dense = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.only(top: 5, bottom: 5, left: 15, right: 10),
        color: Colors.black26,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          dense: dense,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // device name
            getCont(
              title: const Text(
                "Device Name",
                style: TextStyle(color: mainColor),
              ),
              subtitle: TextField(
                controller: _deviceNameController,
                focusNode: _deviceNameNode,
                onTapOutside: (event) => _deviceNameNode.unfocus(),
              ),
              trailing: IconButton(
                onPressed: () {
                  _deviceNameNode.unfocus();
                  if (_deviceNameValid) {
                    save(deviceNameKey, _deviceNameController.text);
                    widget.initialDeviceName = _deviceNameController.text;
                    _deviceNameValid = false;
                    refresh();
                    showSnack("Device Name Updated");
                  } else if (widget.initialDeviceName !=
                      _deviceNameController.text) {
                    showSnack("Please Enter a Valid Name");
                  }
                },
                icon: Icon(
                  Icons.done_outline,
                  color: !_deviceNameValid ? Colors.grey : mainColor,
                ),
              ),
            ),

            // port
            getCont(
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
            ),

            // ipv6
            getCont(
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
            ),

            // discoverable
            getCont(
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
            ),

            // Custom me message color
            getCont(
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
            ),

            // Custom you message color
            getCont(
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
            ),

            // markdown
            getCont(
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
            ),

            // theme mode
            getCont(
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
            )
          ],
        ),
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
                      refresh();
                      Navigator.pop(context);
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
                      refresh();
                      Navigator.pop(context);
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
