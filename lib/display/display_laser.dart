import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ros_flutter_gui_app/basic/occupancy_map.dart';
import 'package:ros_flutter_gui_app/provider/ros_channel.dart';

class DisplayLaser extends StatefulWidget {
  List<Offset> pointList = [];

  DisplayLaser({required this.pointList});

  @override
  DisplayLaserState createState() => DisplayLaserState();
}

class DisplayLaserState extends State<DisplayLaser>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 2000))
          ..repeat();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset updateMoveOffset = Offset(0, 0);
  Offset startMoveOffset = Offset(0, 0);
  Offset endMoveOffset = Offset(0, 0);
  @override
  Widget build(BuildContext context) {
    //너비와 높이 계산
    int width = 0;
    int height = 0;
    widget.pointList.forEach((element) {
      if (element.dx > width) {
        width = element.dx.toInt();
      }
      if (element.dy > height) {
        height = element.dy.toInt();
      }
    });
    return RepaintBoundary(
        child: Container(
      width: width.toDouble(),
      height: height.toDouble(),
      // color: Colors.red,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: DisplayLaserPainter(pointList: widget.pointList),
          );
        },
      ),
    ));
  }
}

class DisplayLaserPainter extends CustomPainter {
  List<Offset> pointList = [];

  Paint _paint = Paint()..style = PaintingStyle.fill;

  DisplayLaserPainter({required this.pointList});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.red // 전달된 색상 매개변수에 색상을 설정합니다.
      ..strokeCap = StrokeCap.butt // 둥근 점을 그릴 수 있도록 브러시의 끝점을 원으로 설정
      ..strokeWidth = 1; // 브러시 너비를 1픽셀로 설정
    canvas.drawPoints(PointMode.points, pointList, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
