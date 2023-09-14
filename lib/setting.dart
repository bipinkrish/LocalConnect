// ignore_for_file: must_be_immutable

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:localconnect/data.dart';

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

  @override
  void initState() {
    super.initState();

    // device name
    _deviceNameController =
        TextEditingController(text: widget.initialDeviceName);
    _deviceNameController.addListener(() {
      setState(() {
        _deviceNameValid = _deviceNameController.text.isNotEmpty &&
            _deviceNameNode.hasFocus &&
            (widget.initialDeviceName != _deviceNameController.text);
      });
    });
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

  void showSnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content));
  }

  Container getCont(
      {required Widget title,
      required Widget subtitle,
      required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.only(top: 5, bottom: 5, left: 15, right: 5),
      color: Colors.black26,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: Column(
        children: [
          const SizedBox(
            height: 10,
          ),

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
                  setState(() {
                    _deviceNameValid = false;
                  });
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

          const SizedBox(
            height: 10,
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
          const SizedBox(
            height: 10,
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
          const SizedBox(
            height: 10,
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
        ],
      ),
    );
  }
}
