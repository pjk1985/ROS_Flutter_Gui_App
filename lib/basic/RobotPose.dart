import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

class RobotPose {
  double x;
  double y;
  double theta;

  RobotPose(this.x, this.y, this.theta);

  RobotPose.zero()
      : x = 0,
        y = 0,
        theta = 0;

  // JSON에서 구문 분석
  RobotPose.fromJson(Map<String, dynamic> json)
      : x = json['x'],
        y = json['y'],
        theta = json['theta'];

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'theta': theta,
      };
  @override
  String toString() => 'RobotPose(x: $x, y: $y, theta: $theta)';
  RobotPose operator +(RobotPose other) =>
      RobotPose(x + other.x, y + other.y, theta + other.theta);
  RobotPose operator -(RobotPose other) =>
      RobotPose(x - other.x, y - other.y, theta - other.theta);
}

/*
@desc 두 포즈의 합 p2는 증분을 나타냅니다. 이 기능은 P1의 포즈와 P2의 증분으로 표현됩니다.
*/
RobotPose absoluteSum(RobotPose p1, RobotPose p2) {
  double s = sin(p1.theta);
  double c = cos(p1.theta);
  return RobotPose(c * p2.x - s * p2.y, s * p2.x + c * p2.y, p2.theta) + p1;
}

/*
@desc 두 포즈의 차이는 P2를 원점으로 하는 좌표계에서 P1의 좌표를 계산하는 데 사용됩니다.
*/
RobotPose absoluteDifference(RobotPose p1, RobotPose p2) {
  RobotPose delta = p1 - p2;
  delta.theta = atan2(sin(delta.theta), cos(delta.theta));
  double s = sin(p2.theta), c = cos(p2.theta);
  return RobotPose(
      c * delta.x + s * delta.y, -s * delta.x + c * delta.y, delta.theta);
}

double deg2rad(double deg) => deg * pi / 180;

double rad2deg(double rad) => rad * 180 / pi;

RobotPose GetRobotPoseFromMatrix(Matrix4 matrix) {
  double x = matrix.storage[12];
  double y = matrix.storage[13];
  // 회전 각도 세타(라디안) 추출
  double theta = atan2(matrix.storage[1], matrix.storage[0]); // 세타 계산

  return RobotPose(x, y, theta);
}
