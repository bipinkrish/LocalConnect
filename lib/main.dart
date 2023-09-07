import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/chat.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/providers.dart';
import 'package:localconnect/socket.dart';
import 'package:network_discovery/network_discovery.dart';

void main() {
  runApp(
    ProviderScope(
      parent: providerContainer,
      child: MaterialApp(
        home: const HomePage(),
        themeMode: ThemeMode.system,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
      ),
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isAccepted = false;
  bool isRequesting = false;
  late DiscoveredDevice peer;

  Timer? discoveryTimer;

  List<DiscoveredDevice> discoveredDevices = [];
  ServerSocket? serverSocket;
  int port = 4321;
  String localIP = "0.0.0.0";
  String localName = "Device";

  @override
  void dispose() {
    serverSocket?.close();
    discoveryTimer!.cancel();
    super.dispose();
  }

  @override
  void initState() {
    getLocalIP().then(
      (value) {
        localIP = value;
        startServerSocket(serverSocket, localIP, port, context, acceptCallback);
        startDeviceDiscovery();
        setState(() {});
      },
    );
    getDeviceName().then((value) {
      setState(() {
        localName = value;
      });
    });
    super.initState();
  }

  void setDisState(String ipAddress, String response) {
    setState(() {
      discoveredDevices.add(DiscoveredDevice(ipAddress, response));
    });
  }

  void setAccAns(String resp) {
    if (isRequesting) {
      setState(() {
        isAccepted = (resp == "ACCEPTED");
        isRequesting = false;
      });
      Navigator.of(context).pop();
      if (isAccepted) {
        serverSocket?.close();
        discoveryTimer!.cancel();
        final notifier = providerContainer.read(chatMessagesProvider.notifier);
        notifier.resetState();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return ChatScreen(
                peer: peer,
                port: port,
              );
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text("Rejected")),
          ),
        );
      }
    }
  }

  void acceptCallback(DiscoveredDevice accpeer) {
    serverSocket?.close();
    discoveryTimer!.cancel();
    final notifier = providerContainer.read(chatMessagesProvider.notifier);
    notifier.resetState();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ChatScreen(
            peer: accpeer,
            port: port,
          );
        },
      ),
    );
  }

  void startDeviceDiscovery() async {
    if (localIP.isNotEmpty) {
      String temp = localIP.substring(0, localIP.lastIndexOf('.'));
      discoveryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        final stream = NetworkDiscovery.discover(temp, port);
        stream.listen((NetworkAddress addr) {
          if (!discoveredDevices.any((device) => device.ip == addr.ip) &&
              addr.ip != localIP) {
            askMetadataRequest(addr.ip, port, setDisState);
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Visibility(
            visible: localIP.isNotEmpty,
            child: Padding(
              padding: const EdgeInsets.only(top: 50, bottom: 10),
              child: Text(
                "$localName Serving on $localIP:$port",
                style: const TextStyle(color: Colors.green),
              ),
            ),
          ),

          // Display discovered devices
          Expanded(
            child: ListView.builder(
              itemCount: discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = discoveredDevices[index];
                return ListTile(
                  title: Text(device.deviceName),
                  subtitle: Text(device.ip),
                  trailing: ElevatedButton(
                    onPressed: () {
                      showChatRequestPopup(device);
                    },
                    child: const Text("Connect"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void showChatRequestPopup(
    DiscoveredDevice receiver,
  ) {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Chat Request"),
            content: !isRequesting
                ? Text(
                    "Do you want to start a chat with ${receiver.deviceName}?")
                : Text("Waiting for ${receiver.deviceName} to accept"),
            actions: !isRequesting
                ? [
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () {
                        setState(() {
                          isRequesting = false;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                    TextButton(
                      child: const Text("Ask"),
                      onPressed: () {
                        setState(() {
                          isRequesting = true;
                          peer = receiver;
                        });
                        Navigator.of(context).pop();
                        showChatRequestPopup(receiver);
                        askAccept(receiver.ip, port, localName, setAccAns);
                      },
                    ),
                  ]
                : [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () {
                        setState(() {
                          isRequesting = false;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
          );
        });
  }
}
