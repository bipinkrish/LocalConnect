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
            primary: mainColor,
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
  bool isAvailable = true;

  late DiscoveredDevice peer;
  DiscoveredDevice asking = DiscoveredDevice("", "");
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
    initiateLocalIP();
    initiateLocalName();
    super.initState();
  }

  // initiate local ip
  void initiateLocalIP() {
    getLocalIP().then(
      (value) {
        discoveredNetwork = value;
        if (discoveredNetwork.isNotEmpty) {
          localIP = discoveredNetwork[0].addr;
          startServerSocket(
              serverSocket, localIP, port, context, getAcceptAns, cancelPopup);
          startDeviceDiscovery();
        }
        setState(() {});
      },
    );
  }

  // inititale local device name
  void initiateLocalName() {
    getDeviceName().then((value) {
      if (localName != value) {
        setState(() {
          localName = value;
        });
      }
    });
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
      } else if (resp == "BUSY") {
        showSnack("${peer.deviceName} is Busy");
      } else {
        // REJECTED
        showSnack("${peer.deviceName} Rejected");
      }
    }
  }

  // req canceled
  void cancelPopup(String ip) {
    if (ip == asking.ip) {
      Navigator.of(context).pop();
      showSnack("${asking.deviceName} Canceled Request");
      setState(() {
        isAvailable = true;
      });
    }
  }

  // pushing new chat screen
  void acceptCallback(DiscoveredDevice accpeer) async {
    serverSocket?.close();
    isAvailable = false;
    final notifier = providerContainer.read(chatMessagesProvider.notifier);
    notifier.resetState();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ChatScreen(
            peer: accpeer,
            port: port,
          );
        },
      ),
    );
    if (!mounted) return;
    startDeviceDiscovery();
  }

  // show snackbar
  void showSnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content));
  }

  // discover devices on network
  void startDeviceDiscovery({bool tapped = false}) async {
    discoveredDevices = {};
    isAvailable = true;
    if (localIP.isNotEmpty) {
      if (tapped) {
        serverSocket?.close();
        await startServerSocket(
            serverSocket, localIP, port, context, getAcceptAns, cancelPopup);
        initiateLocalName();
      }
      // int lastIndex = localIP.lastIndexOf('.');
      // int secondLastIndex = localIP.lastIndexOf('.', lastIndex - 1);
      final stream = NetworkDiscovery.discover(
          localIP.substring(0, localIP.lastIndexOf('.')), port);

      stream.listen((NetworkAddress addr) {
        if (addr.ip != localIP) {
          askMetadataRequest(addr.ip, port, setDisState);
        }
      });
      if (tapped) {
        showSnack("Re-Freshed Configarations");
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
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) {
                    return Settings(
                      initialDeviceName: localName,
                    );
                  },
                ),
              );
              if (!mounted) return;
              initiateLocalName();
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
                    Text(localName, style: const TextStyle(color: mainColor)),
                    const Text(" is available at "),
                    Text(localIP, style: const TextStyle(color: mainColor)),
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
                      style: const TextStyle(color: mainColor),
                      value: localIP,
                      items: [
                        for (DiscoveredNetwork network in discoveredNetwork)
                          DropdownMenuItem(
                              value: network.addr,
                              child: Text(
                                network.name,
                                style: TextStyle(
                                    color: localIP == network.addr
                                        ? mainColor
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

          const Divider(
            height: 5,
            thickness: 1,
            color: mainColor,
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
    if (!isAvailable) {
      client.write("BUSY");
      client.close();
      return;
    }
    setState(() {
      isAvailable = false;
      asking =
          DiscoveredDevice(client.remoteAddress.address.toString(), device);
    });
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(10),
          height: 150,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("$device is requesting to chat with you"),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      child: const Text("Reject"),
                      onPressed: () {
                        client.write("REJECTED");
                        client.close();
                        Navigator.of(context).pop();
                        setState(() {
                          isAvailable = true;
                        });
                      },
                    ),
                    ElevatedButton(
                      child: const Text("Accept"),
                      onPressed: () {
                        client.write("ACCEPTED");
                        client.close();

                        Navigator.of(context).pop();
                        acceptCallback(asking);
                      },
                    ),
                  ],
                )
              ]),
        );
      },
    );
  }

  // show chat request popup
  void showChatRequestPopup(
    DiscoveredDevice receiver,
  ) {
    setState(() {
      isAvailable = false;
    });
    showModalBottomSheet(
      isDismissible: false,
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(10),
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: !isRequesting
                ? [
                    Text(
                        "Do you want to start a chat with ${receiver.deviceName}?"),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          child: const Text("Cancel"),
                          onPressed: () {
                            setState(() {
                              isRequesting = false;
                              isAvailable = true;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                        ElevatedButton(
                          child: const Text("Ask"),
                          onPressed: () {
                            setState(() {
                              isRequesting = true;
                              isAvailable = false;
                              peer = receiver;
                            });
                            Navigator.of(context).pop();
                            showChatRequestPopup(receiver);
                            askAccept(receiver.ip, port, localName, setAccAns);
                          },
                        ),
                      ],
                    )
                  ]
                : [
                    Text("Waiting for ${receiver.deviceName} to accept"),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          child: const Text("Cancel"),
                          onPressed: () {
                            sendCancel(receiver.ip, port);
                            setState(() {
                              isRequesting = false;
                              isAvailable = true;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ],
                    ),
                  ],
          ),
        );
      },
    );
  }
}
