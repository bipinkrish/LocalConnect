import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localconnect/chat.dart';
import 'package:localconnect/data.dart';
import 'package:localconnect/setting.dart';
import 'package:localconnect/network.dart';
import 'package:network_discovery/network_discovery.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:window_size/window_size.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:file_picker/file_picker.dart';

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
  Set<String> enteredIPs = {};

  HttpServer? httpServer;
  int port = 4321;
  String localIP = "";
  String localName = "";
  int _currentIndex = 0;

  Timer? discoveryTimer;
  Timer? removalTimer;

  @override
  void dispose() {
    httpServer?.close();
    if (isMobile) {
      FilePicker.platform.clearTemporaryFiles();
    }
    super.dispose();
  }

  @override
  void initState() {
    if (isMobile) {
      FilePicker.platform.clearTemporaryFiles();
    }
    initiateLocalIP();
    initiateLocalName();
    super.initState();
    FlutterNativeSplash.remove();
  }

  // initiate local ip
  void initiateLocalIP() async {
    discoveredNetwork = await getLocalIP();
    if (discoveredNetwork.isNotEmpty) {
      localIP = discoveredNetwork[0].addr;
      // ignore: use_build_context_synchronously
      startHttpServer(httpServer, localIP, port, getAcceptAns, cancelPopup);
      isAvailable = true;
      startDeviceDiscovery();
    }
    refresh();
  }

  // inititale local device name
  void initiateLocalName() async {
    localName = await getDeviceName();
    refresh();
  }

  // new device's metadata received
  void newDiscovery(String ipAddress, String name, int type) {
    discoveredDevices.add(DiscoveredDevice(ipAddress, name, type));
    showSnack("Discovered $name");
    refresh();
  }

  // asked request response
  void manageResponse(String resp) {
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
      asking = DiscoveredDevice("", "", 0);
    }
  }

  // pushing new chat screen
  void acceptCallback(DiscoveredDevice accpeer) async {
    isAvailable = false;
    final notifier = providerContainer.read(chatMessagesProvider.notifier);
    notifier.resetState();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ChatScreen(
            me: DiscoveredDevice(localIP, localName, thisPlatform),
            peer: accpeer,
            port: port,
          );
        },
      ),
    );
    if (!mounted) return;
    isAvailable = true;
  }

  // show snackbar
  void showSnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(snackbar(content, context));
  }

  // discover devices on network
  void startDeviceDiscovery() async {
    discoveryTimer = Timer.periodic(const Duration(seconds: 2), (Timer timer) {
      final stream = NetworkDiscovery.discover(
        localIP.split('.').take(3).join('.'),
        port,
      );

      stream.listen((NetworkAddress addr) async {
        if (addr.ip != localIP &&
            !discoveredDevices.any((element) => element.ip == addr.ip)) {
          debugPrint("Asking MetaData ${addr.ip}");
          final response = await askMetadataRequest(addr.ip, port);
          if (response.isNotEmpty) {
            newDiscovery(addr.ip, response[0], response[1]);
          }
        }
      });
    });

    removalTimer =
        Timer.periodic(const Duration(seconds: 5), (Timer tmr) async {
      for (DiscoveredDevice element in discoveredDevices) {
        if (!await isDeviceOn(element.ip, port)) {
          discoveredDevices.remove(element);
          enteredIPs.removeWhere((ele) => ele == element.ip);
          refresh();
          break;
        }
      }
    });
  }

  void discoverAddr(String ip) async {
    if (enteredIPs.any((element) => element == ip) ||
        discoveredDevices.any((element) => element.ip == ip)) {
      showSnack("$ip is already Discovered");
      return;
    }

    if (ip != localIP) {
      showSnack("Checking $ip");
      enteredIPs.add(ip);

      debugPrint("Asking MetaData $ip");
      final response = await askMetadataRequest(ip, port);
      if (response.isNotEmpty) {
        newDiscovery(ip, response[0], response[1]);
      }
    }
    showSnack("No device on $ip");
  }

  // device box
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
                    visible: deviceList.isEmpty && discoveredNetwork.isNotEmpty,
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
  Padding getYouBox() {
    return Padding(
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
        child: (localName.isNotEmpty && localIP.isNotEmpty)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(thisSysIcon),
                  getcol("Device", localName),
                  getcol("IP", localIP),
                  // getcol("Port", port.toString()),
                  Column(
                    children: [
                      const Text("Interface"),
                      discoveredNetwork.length == 1
                          ? Text(
                              discoveredNetwork[0].name,
                              style: const TextStyle(color: mainColor),
                            )
                          : DropdownButton(
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
                                if (value != null) {
                                  localIP = value;
                                  if (httpServer != null) {
                                    httpServer!.close();
                                  }
                                  startHttpServer(httpServer, localIP, port,
                                      getAcceptAns, cancelPopup);
                                  if (discoveryTimer != null) {
                                    discoveryTimer!.cancel();
                                  }
                                  if (removalTimer != null) {
                                    removalTimer!.cancel();
                                  }
                                  startDeviceDiscovery();
                                  refresh();
                                }
                              },
                            ),
                    ],
                  ),
                ],
              )
            : const Text(
                "No interfaces found\nRestart after connecting to a network",
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  // some one is asking
  void getAcceptAns(HttpResponse response, String device, int type) {
    if (!isAvailable) {
      response.add("BUSY".codeUnits);
      response.close();
      return;
    }

    isAvailable = false;
    final ip = response.connectionInfo?.remoteAddress.address;
    if (ip == null) {
      response.close();
      return;
    }
    asking = DiscoveredDevice(ip, device, type);

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
                getrow("Chat request from", device),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      style: getButtonStyle(),
                      child: const Text("Reject"),
                      onPressed: () {
                        response.add("REJECTED".codeUnits);
                        response.close();
                        Navigator.of(context).pop();
                        isAvailable = true;
                      },
                    ),
                    ElevatedButton(
                      autofocus: true,
                      style: getButtonStyle(),
                      child: const Text("Accept"),
                      onPressed: () {
                        response.add("ACCEPTED".codeUnits);
                        response.close();
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
                            style: getButtonStyle(),
                            child: const Text("Cancel"),
                            onPressed: () {
                              isRequesting = false;
                              isAvailable = true;
                              Navigator.of(context).pop();
                            },
                          ),
                          ElevatedButton(
                            autofocus: true,
                            style: getButtonStyle(),
                            child: const Text("Ask"),
                            onPressed: () async {
                              isRequesting = true;
                              isAvailable = false;
                              peer = receiver;
                              if (mounted) {
                                setState(() {});
                              }

                              final resp = await askAccept(
                                receiver.ip,
                                port,
                                localName,
                              );
                              if (resp != "") {
                                manageResponse(resp);
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
                            autofocus: true,
                            style: getButtonStyle(),
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
                height: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    style: getButtonStyle(),
                    child: const Text("Cancel"),
                    onPressed: () {
                      Navigator.of(context).pop();
                      isAvailable = true;
                    },
                  ),
                  ElevatedButton(
                    style: getButtonStyle(),
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

  ButtonStyle getButtonStyle() {
    return ButtonStyle(
      backgroundColor: MaterialStateProperty.all(mainColor),
      foregroundColor: MaterialStateProperty.all(
        Theme.of(context).brightness == Brightness.light
            ? Colors.black
            : Colors.white,
      ),
    );
  }

  void refresh() {
    if (mounted) {
      setState(() {});
    }
  }
}
