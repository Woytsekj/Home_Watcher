import 'package:flutter/material.dart';

import 'http_comms.dart';
import 'control_state.dart';

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
  });

  final ButtonDirection direction;
  final ControlState controlState;

  @override
  Widget build(BuildContext context) {
    String buttonText = '';
    String statusText = '';
    String buttonCommand = '';

    switch (direction) {
      case ButtonDirection.forward:
        buttonText = '^';
        statusText = 'Moving Forward';
        buttonCommand = 'MoveForward';
      
      case ButtonDirection.backward:
        buttonText = 'v';
        statusText = 'Moving Backward';
        buttonCommand = 'MoveBackward';

      case ButtonDirection.left:
        buttonText = '<';
        statusText = 'Turning Left';
        buttonCommand = 'TurnLeft';

      case ButtonDirection.right:
        buttonText = '>';
        statusText = 'Turning Right';
        buttonCommand = 'TurnRight';

      case ButtonDirection.cameraUp:
        buttonText = '📷 ^';
        statusText = 'Camera Moving Up';
        buttonCommand = 'CameraUp';

      case ButtonDirection.cameraDown:
        buttonText = '📷 v';
        statusText = 'Camera Moving Down';
        buttonCommand = 'CameraDown';
      }

    final releaseCommand = 'Stop$buttonCommand';

    return GestureDetector(
      onLongPressDown: (_) {
        HttpComms.sendCommandProtected(buttonCommand);
        controlState.setState(statusText);
      },

      onLongPressEnd: (_) {
        HttpComms.sendCommandProtected(releaseCommand);
        controlState.stopState();
      },

      onLongPressCancel: () {
        HttpComms.sendCommandProtected(releaseCommand);
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