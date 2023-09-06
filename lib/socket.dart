import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:localconnect/data.dart';

void getAcceptAns(Socket client, BuildContext context, String device,
    ServerSocket? serverSocket, Function accCallback) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Chat Request"),
        content: Text("$device is requesting to chat with you"),
        actions: [
          TextButton(
            child: const Text("Reject"),
            onPressed: () {
              client.write("REJECTED");
              client.close();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text("Accept"),
            onPressed: () {
              client.write("ACCEPTED");
              String ip = client.remoteAddress.address.toString();
              client.close();
              Navigator.of(context).pop();
              accCallback(
                DiscoveredDevice(ip, device),
              );
            },
          ),
        ],
      );
    },
  );
}

void startServerSocket(ServerSocket? serverSocket, String localIP, int port,
    BuildContext context, Function accCallback) async {
  serverSocket = await ServerSocket.bind(localIP, port);
  final deviceName = await getDeviceName();

  serverSocket.listen((Socket clientSocket) {
    clientSocket.listen((Uint8List data) async {
      final parts = String.fromCharCodes(data).split("|");

      if (parts[0] == 'GET_METADATA') {
        clientSocket.write(deviceName);
        clientSocket.close();
      }
      if (parts[0] == 'ASK_ACCEPT') {
        getAcceptAns(
            clientSocket, context, parts[1], serverSocket, accCallback);
      }
    });
  });
}

void askMetadataRequest(String ipAddress, int port, Function setstate) {
  Socket.connect(ipAddress, port).then((clientSocket) {
    const metadataRequest = 'GET_METADATA';
    clientSocket.add(Uint8List.fromList(metadataRequest.codeUnits));

    clientSocket.listen((Uint8List data) {
      final response = String.fromCharCodes(data);
      clientSocket.close();
      setstate(ipAddress, response);
    }, onDone: () {}, onError: (error) {});
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}

void askAccept(String rec, int port, String device, Function setAccAns) {
  Socket.connect(rec, port).then((clientSocket) {
    String askRequest = 'ASK_ACCEPT|$device';
    clientSocket.add(Uint8List.fromList(askRequest.codeUnits));

    clientSocket.listen((Uint8List data) {
      final response = String.fromCharCodes(data);
      clientSocket.close();
      setAccAns(response);
    }, onDone: () {}, onError: (error) {});
  }).catchError((error) {
    debugPrint('Connection error: $error');
  });
}
