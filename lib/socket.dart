import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:localconnect/data.dart';

const String seperator = "--|-|--";

// server
Future<bool> startServerSocket(
    ServerSocket? serverSocket,
    String localIP,
    int port,
    BuildContext context,
    Function accCallback,
    Function cancelCallback) async {
  final chatMessagesNotifier =
      providerContainer.read(chatMessagesProvider.notifier);
  serverSocket = await ServerSocket.bind(localIP, port, shared: true);

  serverSocket.listen((Socket clientSocket) {
    clientSocket.listen((Uint8List data) async {
      final parts = utf8.decode(data).split(seperator);

      if (parts[0] == 'GET_METADATA') {
        final deviceName = await getDeviceName();
        clientSocket.write("$deviceName$seperator${thisPlatform}");
        clientSocket.close();
      }

      if (parts[0] == 'ASK_ACCEPT') {
        final int pltType = int.tryParse(parts[2]) ?? 0;
        accCallback(clientSocket, parts[1], pltType);
      }

      if (parts[0] == 'CANCEL') {
        cancelCallback(
          clientSocket.remoteAddress.address.toString(),
        );
      }

      if (parts[0] == 'MESSAGE') {
        final message = parts[1];
        chatMessagesNotifier.addMessage(message, false, info: parts[2] == "1");
      }
    });
  });
  return true;
}

// asking meta data
void askMetadataRequest(String ipAddress, int port, Function setstate) {
  Socket.connect(ipAddress, port).then((clientSocket) {
    const metadataRequest = 'GET_METADATA';
    clientSocket.add(Uint8List.fromList(utf8.encode(metadataRequest)));

    clientSocket.listen((Uint8List data) {
      final response = String.fromCharCodes(data).split(seperator);
      clientSocket.close();
      setstate(ipAddress, response[0], int.parse(response[1]));
    }, onDone: () {}, onError: (error) {});
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}

// ask accept
void askAccept(String rec, int port, String device, Function setAccAns) {
  Socket.connect(rec, port).then((clientSocket) {
    String askRequest =
        'ASK_ACCEPT$seperator$device$seperator${thisPlatform}';
    clientSocket.add(Uint8List.fromList(utf8.encode(askRequest)));

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
    String canRequest = 'CANCEL';
    clientSocket.add(Uint8List.fromList(utf8.encode(canRequest)));
    clientSocket.close();
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}

// sending msg
void sendMessage(String party, int port, String msg, String info) {
  Socket.connect(party, port).then((clientSocket) {
    String msgRequest = 'MESSAGE$seperator$msg$seperator$info';
    clientSocket.add(Uint8List.fromList(utf8.encode(msgRequest)));
    clientSocket.close();
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}
