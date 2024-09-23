import 'package:flutter/material.dart';

class DisplayGrid extends StatelessWidget {
  DisplayGrid({required this.step, required this.width, required this.height});
  double step = 20;
  double width = 300;
  double height = 300;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      color: theme.scaffoldBackgroundColor,
      child: CustomPaint(
        painter: GridPainter(
          step: step,
          color: isDarkMode
              ? Colors.white.withAlpha(60)
              : Colors.black.withAlpha(60),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  late double step;
  Color color;

  GridPainter({required this.step, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round // 둥근 끝점
      ..strokeWidth = 2.0;

    for (double x = 0; x <= size.width; x += step) {
      for (double y = 0; y <= size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.0, paint); // 그리드 교차점에 점 그리기
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
