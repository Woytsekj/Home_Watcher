// Global Packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
//import 'package:video_player/video_player.dart';

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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Watching the Home:'), 
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

/*
// Stateful widget to fetch and then display video content.
class VideoApp extends StatefulWidget {
  const VideoApp({
    super.key,
    });

  @override
  VideoAppState createState() => VideoAppState();
}

class VideoAppState extends State<VideoApp> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(
        'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'))
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  void pauseVideo() {
    _controller.pause();
  }

  void playVideo() {
    _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      home: Scaffold(
        body: Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : Container(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
*/