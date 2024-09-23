import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ros_flutter_gui_app/basic/occupancy_map.dart';
import 'package:ros_flutter_gui_app/provider/ros_channel.dart';

class DisplayPath extends CustomPainter {
  List<Offset> pointList = [];
  Color color = Colors.green;
  DisplayPath({required this.pointList, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color // 전달된 색상 매개변수에 색상을 설정
      ..strokeCap = StrokeCap.butt // 둥근 점을 그릴 수 있도록 브러시의 끝점을 원으로 설정
      ..strokeWidth = 1; // 브러시 너비를 1픽셀로 설정
    canvas.drawPoints(PointMode.points, pointList, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
