import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DiscoveredDevice {
  final String ip;
  final String deviceName;

  DiscoveredDevice(this.ip, this.deviceName);
}

Future<String> getLocalIP() async {
  List<NetworkInterface> interfaces =
      await NetworkInterface.list(type: InternetAddressType.IPv4);

  return interfaces[0].addresses[0].address;
}

Future<String> getDeviceName() async {
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