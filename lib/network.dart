import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:localconnect/data.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

// server
void startHttpServer(HttpServer? httpServer, String localIP, int port,
    Function accCallback, Function cancelCallback) async {
  final chatMessagesNotifier =
      providerContainer.read(chatMessagesProvider.notifier);

  try {
    httpServer = await HttpServer.bind(localIP, port, shared: true);
    debugPrint(
        'Serving at http://${httpServer.address.host}:${httpServer.port}');

    await for (final request in httpServer) {
      final Uri uri = request.uri;
      final List<String> segments = uri.pathSegments;
      final String messageType = segments.isNotEmpty ? segments.first : '';
      final parsedData = uri.queryParameters;

      if (request.method == 'GET') {
        switch (messageType) {
          case "":
            request.response.add("LocalConnect $version".codeUnits);
            await request.response.close();
            break;

          case 'GET_METADATA':
            final deviceName = await getDeviceName();
            final platformType = getPlatformType();
            final metadataResponse = {
              'deviceName': deviceName,
              'platformType': platformType,
            };
            final responseJson = jsonEncode(metadataResponse);
            request.response.add(responseJson.codeUnits);
            await request.response.close();
            break;

          case 'ASK_ACCEPT':
            final device = parsedData['device'];
            final platformType =
                int.tryParse(parsedData['platformType'] ?? "0") ?? 0;
            accCallback(request.response, device, platformType);
            break;

          case 'CANCEL':
            final ip = request.connectionInfo?.remoteAddress.address;
            if (ip != null) {
              cancelCallback(ip);
            }
            await request.response.close();
            break;

          default:
            request.response.add("LocalConnect $version".codeUnits);
            await request.response.close();
            break;
        }
      } else if (request.method == 'POST' &&
          chatMessagesNotifier.ip ==
              request.connectionInfo?.remoteAddress.address) {
        switch (messageType) {
          case 'MESSAGE':
            final type = parsedData['type'];
            final info = parsedData['info'];

            if (type == "TEXT") {
              final data = await utf8.decodeStream(request);
              chatMessagesNotifier.addMessage(data, false, type ?? "TEXT",
                  info: info == "true");
            } else {
              final name = parsedData["name"];
              final List<int> payload = await request
                  .fold<List<int>>(<int>[], (a, b) => a..addAll(b));

              if (name != null && type != null) {
                chatMessagesNotifier.addFile(payload, false, type, name);
              }
            }
          default:
            await request.response.close();
            break;
        }
      } else {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
      }
    }
  } catch (e) {
    debugPrint(e.toString());
  }
}

// asking meta data
Future<List> askMetadataRequest(String ipAddress, int port) async {
  try {
    final response =
        await http.get(Uri.parse("http://$ipAddress:$port/GET_METADATA/"));

    if (response.statusCode == 200) {
      final dynamic jsondata = jsonDecode(response.body);
      return [jsondata['deviceName'], jsondata['platformType']];
    }
    return [];
  } catch (e) {
    return [];
  }
}

// is on
Future<bool> isDeviceOn(String ipAddress, int port) async {
  try {
    await http.get(Uri.parse("http://$ipAddress:$port/"));
    return true;
  } catch (e) {
    return false;
  }
}

// ask accept
Future<String> askAccept(String ipAddress, int port, String device) async {
  final response = await http.get(Uri.parse(
      "http://$ipAddress:$port/ASK_ACCEPT/?device=$device&platformType=$thisPlatform"));

  if (response.statusCode == 200) {
    return response.body;
  }
  return "";
}

// canceling request
void sendCancel(String ipAddress, int port) {
  http.get(Uri.parse("http://$ipAddress:$port/CANCEL/"));
}

// sending msg
void sendText(String ipAddress, int port, String msg, bool info) {
  http.post(Uri.parse("http://$ipAddress:$port/MESSAGE/?type=TEXT&info=$info"),
      body: utf8.encode(msg));
}

// sending file
void sendFile(
    String ipAddress, int port, XFile file, String type, bool info) async {
  http.post(
      Uri.parse(
          "http://$ipAddress:$port/MESSAGE/?name=${file.name}&type=$type&info=$info"),
      body: await file.readAsBytes());

  if (isMobile) {
    FilePicker.platform.clearTemporaryFiles();
  }

  // final request = http.MultipartRequest('POST', Uri.parse(""))
  //   ..files.add(await http.MultipartFile.fromPath('file', file.path));
}
