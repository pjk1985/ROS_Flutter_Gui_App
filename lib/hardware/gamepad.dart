import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gamepads/gamepads.dart';
import 'dart:async';
import 'package:provider/provider.dart';

enum KeyName {
  leftAxisX,
  leftAxisY,
  rightAxisX,
  rightAxisY,
  lS,
  rS,
  triggerLeft,
  triggerRight,
  buttonUpDown,
  buttonLeftRight,
  buttonA,
  buttonB,
  buttonX,
  buttonY,
  buttonLB,
  buttonRB,
}

class JoyStickEvent {
  late KeyName keyName;
  int reverse = 1; //반전할지 여부(반전하려면 -1 입력)
  int maxValue = 32767;
  int minValue = -32767;
  int value = 0;
  JoyStickEvent(this.keyName,
      {this.reverse = 1, this.maxValue = 32767, this.minValue = -32767});
}

// Dart의 클래스 이름을 JavaScript의 클래스 이름으로 매핑하는 매핑 관계 정의
Map<int, JoyStickEvent> axisMapping = {
  0: JoyStickEvent(KeyName.leftAxisX),
  1: JoyStickEvent(KeyName.leftAxisY),
  2: JoyStickEvent(KeyName.rightAxisX),
  3: JoyStickEvent(KeyName.rightAxisY),
  4: JoyStickEvent(KeyName.triggerRight),
  5: JoyStickEvent(KeyName.triggerLeft),
  6: JoyStickEvent(KeyName.buttonLeftRight),
  7: JoyStickEvent(KeyName.buttonUpDown),
};
Map<int, JoyStickEvent> buttonMapping = {
  0: JoyStickEvent(KeyName.buttonA, maxValue: 1, minValue: 0),
  1: JoyStickEvent(KeyName.buttonB, maxValue: 1, minValue: 0),
  3: JoyStickEvent(KeyName.buttonX, maxValue: 1, minValue: 0),
  4: JoyStickEvent(KeyName.buttonY, maxValue: 1, minValue: 0),
  6: JoyStickEvent(KeyName.buttonLB, maxValue: 1, minValue: 0),
  7: JoyStickEvent(KeyName.buttonRB, maxValue: 1, minValue: 0),
};

class JoyStickController extends ChangeNotifier {
  JoyStickController() {}
  StreamSubscription<GamepadEvent>? _subscription;
  late JoyStickEvent buttonEvent_;
  late JoyStickEvent axisEvent_;
  void startListen() {
    if (!Platform.isLinux) return;
    _subscription = Gamepads.events.listen((event) {
      int key = int.parse(event.key);
      int value = event.value.toInt();
      if (event.type == KeyType.button) {
        if (buttonMapping.containsKey(key)) {
          axisEvent_ = buttonMapping[key]!;
          axisEvent_.value = value;

          notifyListeners();
        } else {
          print(
              'current button not mapping! event key: ${event.key},value:${event.value}type:${event.type}');
        }
      } else {
        if (axisMapping.containsKey(key)) {
          axisEvent_ = axisMapping[key]!;
          axisEvent_.value = value;
          notifyListeners();
        } else {
          print(
              'current axis not mapping! event key: ${event.key},value:${event.value}type:${event.type}');
        }
      }
    });
  }

  void stopListen() {
    if (_subscription != null) _subscription?.cancel();
  }
}
