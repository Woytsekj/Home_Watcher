// Global Packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

// Local Classes
import 'control_state.dart';
import 'control_button.dart';
import 'menu_entry.dart';
import 'http_comms.dart';
import 'src/p2p_call.dart';

import 'mqtt_server_client.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  MqttComms mqttComms = MqttComms();
  @override
  void initState() {
    super.initState();
    mqttComms.setupClient();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ControlState(),
      child: MaterialApp(
        title: 'Namer App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        ),
        home: MyHomePage(mqttComms: mqttComms),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}


class MyHomePage extends StatelessWidget {
  
  const MyHomePage({
    super.key,
    required this.mqttComms,
  });

  final MqttComms mqttComms;

  List<MenuEntry> _getMenus(ControlState appState) {
    final List<MenuEntry> result = <MenuEntry>[
      MenuEntry(
        label: 'Menu',
        menuChildren: <MenuEntry>[
          MenuEntry(
            label: 'Test Server Connection',
            onPressed: () async {
              
              appState.setState("Testing Server Connection");
              mqttComms.disconnectFromServer();
              //response = await HttpComms.sendCommandProtected('TestConnectionServer');
              int response = await mqttComms.connectToServer();

              if (response == 0)
              {
                // Connection successful
                appState.setState("Server Connection Successful");
              }
              else
              {
                // Connection failure
                appState.setState("Server Connection Not Successful");
              }
            },
          ),
          MenuEntry(
            label: 'Test Robot Connection',
            onPressed: () async {
              http.Response response;  
              appState.setState("Testing Robot Connection");
              response = await HttpComms.sendCommandProtected('TestConnectionRobot');

              if (response.statusCode == 200)
              {
                // Connection successful
                appState.setState("Robot Connection Successful");
              }
              else
              {
                // Connection failure
                appState.setState("Robot Connection Not Successful");
              }
            },
          ),
        ],
      ),
    ];

    return result;
  }

  @override
  Widget build(BuildContext context) {
    ControlState appState = context.watch<ControlState>();
    String movementStatus = appState.current;

    return Scaffold(
      body: Stack(
        children: [
          CallSample(),
          //Image(image: AssetImage('pictures/DoggoPic.jpg')),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                MovementStatusDisplay(movementStatus: movementStatus),
              ],
            ),  
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: CameraControls(appState: appState, mqttComms: mqttComms),
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: MovementControls(appState: appState, mqttComms: mqttComms),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: SafeArea
            (
              child: MenuBar(children: MenuEntry.build(_getMenus(appState)))
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea
            (
              child: Transform.rotate(
                angle: 90 * math.pi / 180,
                child: Icon(Icons.battery_full, color: Colors.blue, size: 50)
                )
            ),
          ),
        ],
      ),
    );
  }
}

class CameraControls extends StatelessWidget {
  const CameraControls({
    super.key,
    required this.appState,
    required this.mqttComms,
  });

  final ControlState appState;
  final MqttComms mqttComms;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ControlButton(direction: ButtonDirection.cameraUp, controlState: appState, mqttComms: mqttComms),
        ControlButton(direction: ButtonDirection.cameraDown, controlState: appState, mqttComms: mqttComms),
      ],
    );
  }
}

class MovementControls extends StatelessWidget {
  const MovementControls({
    super.key,
    required this.appState,
    required this.mqttComms,
  });

  final ControlState appState;
  final MqttComms mqttComms;
 
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ControlButton(direction: ButtonDirection.forward, controlState: appState, mqttComms: mqttComms),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ControlButton(direction: ButtonDirection.left, controlState: appState, mqttComms: mqttComms),
            ControlButton(direction: ButtonDirection.backward, controlState: appState, mqttComms: mqttComms),
            ControlButton(direction: ButtonDirection.right, controlState: appState, mqttComms: mqttComms),
          ],
        ),
      ],
    );
  }
}

class MovementStatusDisplay extends StatelessWidget {
  const MovementStatusDisplay({
    super.key,
    required this.movementStatus,
  });

  final String movementStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );


    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(movementStatus, style: style),
      ),
    );
  }
}