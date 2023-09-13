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
  late FocusNode _deviceNameNode;
  late TextEditingController _deviceNameController;
  bool _deviceNameValid = false;

  // port
  late FocusNode _portNode;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();

    // device name
    _deviceNameNode = FocusNode();
    _deviceNameController =
        TextEditingController(text: widget.initialDeviceName);
    _deviceNameController.addListener(() {
      setState(() {
        _deviceNameValid = _deviceNameController.text.isNotEmpty &&
            _deviceNameNode.hasFocus &&
            (widget.initialDeviceName != _deviceNameController.text);
      });
    });

    // port
    _portNode = FocusNode();
    _portController = TextEditingController(text: "4321");
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  void showSnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content));
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
          Container(
            padding:
                const EdgeInsets.only(top: 5, bottom: 5, left: 15, right: 5),
            color: Colors.black26,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Device Name",
                style: TextStyle(color: Colors.green),
              ),
              subtitle: TextField(
                controller: _deviceNameController,
                focusNode: _deviceNameNode,
              ),
              trailing: IconButton(
                onPressed: () {
                  _deviceNameNode.unfocus();
                  if (_deviceNameValid) {
                    save(deviceNameKey, _deviceNameController.text);
                    widget.initialDeviceName = _deviceNameController.text;
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
          ),
          const SizedBox(
            height: 10,
          ),

          // port
          Container(
            padding:
                const EdgeInsets.only(top: 5, bottom: 5, left: 15, right: 5),
            color: Colors.black26,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Port",
                style: TextStyle(color: Colors.red),
              ),
              subtitle: TextField(
                controller: _portController,
                focusNode: _portNode,
                readOnly: true,
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
          ),
          const SizedBox(
            height: 10,
          ),

          // ipv6
          Container(
            padding:
                const EdgeInsets.only(top: 5, bottom: 5, left: 15, right: 5),
            color: Colors.black26,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "IPv6",
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text("not ready yet"),
              trailing: CupertinoSwitch(
                value: false,
                onChanged: (value) {},
              ),
            ),
          ),
          const SizedBox(
            height: 10,
          ),

          // discoverable
          Container(
            padding:
                const EdgeInsets.only(top: 5, bottom: 5, left: 15, right: 5),
            color: Colors.black26,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Discoverable",
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text("not ready yet"),
              trailing: CupertinoSwitch(
                value: false,
                onChanged: (value) {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}
