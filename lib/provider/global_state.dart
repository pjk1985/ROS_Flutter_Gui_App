import 'package:flutter/cupertino.dart';

enum Mode {
  noraml,
  reloc, //재배치 모드
  addNavPoint, //탐색 지점 추가 모드
  robotFixedCenter, //Android 화면 중앙 고정 모드
}

class GlobalState extends ChangeNotifier {
   ValueNotifier<Mode> mode = ValueNotifier(Mode.noraml);
   ValueNotifier<bool> isManualCtrl = ValueNotifier(false);
}
