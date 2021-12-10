import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:nearby_connections/nearby_connections.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          ThemeData(primaryColor: Colors.deepPurple, accentColor: Colors.black),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Keep In Touch'),
          centerTitle: true,
        ),
        body: Body(),
      ),
    );
  }
}

class Body extends StatefulWidget {
  @override
  _MyBodyState createState() => _MyBodyState();
}

class _MyBodyState extends State<Body> {
  List<String> msg = [];
  final String userName = Random().nextInt(10000).toString();
  final Strategy strategy = Strategy.P2P_CLUSTER;
  final myController = TextEditingController();
  final options = ['SOS', 'Health Centre', 'Resource Centre', 'Reply'];
  String _option = 'SOS';
  List<String> cId = []; //currently connected device ID
  late File tempFile; //reference to the file currently being transferred
  Map<int, String> map =
      Map(); //store filename mapped to corresponding payloadId

  @override
  void initState() {
    super.initState();
    checkloc();
  }

  @override
  Widget build(BuildContext context) {
    TextStyle? textStyle = Theme.of(context).textTheme.headline6;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: <Widget>[
            Wrap(
              children: <Widget>[
                DropdownButton(
                  items: options.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  value: _option,
                  onChanged: (String? value) {
                    setState(() {
                      this._option = value!;
                    });
                  },
                ),
                TextField(
                    controller: myController,
                    decoration: InputDecoration(
                        hintText: 'e.g. abcd',
                        labelText: 'Message',
                        labelStyle: textStyle,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5.0)))),
              ],
            ),
            Divider(),
            Text("User Name: " + userName),
            Wrap(
              children: <Widget>[
                ElevatedButton(
                  child: Text("Start Advertising"),
                  onPressed: () async {
                    try {
                      bool a = await Nearby().startAdvertising(
                        userName,
                        strategy,
                        onConnectionInitiated: onConnectionInit,
                        onConnectionResult: (id, status) {
                          showSnackbar(status);
                        },
                        onDisconnected: (id) {
                          showSnackbar("Disconnected: " + id);
                        },
                      );
                      showSnackbar("ADVERTISING: " + a.toString());
                    } catch (exception) {
                      showSnackbar(exception);
                    }
                  },
                ),
                Container(width: 5.0 * 5),
                ElevatedButton(
                  child: Text("Stop Advertising"),
                  onPressed: () async {
                    await Nearby().stopAdvertising();
                  },
                ),
              ],
            ),
            Wrap(
              children: <Widget>[
                ElevatedButton(
                  child: Text("Start Discovery   "),
                  onPressed: () async {
                    try {
                      bool a = await Nearby().startDiscovery(
                        userName,
                        strategy,
                        onEndpointFound: (id, name, serviceId) {
                          // show sheet automatically to request connection
                          showModalBottomSheet(
                            context: context,
                            builder: (builder) {
                              return Center(
                                child: Column(
                                  children: <Widget>[
                                    Text("id: " + id),
                                    Text("Name: " + name),
                                    Text("ServiceId: " + serviceId),
                                    ElevatedButton(
                                      child: Text("Request Connection"),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Nearby().requestConnection(
                                          userName,
                                          id,
                                          onConnectionInitiated: (id, info) {
                                            onConnectionInit(id, info);
                                          },
                                          onConnectionResult: (id, status) {
                                            showSnackbar(status);
                                          },
                                          onDisconnected: (id) {
                                            showSnackbar(id);
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        onEndpointLost: (id) {
                          showSnackbar("Lost Endpoint:" + id!);
                        },
                      );
                      showSnackbar("DISCOVERING: " + a.toString());
                    } catch (e) {
                      showSnackbar(e);
                    }
                  },
                ),
                Container(width: 5.0 * 5),
                ElevatedButton(
                  child: Text("Stop Discovery   "),
                  onPressed: () async {
                    await Nearby().stopDiscovery();
                  },
                ),
              ],
            ),
            ElevatedButton(
              child: Text("Stop All Endpoints"),
              onPressed: () async {
                await Nearby().stopAllEndpoints();
              },
            ),
            Divider(),
            Text(
              "Sending Data",
            ),
            ElevatedButton(
                child: Text("Send Message"),
                onPressed: () async {
                  String a = myController.text;
                  if (_option == 'SOS')
                    a = 'SOS: ' + a;
                  else if (_option == 'Health Centre')
                    a = 'HC: ' + a;
                  else if (_option == 'Resource Centre')
                    a = 'RC: ' + a;
                  else
                    a = 'Reply: ' + a;
                  for (var i in cId) {
                    showSnackbar("Sending $a to $i");
                    Nearby()
                        .sendBytesPayload(i, Uint8List.fromList(a.codeUnits));
                  }
                }),
            // ElevatedButton(
            //   child: Text("Send File Payload"),
            //   onPressed: () async {
            //     File file =
            //         await ImagePicker.pickImage(source: ImageSource.gallery);

            //     if (file == null) return;
            //     for (var z in cId) {
            //       int payloadId = await Nearby().sendFilePayload(z, file.path);
            //       showSnackbar("Sending file to $z");
            //       Nearby().sendBytesPayload(
            //           z,
            //           Uint8List.fromList(
            //               "$payloadId:${file.path.split('/').last}".codeUnits));
            //     }
            //   },
            // ),
            Text(
              'Broadcasts\n',
              style: TextStyle(fontSize: 20),
            ),
            Column(
                children: msg
                    .map((f) => Row(children: <Widget>[
                          Container(
                            child: Text(
                              f,
                              textAlign: TextAlign.left,
                              style: TextStyle(fontSize: 20),
                            ),
                          )
                        ]))
                    .toList()),
          ],
        ),
      ),
    );
  }

  // ignore: non_constant_identifier_names
  void Go() {}
  Future<void> askLoc() async {
    // ignore: await_only_futures
    Nearby().askLocationPermission();
  }

  void checkloc() async {
    if (await Nearby().checkLocationPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permissions granted :)")));
    } else {
      askLoc();
    }
    checkext();
  }

  void askExt() async {
    // ignore: await_only_futures
    Nearby().askExternalStoragePermission();
  }

  void checkext() async {
    if (await Nearby().checkExternalStoragePermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("External Storage permissions granted :)")));
    } else {
      askExt();
    }
  }

  void showSnackbar(dynamic a) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(a.toString()),
    ));
  }

  /// Called upon Connection request (on both devices)
  /// Both need to accept connection to start sending/receiving
  void onConnectionInit(String? id, ConnectionInfo info) {
    showModalBottomSheet(
      context: context,
      builder: (builder) {
        return Center(
          child: Column(
            children: <Widget>[
              Text("id: " + id!),
              Text("Token: " + info.authenticationToken!),
              Text("Name" + info.endpointName!),
              Text("Incoming: " + info.isIncomingConnection.toString()),
              ElevatedButton(
                child: Text("Accept Connection"),
                onPressed: () {
                  Navigator.pop(context);
                  if (!cId.contains(id)) {
                    cId.add(id);
                  }

                  Nearby().acceptConnection(
                    id,
                    onPayLoadRecieved: (endid, payload) async {
                      if (payload.type == PayloadType.BYTES) {
                        String str = String.fromCharCodes(payload.bytes!);
                        showSnackbar(endid + ": " + str);
                        setState(() {
                          if (!msg.contains(str)) {
                            msg.add(str);
                            for (var i in cId) {
                              showSnackbar("Sending $str to $i");
                              Nearby().sendBytesPayload(
                                  i, Uint8List.fromList(str.codeUnits));
                            }
                          }
                        });

                        if (str.contains(':')) {
                          // used for file payload as file payload is mapped as
                          // payloadId:filename
                          int payloadId = int.parse(str.split(':')[0]);
                          String fileName = (str.split(':')[1]);

                          if (map.containsKey(payloadId)) {
                            if (await tempFile.exists()) {
                              tempFile.rename(
                                  tempFile.parent.path + "/" + fileName);
                            } else {
                              showSnackbar("File doesnt exist");
                            }
                          } else {
                            //add to map if not already
                            map[payloadId] = fileName;
                          }
                        }
                      } else if (payload.type == PayloadType.FILE) {
                        showSnackbar(endid + ": File transfer started");
                        tempFile = File(payload.filePath!);
                      }
                    },
                    onPayloadTransferUpdate: (endid, payloadTransferUpdate) {
                      if (payloadTransferUpdate.status ==
                          PayloadStatus.IN_PROGRESS) {
                        print(payloadTransferUpdate.bytesTransferred);
                      } else if (payloadTransferUpdate.status ==
                          PayloadStatus.FAILURE) {
                        print("failed");
                        showSnackbar(endid + ": FAILED to transfer file");
                      } else if (payloadTransferUpdate.status ==
                          PayloadStatus.SUCCESS) {
                        showSnackbar(
                            "success, total bytes = ${payloadTransferUpdate.totalBytes}");

                        if (map.containsKey(payloadTransferUpdate.id)) {
                          //rename the file now
                          String? name = map[payloadTransferUpdate.id];
                          tempFile.rename(tempFile.parent.path + "/" + name!);
                        } else {
                          //bytes not received till yet
                          map[payloadTransferUpdate.id!] = "";
                        }
                      }
                    },
                  );
                },
              ),
              ElevatedButton(
                child: Text("Reject Connection"),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await Nearby().rejectConnection(id);
                  } catch (e) {
                    showSnackbar(e);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
