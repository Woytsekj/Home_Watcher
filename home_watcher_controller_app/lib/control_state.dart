import 'package:flutter/material.dart';

class ControlState extends ChangeNotifier {
  var current = 'Waiting for input';

  void setState(String newState) {
    current = newState;
    print(current);
    notifyListeners();
  }

  void stopState()
  {
    current = 'Robot Stopped';
    print(current);
    notifyListeners();
  }
}