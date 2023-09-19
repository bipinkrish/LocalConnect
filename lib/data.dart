import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

////////////////////////////////////////////////////////////// Constants

const String version = "v1.2.5";
const String copyright = "© 2023 Bipin";
const Color mainColor = Colors.deepOrange;

const String deviceNameKey = "DeviceName";
const String youColorKey = 'YouColor';
const String meColorKey = 'MeColor';
const String markdownKey = 'MarkDown';
const String themeKey = 'ThemeMode';

const Color defaultmeColor = Colors.blue;
const Color defaultyouColor = Colors.green;
final String defaultMeColor = defaultmeColor.hashCode.toString();
final String defaultYouColor = defaultyouColor.hashCode.toString();
const bool defaultMarkdown = false;
const int defaultThemeMode = 2;

///////////////////////////////////////////////////////////// Custom Classes

class DiscoveredDevice {
  final String ip;
  final String deviceName;
  final int type;

  DiscoveredDevice(this.ip, this.deviceName, this.type);

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
  final bool isYou;
  final String time;
  final bool isInfo;

  Message(this.text, this.isYou, this.time, {this.isInfo = false});
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

  void addMessage(String message, bool you, {bool info = false}) {
    state = [
      ...state,
      Message(message, you, formatTime(DateTime.now()), isInfo: info)
    ];
  }
}

//////////////////////////////////////////////////// Common

SnackBar snackbar(String content, BuildContext context) {
  final darkmode = Theme.of(context).brightness == Brightness.dark;
  return SnackBar(
    duration: const Duration(milliseconds: 800),
    backgroundColor: darkmode ? mainColor.withAlpha(40) : Colors.brown.shade50,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(40),
        topRight: Radius.circular(40),
      ),
    ),
    content: Center(
      child: Text(
        content,
        style: TextStyle(
          color: darkmode ? Colors.white : Colors.black,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  );
}

String formatTime(DateTime time) {
  String period = time.hour < 12 ? 'AM' : 'PM';
  int formattedHour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  String hour = formattedHour.toString().padLeft(2, '0');
  String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

// check valid ip
bool isValidIPAddress(String input) {
  final RegExp ipv4RegExp = RegExp(
    r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
    caseSensitive: false,
  );

  final RegExpMatch? match = ipv4RegExp.firstMatch(input);

  if (match == null) {
    return false;
  }

  for (int i = 1; i <= 4; i++) {
    final int octet = int.parse(match[i]!);
    if (octet < 0 || octet > 255) {
      return false;
    }
  }

  return true;
}

// row of key value
Row getrow(String name, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text("$name "),
      Text(
        value.length <= 20 ? value : '${value.substring(0, 20)}...',
        style: const TextStyle(color: mainColor),
      )
    ],
  );
}

/////////////////////////////////////////////////// Shared Prefrences

void save(String key, String value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString(key, value);
}

void saveBool(String key, bool value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(key, value);
}

void saveInt(String key, int value) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt(key, value);
}

Future<bool> isStored(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(key);
}

Future<String> get(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(key) ?? "Null";
}

Future<bool> getBool(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool(key) ?? true;
}

Future<int> getInt(String key) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getInt(key) ?? 0;
}

Future<String> load(String key, String def) async {
  if (await isStored(key)) {
    return await get(key);
  }
  return def;
}

Future<bool> loadBool(String key, bool def) async {
  if (await isStored(key)) {
    return await getBool(key);
  }
  return def;
}

Future<int> loadInt(String key, int def) async {
  if (await isStored(key)) {
    return await getInt(key);
  }
  return def;
}

/////////////////////////////////////////////////////////// Themes

final lighttheme = ThemeData.from(
  useMaterial3: true,
  colorScheme: const ColorScheme.light(
    primary: mainColor,
    onPrimary: Colors.black,
  ),
);

final darktheme = ThemeData.from(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(
    primary: mainColor,
    onPrimary: Colors.white,
    secondaryContainer: Colors.black54,
  ),
);

//////////////////////////////////////////// Platform Icon

final thisSysIcon = platformIcons[getPlatformType()];

const Map<int, IconData> platformIcons = {
  0: Icons.device_unknown_outlined,
  1: Icons.android_outlined,
  2: Custom.iphone,
  3: Icons.window,
  4: Custom.linux,
  5: Icons.desktop_mac
};

int getPlatformType() {
  if (Platform.isAndroid) {
    return 1;
  }
  if (Platform.isIOS) {
    return 2;
  }
  if (Platform.isWindows) {
    return 3;
  }
  if (Platform.isLinux) {
    return 4;
  }
  if (Platform.isMacOS) {
    return 5;
  } else {
    return 0;
  }
}

///////////////////////////////////////////////// Custom

class Custom {
  Custom._();

  static const _kFontFam = 'Custom';
  static const String? _kFontPkg = null;

  static const IconData iphone =
      IconData(0xf034, fontFamily: _kFontFam, fontPackage: _kFontPkg);
  static const IconData linux =
      IconData(0xf17c, fontFamily: _kFontFam, fontPackage: _kFontPkg);
}
