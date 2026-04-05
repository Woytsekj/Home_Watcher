import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';

import 'src/mqtt_server_client.dart';

class BatteryWidget extends StatefulWidget {
  final MqttComms mqttComms;

  const BatteryWidget({super.key, required this.mqttComms});

  @override
  State<BatteryWidget> createState() => _BatteryWidgetState(this.mqttComms);
}

class _BatteryWidgetState extends State<BatteryWidget> {
  double batteryLevel = -1;
  Timer? _batteryLevelRequestTimer;

  final MqttComms mqttComms;

  Icon batteryIcon = const Icon(Icons.battery_alert, color: Colors.red, size: 50);
  
  _BatteryWidgetState(this.mqttComms);

  @override
  void initState() {
    super.initState();
    // Set up MQTT callback for battery level messages
    mqttComms.onBatteryLevelReceived = (String batteryLevelStr) {
      print('BatteryWidget::Received battery level message: $batteryLevelStr');
      double? batteryLevel = double.tryParse(batteryLevelStr);
      if (batteryLevel != null) {
        print('BatteryWidget::Parsed battery level: $batteryLevel');
        updateBatteryLevel(batteryLevel);
      } else {
        print('BatteryWidget::Failed to parse battery level: $batteryLevelStr');
      }
    };

    _batteryLevelRequestTimer = Timer.periodic(const Duration(seconds: 60), requestBatteryLevelTimeout);

    mqttComms.publishCommand('requestBatteryLevel');
  }

  void requestBatteryLevelTimeout(Timer timer)
  {
    if (batteryLevel < 0)
    {
      print('BatteryWidget::Battery level request timed out, requesting update from robot');
      mqttComms.publishCommand('requestBatteryLevel');
    } else {
      // Battery level has been received, stop the timer
      _batteryLevelRequestTimer?.cancel();
    }
  }

  void updateBatteryLevel(double newLevel) {
    setState(() {
      batteryLevel = newLevel;
      if (batteryLevel > 90) {
        batteryIcon = const Icon(Icons.battery_full, color: Colors.blue, size: 50);
      } else if (batteryLevel > 75) {
        batteryIcon = const Icon(Icons.battery_5_bar, color: Colors.blue, size: 50);
      } else if (batteryLevel > 50) {
        batteryIcon = const Icon(Icons.battery_3_bar, color: Colors.blue, size: 50);
      } else if (batteryLevel > 25) {
        batteryIcon = const Icon(Icons.battery_2_bar, color: Colors.blue, size: 50);
      } else if (batteryLevel > 10) {
        batteryIcon = const Icon(Icons.battery_1_bar, color: Colors.yellow, size: 50);
      } else {
        batteryIcon = const Icon(Icons.battery_0_bar, color: Colors.red, size: 50);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
                angle: 90 * math.pi / 180,
                child: batteryIcon
    );
  }
}