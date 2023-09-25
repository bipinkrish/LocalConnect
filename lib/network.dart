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
      final String? messageType = uri.queryParameters['messageType'];
      final parsedData = uri.queryParameters;

      if (request.method == 'GET') {
        switch (messageType) {
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
            break;

          default:
            debugPrint("Unknow Data");
            break;
        }
      } else if (request.method == 'POST') {
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
void askMetadataRequest(String ipAddress, int port, Function setstate) async {
  const String metadataReq = "GET_METADATA";
  final response = await http
      .get(Uri.parse("http://$ipAddress:$port?messageType=$metadataReq"));

  if (response.statusCode == 200) {
    final dynamic jsondata = jsonDecode(response.body);
    setstate(ipAddress, jsondata['deviceName'], jsondata['platformType']);
  }
}

// ask accept
void askAccept(
    String ipAddress, int port, String device, Function setAccAns) async {
  const String askAcceptReq = "ASK_ACCEPT";
  final response = await http.get(Uri.parse(
      "http://$ipAddress:$port?messageType=$askAcceptReq&device=$device&platformType=$thisPlatform"));

  if (response.statusCode == 200) {
    setAccAns(response.body);
  }
}

// canceling request
void sendCancel(String ipAddress, int port) {
  const String cancelReq = "CANCEL";
  http.get(Uri.parse("http://$ipAddress:$port?messageType=$cancelReq"));
}

// sending msg
void sendText(String ipAddress, int port, String msg, bool info) {
  const String messagePost = "MESSAGE";
  const type = "TEXT";
  http.post(
      Uri.parse(
          "http://$ipAddress:$port?messageType=$messagePost&type=$type&info=$info"),
      body: utf8.encode(msg));
}

// sending file
void sendFile(
    String ipAddress, int port, XFile file, String type, bool info) async {
  const String messagePost = "MESSAGE";
  final name = file.name;

  http.post(
      Uri.parse(
          "http://$ipAddress:$port?messageType=$messagePost&name=$name&type=$type&info=$info"),
      body: await file.readAsBytes());

  if (isMobile) {
    FilePicker.platform.clearTemporaryFiles();
  }

  // final request = http.MultipartRequest('POST', Uri.parse(""))
  //   ..files.add(await http.MultipartFile.fromPath('file', file.path));
}
