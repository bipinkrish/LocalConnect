import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:localconnect/data.dart';

// server
void startServerSocket(ServerSocket? serverSocket, String localIP, int port,
    BuildContext context, Function accCallback, Function cancelCallback) async {
  final chatMessagesNotifier =
      providerContainer.read(chatMessagesProvider.notifier);
  try {
    serverSocket = await ServerSocket.bind(localIP, port, shared: true);

    serverSocket.listen((Socket clientSocket) {
      clientSocket.listen((Uint8List data) async {
        final jsonData = utf8.decode(data);
        final dynamic parsedData = jsonDecode(jsonData);

        if (parsedData is Map<String, dynamic>) {
          final messageType = parsedData['messageType'];

          switch (messageType) {
            case 'GET_METADATA':
              final deviceName = await getDeviceName();
              final platformType = getPlatformType();
              final metadataResponse = {
                'deviceName': deviceName,
                'platformType': platformType,
              };
              final responseJson = jsonEncode(metadataResponse);
              clientSocket.add(Uint8List.fromList(utf8.encode(responseJson)));
              clientSocket.close();
              break;

            case 'ASK_ACCEPT':
              final device = parsedData['device'];
              final platformType = parsedData['platformType'];
              accCallback(clientSocket, device, platformType);
              break;

            case 'CANCEL':
              final ip = clientSocket.remoteAddress.address.toString();
              cancelCallback(ip);
              break;

            case 'MESSAGE':
              final message = parsedData['message'];
              final info = parsedData['info'];
              chatMessagesNotifier.addMessage(message, false, info: info);
              break;

            default:
              debugPrint("Unknow Data : $parsedData");
              break;
          }
        }
      });
    });
  } catch (e) {
    debugPrint(e.toString());
  }
}

// asking meta data
void askMetadataRequest(String ipAddress, int port, Function setstate) {
  Socket.connect(ipAddress, port).then((clientSocket) {
    final metadataRequest = {
      'messageType': 'GET_METADATA',
    };
    final requestJson = jsonEncode(metadataRequest);
    clientSocket.add(Uint8List.fromList(utf8.encode(requestJson)));

    clientSocket.listen((Uint8List data) {
      final jsonData = utf8.decode(data);
      final dynamic response = jsonDecode(jsonData);
      clientSocket.close();
      setstate(ipAddress, response['deviceName'], response['platformType']);
    }, onDone: () {}, onError: (error) {});
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}

// ask accept
void askAccept(String rec, int port, String device, Function setAccAns) {
  Socket.connect(rec, port).then((clientSocket) {
    final askRequest = {
      'messageType': 'ASK_ACCEPT',
      'device': device,
      'platformType': thisPlatform,
    };
    final requestJson = jsonEncode(askRequest);
    clientSocket.add(Uint8List.fromList(utf8.encode(requestJson)));

    clientSocket.listen((Uint8List data) {
      final response = String.fromCharCodes(data);
      clientSocket.close();
      setAccAns(response);
    }, onDone: () {}, onError: (error) {});
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}

// canceling request
void sendCancel(String ip, int port) {
  Socket.connect(ip, port).then((clientSocket) {
    final cancelRequest = {
      'messageType': 'CANCEL',
    };
    final requestJson = jsonEncode(cancelRequest);
    clientSocket.add(Uint8List.fromList(utf8.encode(requestJson)));
    clientSocket.close();
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}

// sending msg
void sendMessage(String party, int port, String msg, bool info) {
  Socket.connect(party, port).then((clientSocket) {
    final msgRequest = {
      'messageType': 'MESSAGE',
      'message': msg,
      'info': info,
    };
    final requestJson = jsonEncode(msgRequest);
    clientSocket.add(Uint8List.fromList(utf8.encode(requestJson)));
    clientSocket.close();
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}
