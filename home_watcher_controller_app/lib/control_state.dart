import 'package:flutter/material.dart';

class ControlState extends ChangeNotifier {
  String current = 'Waiting for input';
  bool keyboardInitialized = false;

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

  void initializeKeyboard()
  {
    keyboardInitialized = true;
  }
}