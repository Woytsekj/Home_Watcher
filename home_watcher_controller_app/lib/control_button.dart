import 'package:flutter/material.dart';

import 'control_state.dart';
import 'src/mqtt_server_client.dart';

enum ButtonDirection
{
  forward,
  backward,
  left,
  right,
  cameraUp,
  cameraDown
}

class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.direction,
    required this.controlState,
    required this.mqttComms
  });

  final ButtonDirection direction;
  final ControlState controlState;
  final MqttComms mqttComms;

  @override
  Widget build(BuildContext context) {
    String buttonText = '';
    String statusText = '';
    String buttonCommand = '';
    String releaseCommand = 'stop';

    switch (direction) {
      case ButtonDirection.forward:
        buttonText = '^';
        statusText = 'Moving Forward';
        buttonCommand = 'moveForward';
      
      case ButtonDirection.backward:
        buttonText = 'v';
        statusText = 'Moving Backward';
        buttonCommand = 'moveBackward';

      case ButtonDirection.left:
        buttonText = '<';
        statusText = 'Turning Left';
        buttonCommand = 'turnLeft';

      case ButtonDirection.right:
        buttonText = '>';
        statusText = 'Turning Right';
        buttonCommand = 'turnRight';

      case ButtonDirection.cameraUp:
        buttonText = '📷 ^';
        statusText = 'Camera Moving Up';
        buttonCommand = 'SERVO_UP';
        releaseCommand = 'stopCamera';

      case ButtonDirection.cameraDown:
        buttonText = '📷 v';
        statusText = 'Camera Moving Down';
        buttonCommand = 'SERVO_DOWN';
        releaseCommand = 'stopCamera';
      }

    return GestureDetector(
      onLongPressDown: (_) {
        mqttComms.publishCommand(buttonCommand);
        controlState.setState(statusText);
      },

      onLongPressEnd: (_) {
        mqttComms.publishCommand(releaseCommand);
        controlState.stopState();
      },

      onLongPressCancel: () {
        mqttComms.publishCommand(releaseCommand);
        controlState.stopState();
      },

      child: ElevatedButton(
        onPressed: () {
          // Just Placeholder to enable the button
        },
      
        child: Text(buttonText)
      ),
    );
  }
}