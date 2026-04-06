// Global Packages
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_watcher_controller_app/battery_widget.dart';
import 'package:home_watcher_controller_app/src/signaling.dart';
import 'package:provider/provider.dart';


// Local Classes
import 'control_state.dart';
import 'control_button.dart';
import 'menu_entry.dart';
import 'src/p2p_call.dart';
import 'src/mqtt_server_client.dart';

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
  late Signaling signaling;

  @override
  void initState() {
    super.initState();
    mqttComms.setupClient();
    signaling = Signaling(mqttComms);
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
        home: MyHomePage(mqttComms: mqttComms, signaling: signaling),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}


class MyHomePage extends StatelessWidget {
  
  const MyHomePage({
    super.key,
    required this.mqttComms,
    required this.signaling,
  });

  final MqttComms mqttComms;
  final Signaling signaling;

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
            label: 'Send WebRTC Offer',
            onPressed: () async {
              
              appState.setState("Sending WebRTC Offer");
              signaling.invite("1");
            },
          ),
          MenuEntry(
            label: 'Request Battery Level',
            onPressed: () async {
              
              appState.setState("Requesting Battery Level");
              mqttComms.publishCommand('requestBatteryLevel');
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

    if (appState.keyboardInitialized == false)
    {
      appState.initializeKeyboard();
      bool handleKeyPress(KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            mqttComms.publishCommand('moveForward');
            appState.setState('Moving Forward');
            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            mqttComms.publishCommand('moveBackward');
            appState.setState('Moving Backward');
            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            mqttComms.publishCommand('turnLeft');
            appState.setState('Turning Left');
            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            mqttComms.publishCommand('turnRight');
            appState.setState('Turning Right');
            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
            mqttComms.publishCommand('SERVO_UP');
            appState.setState('Camera Moving Up');
            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
            mqttComms.publishCommand('SERVO_DOWN');
            appState.setState('Camera Moving Down');
            return true;
          }
        } else if (event is KeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowRight) {
            mqttComms.publishCommand('stop');
            appState.stopState();
            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.keyW ||
                    event.logicalKey == LogicalKeyboardKey.keyS) {
            mqttComms.publishCommand('stopCamera');
            appState.stopState();
            return true;
          }
        }
        return false;
      }

      HardwareKeyboard.instance.addHandler(handleKeyPress);
    }
    

    return Scaffold(
      body: Stack(
        children: [
          CallSample(signaling),
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
              child: BatteryWidget(mqttComms: mqttComms)
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