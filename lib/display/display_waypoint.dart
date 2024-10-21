import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ros_flutter_gui_app/basic/RobotPose.dart';
import 'package:ros_flutter_gui_app/basic/occupancy_map.dart';

class DisplayWayPoint extends StatefulWidget {
  late double size;
  late Color color = const Color(0xFF0080ff);
  int count = 2;
  DisplayWayPoint(
      {required this.size, required this.color, required this.count});

  @override
  _DisplayWayPointState createState() => _DisplayWayPointState();
}

class _DisplayWayPointState extends State<DisplayWayPoint>
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
            painter: DisplayWayPointPainter(_controller.value,
                count: widget.count, color: widget.color),
          );
        },
      ),
    );
  }
}

class DisplayWayPointPainter extends CustomPainter {
  final double progress;
  final int count;
  final Color color;

  Paint _paint = Paint()..style = PaintingStyle.fill;

  DisplayWayPointPainter(this.progress,
      {this.count = 3, this.color = Colors.yellow});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // 로봇 좌표 그리기
    double radius = min(size.width / 2, size.height / 2);

    for (int i = count; i >= 0; i--) {
      final double opacity = (1.0 - ((i + progress) / (count + 1)));
      _paint.color = color.withOpacity(opacity);

      double _radius = radius * ((i + progress) / (count + 1));

      // 마름모의 꼭지점 4개 계산
      final path = Path()
        ..moveTo(size.width / 2 + _radius, size.height / 2) // 오른쪽 꼭지점
        ..lineTo(size.width / 2, size.height / 2 + _radius) // 아래쪽 꼭지점
        ..lineTo(size.width / 2 - _radius, size.height / 2) // 왼쪽 꼭지점
        ..lineTo(size.width / 2, size.height / 2 - _radius) // 위쪽 꼭지점
        ..close();

      // 경로 그리기
      canvas.drawPath(path, _paint);
    }

    final path = Path()
      ..moveTo(size.width / 2 + radius / 3, size.height / 2) // 오른쪽 꼭지점
      ..lineTo(size.width / 2, size.height / 2 + radius / 3) // 아래쪽 꼭지점
      ..lineTo(size.width / 2 - radius / 3, size.height / 2) // 왼쪽 꼭지점
      ..lineTo(size.width / 2, size.height / 2 - radius / 3) // 위쪽 꼭지점
      ..close();

    // 경로 그리기
    canvas.drawPath(path, _paint);

    Paint dirPainter = Paint()..style = PaintingStyle.fill;
    dirPainter.color = color.withOpacity(0.3);
    Rect rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: radius);
    canvas.drawArc(rect, -deg2rad(15), deg2rad(30), true, dirPainter);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
