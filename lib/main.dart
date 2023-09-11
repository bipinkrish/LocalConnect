import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:localconnect/chat.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/setting.dart';
import 'package:localconnect/socket.dart';
import 'package:network_discovery/network_discovery.dart';
import 'package:window_size/window_size.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isWindows) {
    setWindowTitle("Local Connect");
  }
  runApp(
    ProviderScope(
      parent: providerContainer,
      child: MaterialApp(
        title: "Local Connect",
        home: const HomePage(),
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.from(
          colorScheme: const ColorScheme.dark(
            primary: Colors.deepOrangeAccent,
            onPrimary: Colors.white,
          ),
        ),
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
  Set<DiscoveredDevice> discoveredDevices = {};
  List<DiscoveredNetwork> discoveredNetwork = [];

  ServerSocket? serverSocket;
  int port = 4321;
  String localIP = "";
  String localName = "";

  @override
  void dispose() {
    serverSocket?.close();
    super.dispose();
  }

  @override
  void initState() {
    getLocalIP().then(
      (value) {
        discoveredNetwork = value;
        if (discoveredNetwork.isNotEmpty) {
          localIP = discoveredNetwork[0].addr;
          startServerSocket(
              serverSocket, localIP, port, context, getAcceptAns);
          startDeviceDiscovery();
        }
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

  // new device's metadata received
  void setDisState(String ipAddress, String response) {
    setState(() {
      discoveredDevices.add(DiscoveredDevice(ipAddress, response));
    });
  }

  // asked request response
  void setAccAns(String resp) {
    if (isRequesting) {
      setState(() {
        isAccepted = (resp == "ACCEPTED");
        isRequesting = false;
      });
      Navigator.of(context).pop();
      if (isAccepted) {
        acceptCallback(peer);
      } else {
        showSnack("${peer.deviceName} Rejected");
      }
    }
  }

  // pushing new chat screen
  void acceptCallback(DiscoveredDevice accpeer) {
    serverSocket?.close();
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

  // show snackbar
  void showSnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 800),
        // showCloseIcon: true,
        // closeIconColor: Colors.white,
        backgroundColor: Colors.deepOrangeAccent,
        content: Center(
          child: Text(
            content,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  // discover devices on network
  void startDeviceDiscovery({bool tapped = false}) async {
    discoveredDevices = {};
    if (localIP.isNotEmpty) {
      if (tapped) {
        serverSocket?.close();
        await startServerSocket(
            serverSocket, localIP, port, context, getAcceptAns);
      }
      final stream = NetworkDiscovery.discover(
          localIP.substring(0, localIP.lastIndexOf('.')), port);

      stream.listen((NetworkAddress addr) {
        if (addr.ip != localIP) {
          askMetadataRequest(addr.ip, port, setDisState);
        }
      });
      if (tapped) {
        showSnack("Re Discovered Devices");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceList = discoveredDevices.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Local Connect"),
        actions: [
          IconButton(
            onPressed: () {
              startDeviceDiscovery(tapped: true);
            },
            icon: const Icon(
              Icons.refresh_outlined,
              semanticLabel: "Re Discover",
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return const Settings();
                  },
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(
            height: 10,
          ),

          // you box
          Visibility(
            visible: (localName.isNotEmpty && localIP.isNotEmpty),
            child: Column(
              children: [
                //first line
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(localName,
                        style: const TextStyle(color: Colors.deepOrangeAccent)),
                    const Text(" is available at "),
                    Text(localIP,
                        style: const TextStyle(color: Colors.deepOrangeAccent)),
                  ],
                ),

                // second line
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "with interface ",
                    ),
                    DropdownButton(
                      style: const TextStyle(color: Colors.deepOrangeAccent),
                      value: localIP,
                      items: [
                        for (DiscoveredNetwork network in discoveredNetwork)
                          DropdownMenuItem(
                              value: network.addr,
                              child: Text(
                                network.name,
                                style: TextStyle(
                                    color: localIP == network.addr
                                        ? Colors.deepOrangeAccent
                                        : Colors.white),
                              ))
                      ],
                      onChanged: (value) {
                        localIP = value!;
                        startDeviceDiscovery(tapped: true);
                        setState(() {});
                      },
                    ),
                    Text(" on port $port"),
                  ],
                ),
              ],
            ),
          ),

          // Display discovered devices
          Expanded(
            child: ListView.builder(
              itemCount: deviceList.length,
              itemBuilder: (context, index) {
                final device = deviceList[index];
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

  // some one is asking
  void getAcceptAns(
    Socket client,
    String device,
  ) {
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
                acceptCallback(
                  DiscoveredDevice(ip, device),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // show chat request popup
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
