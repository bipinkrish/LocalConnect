import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

////////////////////////////////////////////////////////////// Constants

const String version = "v1.3.3";
const String copyright = "© 2023 Bipin";
const Color mainColor = Colors.deepOrange;
bool isComputer = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
bool isMobile = Platform.isAndroid || Platform.isIOS;

const String deviceNameKey = "DeviceName";
const String youColorKey = 'YouColor';
const String meColorKey = 'MeColor';
const String markdownKey = 'MarkDown';
const String themeKey = 'ThemeMode';
const String destKey = "Destination";

const Color defaultmeColor = Colors.blue;
const Color defaultyouColor = Colors.green;
final String defaultMeColor =
    "${defaultmeColor.alpha},${defaultmeColor.red},${defaultmeColor.green},${defaultmeColor.blue}";
final String defaultYouColor =
    "${defaultyouColor.alpha},${defaultyouColor.red},${defaultyouColor.green},${defaultyouColor.blue}";
const bool defaultMarkdown = false;
const int defaultThemeMode = 2;

Future<String> getDefaultDestination() async {
  if (Platform.isAndroid) {
    return (await getExternalStorageDirectory())!.path;
  } else {
    return (await getDownloadsDirectory())!.path;
  }
}

Future<String> getDestination() async {
  if (await isStored(destKey)) {
    return await get(destKey);
  }
  return await getDefaultDestination();
}

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
  final String data;
  final bool isYou;
  final String time;
  final String type;
  final bool isInfo;
  final double size;

  Message(this.data, this.isYou, this.time, this.type,
      {this.size = 0, this.isInfo = false});
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
  String ip = "";
  Set<String> folders = {};

  void resetState() {
    state = [];
    ip = "";
    folders = {};
  }

  void addMessage(String data, bool you, String type,
      {double size = 0, bool info = false}) {
    state = [
      ...state,
      Message(data, you, formatDateTime(DateTime.now()), type,
          size: size, isInfo: info)
    ];
  }

  void addFile(
    List<int> data,
    bool you,
    String type,
    String name,
  ) async {
    final destination = await getDestination();
    final finalpath = "$destination$name";
    debugPrint("Saving to $finalpath");

    final file = File(finalpath);
    await file.writeAsBytes(data);

    state = [
      ...state,
      Message(file.path, you, formatDateTime(DateTime.now()), type,
          size: getFileSize(file.path), isInfo: false)
    ];
  }

  void addFolder(
    List<int> data,
    bool you,
    String type,
    String name,
  ) async {
    final destination = await getDestination();
    final finalpath = "$destination$name";
    final destinationFolder = Directory(path.dirname(finalpath));
    if (!await destinationFolder.exists()) {
      await destinationFolder.create(recursive: true);
    }
    debugPrint("Saving to $finalpath");

    final file = File(finalpath);
    await file.writeAsBytes(data);

    final relPath = name.split("/")[1];
    if (!folders.contains(relPath)) {
      folders.add(relPath);
      state = [
        ...state,
        Message(
            "$destination/$relPath", you, formatDateTime(DateTime.now()), type,
            size: 0, isInfo: false)
      ];
    }
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

String formatDateTime(DateTime dateTime) {
  final String period = dateTime.hour < 12 ? 'AM' : 'PM';
  final int formattedHour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final String hour = formattedHour.toString().padLeft(2, '0');
  final String minute = dateTime.minute.toString().padLeft(2, '0');
  final String formattedTime = '$hour:$minute $period';

  final String formattedDate =
      '${_getDayOfWeek(dateTime.weekday)}, ${_getFormattedDate(dateTime)}';

  return '$formattedTime, $formattedDate';
}

String _getDayOfWeek(int dayOfWeek) {
  final List<String> daysOfWeek = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];
  return daysOfWeek[dayOfWeek - 1];
}

String _getFormattedDate(DateTime dateTime) {
  final String year = dateTime.year.toString();
  final String month = dateTime.month.toString().padLeft(2, '0');
  final String day = dateTime.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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

int maxlen = 16;

// row of key value
Row getrow(String name, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text("$name "),
      Text(
        value.length <= maxlen ? value : '${value.substring(0, maxlen)}...',
        style: const TextStyle(color: mainColor),
      )
    ],
  );
}

// col of key value
Column getcol(String name, String value) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(name),
      Text(
        value.length <= maxlen ? value : '${value.substring(0, maxlen)}...',
        style: const TextStyle(color: mainColor),
      )
    ],
  );
}

double getFileSize(String filePath) {
  File file = File(filePath);

  if (file.existsSync()) {
    int fileSizeBytes = file.lengthSync();
    return (fileSizeBytes / (1024 * 1024));
  } else {
    return -1;
  }
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

final thisPlatform = getPlatformType();
final thisSysIcon = platformIcons[thisPlatform];

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
