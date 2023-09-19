import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localconnect/chat.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/setting.dart';
import 'package:localconnect/socket.dart';
import 'package:network_discovery/network_discovery.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:window_size/window_size.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  if (Platform.isWindows || Platform.isLinux || Platform.isWindows) {
    setWindowTitle("LocalConnect");
  }
  runApp(
    AdaptiveTheme(
      light: lighttheme,
      dark: darktheme,
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => MaterialApp(
        title: "LocalConnect",
        theme: theme,
        darkTheme: darkTheme,
        home: const HomePage(),
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
  DiscoveredDevice asking = DiscoveredDevice("", "", 0);
  Set<DiscoveredDevice> discoveredDevices = {};
  List<DiscoveredNetwork> discoveredNetwork = [];

  ServerSocket? serverSocket;
  int port = 4321;
  String localIP = "";
  String localName = "";
  int _currentIndex = 0;

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
    FlutterNativeSplash.remove();
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
        refresh();
      },
    );
  }

  // inititale local device name
  void initiateLocalName() {
    getDeviceName().then((value) {
      if (localName != value) {
        localName = value;
        refresh();
      }
    });
  }

  // new device's metadata received
  void setDisState(String ipAddress, String name, int type) {
    discoveredDevices.add(DiscoveredDevice(ipAddress, name, type));
    showSnack("Discovered $name");
    refresh();
  }

  // asked request response
  void setAccAns(String resp) {
    if (isRequesting) {
      isAccepted = (resp == "ACCEPTED");
      isRequesting = false;

      Navigator.of(context).pop();
      if (isAccepted) {
        acceptCallback(peer);
      } else {
        isAvailable = true;
        if (resp == "BUSY") {
          showSnack("${peer.deviceName} is Busy");
        } else {
          // REJECTED
          showSnack("${peer.deviceName} Rejected");
        }
      }
    }
  }

  // req canceled
  void cancelPopup(String ip) {
    if (ip == asking.ip) {
      Navigator.of(context).pop();
      showSnack("${asking.deviceName} Canceled Request");

      isAvailable = true;
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
            me: DiscoveredDevice(localIP, localName, getPlatformType()),
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
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content, context));
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

      final stream = NetworkDiscovery.discover(
        localIP.split('.').take(3).join('.'),
        port,
      );

      stream.listen((NetworkAddress addr) {
        if (addr.ip != localIP) {
          askMetadataRequest(addr.ip, port, setDisState);
        }
      });
      if (tapped) {
        showSnack("Re-Freshed Configarations");
      }
    }
    refresh();
  }

  void discoverAddr(String ip) async {
    showSnack("Checking $ip");
    final stream = await NetworkDiscovery.discoverFromAddress(ip, port);
    if (stream.ip != localIP) {
      askMetadataRequest(stream.ip, port, setDisState);
    }
  }

  Container getListBox(DiscoveredDevice device, {bool plus = false}) {
    const int pad = 16;

    return Container(
      height: 100,
      width: (MediaQuery.of(context).size.width / 2) - (pad * 2),
      margin: EdgeInsets.all(pad.toDouble()),
      decoration: BoxDecoration(
        color: plus
            ? Theme.of(context).brightness == Brightness.light
                ? Colors.brown.shade50
                : Colors.black54
            : mainColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          if (plus) {
            showIpAddressDialog();
          } else {
            showChatRequestPopup(device);
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: plus
              ? const [
                  Icon(
                    Icons.add,
                    color: mainColor,
                  )
                ]
              : [
                  Icon(platformIcons[device.type]),
                  Text(
                    device.deviceName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    device.ip,
                  ),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceList = discoveredDevices.toList();

    return Scaffold(
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                startDeviceDiscovery(tapped: true);
              },
              child: const Icon(
                Icons.refresh_outlined,
              ),
            )
          : null,
      bottomNavigationBar: SalomonBottomBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 0 && _currentIndex == 1) {
            isAvailable = true;
            initiateLocalName();
          }
          if (i == 1 && _currentIndex == 0) {
            isAvailable = false;
          }

          _currentIndex = i;
          refresh();
        },
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.home),
            title: const Text("Home"),
            selectedColor: mainColor,
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.settings_outlined),
            title: const Text("Settings"),
            selectedColor: mainColor,
          ),
        ],
      ),
      body: _currentIndex == 1
          ? Settings(
              initialDeviceName: localName,
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // actions
                  const SizedBox(
                    height: 60,
                  ),

                  // you box
                  getYouBox(),

                  // discovered
                  if (deviceList.isNotEmpty)
                    for (int i = 0; i < deviceList.length; i = i + 2)
                      Row(
                        children: [
                          if (i < deviceList.length) getListBox(deviceList[i]),
                          if (i + 1 < deviceList.length)
                            getListBox(deviceList[i + 1])
                          else
                            getListBox(asking, plus: true)
                        ],
                      ),
                  if (deviceList.length % 2 == 0)
                    Row(
                      children: [
                        getListBox(asking, plus: true),
                      ],
                    ),

                  // help msg
                  Visibility(
                    visible: deviceList.isEmpty,
                    child: const Padding(
                      padding: EdgeInsets.all(50),
                      child: Text(
                        "No devices found, both parties should be on the same network\nMake sure the IP addresses should match upto 2 dots",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // you box
  Visibility getYouBox() {
    return Visibility(
      visible: (localName.isNotEmpty && localIP.isNotEmpty),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          padding: const EdgeInsets.all(15),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.brown.shade50
                : Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Flexible(
                flex: 1,
                child: Center(
                  child: Icon(thisSysIcon),
                ),
              ),
              Flexible(
                flex: 9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        getrow("Device", localName),
                        getrow("IP", localIP),
                      ],
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        getrow("Port", port.toString()),
                        Row(
                          children: [
                            const Text("Interface "),
                            DropdownButton(
                              style: const TextStyle(color: mainColor),
                              value: localIP,
                              borderRadius: BorderRadius.circular(8),
                              items: [
                                for (DiscoveredNetwork network
                                    in discoveredNetwork)
                                  DropdownMenuItem(
                                    value: network.addr,
                                    child: Text(
                                      network.name,
                                      style: TextStyle(
                                        color: localIP == network.addr
                                            ? mainColor
                                            : Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? Colors.black
                                                : Colors.white,
                                      ),
                                    ),
                                  )
                              ],
                              onChanged: (value) {
                                localIP = value!;
                                startDeviceDiscovery(tapped: true);
                                refresh();
                              },
                            ),
                          ],
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // some one is asking
  void getAcceptAns(Socket client, String device, int type) {
    if (!isAvailable) {
      client.write("BUSY");
      client.close();
      return;
    }

    isAvailable = false;
    asking =
        DiscoveredDevice(client.remoteAddress.address.toString(), device, type);

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
                        isAvailable = true;
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
    isAvailable = false;

    showModalBottomSheet(
      isDismissible: false,
      context: context,
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Container(
            padding: const EdgeInsets.all(10),
            height: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: !isRequesting
                  ? [
                      getrow("Do you want to start a chat with",
                          receiver.deviceName),
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            child: const Text("Cancel"),
                            onPressed: () {
                              isRequesting = false;
                              isAvailable = true;
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            child: const Text("Ask"),
                            onPressed: () {
                              isRequesting = true;
                              isAvailable = false;
                              peer = receiver;
                              askAccept(
                                  receiver.ip, port, localName, setAccAns);
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      )
                    ]
                  : [
                      getrow(
                          "Waiting for acceptance from", receiver.deviceName),
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
                              isRequesting = false;
                              isAvailable = true;
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
        });
      },
    );
  }

  // Function to show the IP address entry dialog
  void showIpAddressDialog() {
    isAvailable = false;
    List<String> ipAddress = localIP.split('.');
    final TextEditingController ip3 = TextEditingController();
    final TextEditingController ip4 = TextEditingController();
    const textstyle = TextStyle(fontSize: 30, color: Colors.grey);
    final typestyle = TextStyle(
      fontSize: 30,
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.black
          : Colors.white,
    );
    final FocusNode ip3Focus = FocusNode();
    final FocusNode ip4Focus = FocusNode();

    void changeFocusIfNeeded(String value, {bool entered = false}) {
      if (value.length == 3 || entered) {
        ip3Focus.unfocus();
        ip4Focus.requestFocus();
      }
    }

    void clickediscover() {
      Navigator.of(context).pop();
      isAvailable = true;
      String enteredIpAddress =
          "${ipAddress[0]}.${ipAddress[1]}.${ip3.text}.${ip4.text}";
      if (isValidIPAddress(enteredIpAddress)) {
        discoverAddr(enteredIpAddress);
      } else {
        showSnack("Not a Valid IP Address");
      }
    }

    showModalBottomSheet(
      isDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(ipAddress[0], style: textstyle),
                  const Text(" . ", style: textstyle),
                  Text(ipAddress[1], style: textstyle),
                  const Text(" . ", style: textstyle),
                  Expanded(
                    child: TextField(
                      textAlign: TextAlign.center,
                      controller: ip3,
                      style: typestyle,
                      minLines: 1,
                      focusNode: ip3Focus,
                      autofocus: ip3.text.isEmpty,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(3),
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (value) {
                        changeFocusIfNeeded(value);
                      },
                      onSubmitted: (value) =>
                          changeFocusIfNeeded(value, entered: true),
                    ),
                  ),
                  const Text(" . ", style: textstyle),
                  Expanded(
                    child: TextField(
                      textAlign: TextAlign.center,
                      controller: ip4,
                      style: typestyle,
                      minLines: 1,
                      focusNode: ip4Focus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(3),
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onSubmitted: (value) => clickediscover(),
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    child: const Text("Cancel"),
                    onPressed: () {
                      Navigator.of(context).pop();
                      isAvailable = true;
                    },
                  ),
                  ElevatedButton(
                    child: const Text("Discover"),
                    onPressed: () => clickediscover(),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
