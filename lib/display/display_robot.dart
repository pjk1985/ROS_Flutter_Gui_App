import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ros_flutter_gui_app/basic/RobotPose.dart';
import 'package:ros_flutter_gui_app/basic/occupancy_map.dart';

class DisplayRobot extends StatefulWidget {
  late double size;
  late Color color = const Color(0xFF0080ff);
  int count = 2;
  double direction = 0; //기본 방향은 0. 전면은 오른쪽을 향하고 있습니다.
  DisplayRobot(
      {required this.size,
      required this.color,
      required this.count,
      this.direction = 0});

  @override
  _DisplayRobotState createState() => _DisplayRobotState();
}

class _DisplayRobotState extends State<DisplayRobot>
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
    return Container(
      width: widget.size,
      height: widget.size,
      // decoration: BoxDecoration(
      //   border: Border.all(
      //     color: Colors.red,
      //     width: 1,
      //   ),
      // ),
      // color: Colors.red,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: DisplayRobotPainter(_controller.value,
                count: widget.count,
                color: widget.color,
                direction: widget.direction),
          );
        },
      ),
    );
  }
}

class DisplayRobotPainter extends CustomPainter {
  final double progress;
  final int count;
  final Color color;
  final double direction;
  Paint _paint = Paint()..style = PaintingStyle.fill;

  DisplayRobotPainter(
    this.progress, {
    this.count = 3,
    this.color = Colors.yellow,
    this.direction = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    //로봇 좌표 그리기
    double radius = min(size.width / 2, size.height / 2);
    for (int i = count; i >= 0; i--) {
      final double opacity = (1.0 - ((i + progress) / (count + 1)));
      _paint.color = color.withOpacity(opacity);

      double _radius = radius * ((i + progress) / (count + 1));

      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), _radius, _paint);
    }

    //중심점
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), radius * 0.2, _paint);

    Paint dirPainter = Paint()..style = PaintingStyle.fill;
    dirPainter.color = color.withOpacity(0.3);
    Rect rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: radius);

    //방향
    canvas.drawArc(
        rect, direction - deg2rad(15), deg2rad(30), true, dirPainter);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
