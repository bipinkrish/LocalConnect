import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

////////////////////////////////////////////////////////////// Constants

const Color mainColor = Colors.deepOrange;

///////////////////////////////////////////////////////////// Custom Classes

class DiscoveredDevice {
  final String ip;
  final String deviceName;

  DiscoveredDevice(this.ip, this.deviceName);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredDevice &&
        other.ip == ip &&
        other.deviceName == deviceName;
  }

  @override
  int get hashCode => ip.hashCode ^ deviceName.hashCode;
}

class DiscoveredNetwork {
  final String addr;
  final String name;

  DiscoveredNetwork(this.addr, this.name);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredNetwork &&
        other.addr == addr &&
        other.name == name;
  }

  @override
  int get hashCode => addr.hashCode ^ name.hashCode;
}

class Message {
  final String text;
  final bool you;

  Message(this.text, this.you);
}

///////////////////////////////////////////////////////////// Others

Future<List<DiscoveredNetwork>> getLocalIP() async {
  List<NetworkInterface> interfaces =
      await NetworkInterface.list(type: InternetAddressType.IPv4);
  Set<DiscoveredNetwork> discoverNet = {};
  discoverNet.addAll(interfaces.map((interface) =>
      DiscoveredNetwork(interface.addresses[0].address, interface.name)));

  return discoverNet.toList();
}

Future<String> getDeviceName() async {
  if (await isStored(deviceNameKey)) {
    return await get(deviceNameKey);
  }

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    try {
      AndroidDeviceInfo info = await deviceInfo.androidInfo;
      return info.model;
    } catch (e) {
      return "Android";
    }
  } else if (Platform.isIOS) {
    try {
      IosDeviceInfo info = await deviceInfo.iosInfo;
      return info.name;
    } catch (e) {
      return "Ios";
    }
  } else if (Platform.isLinux) {
    try {
      LinuxDeviceInfo info = await deviceInfo.linuxInfo;
      return info.prettyName;
    } catch (e) {
      return "Linux";
    }
  } else if (Platform.isMacOS) {
    try {
      MacOsDeviceInfo info = await deviceInfo.macOsInfo;
      return info.computerName;
    } catch (e) {
      return "MacOS";
    }
  } else if (Platform.isWindows) {
    try {
      WindowsDeviceInfo info = await deviceInfo.windowsInfo;
      return info.computerName;
    } catch (e) {
      return "Windows";
    }
  } else {
    return "Device";
  }
}

///////////////////////////////////////////////////////////// Providers

final providerContainer = ProviderContainer();

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<Message>>((ref) {
  return ChatMessagesNotifier();
});

class ChatMessagesNotifier extends StateNotifier<List<Message>> {
  ChatMessagesNotifier() : super([]);

  void resetState() {
    state = [];
  }

  void addMessage(String message, bool you) {
    state = [...state, Message(message, you)];
  }
}

//////////////////////////////////////////////////// Common

SnackBar snackbar(String content) {
  return SnackBar(
    duration: const Duration(milliseconds: 800),
    backgroundColor: mainColor,
    content: Center(
      child: Text(
        content,
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

/////////////////////////////////////////////////// Shared Prefrences

String deviceNameKey = "DeviceName";

void save(String key, String value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

Future<bool> isStored(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(key);
}

Future<String> get(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(key) ?? "Null";
}
