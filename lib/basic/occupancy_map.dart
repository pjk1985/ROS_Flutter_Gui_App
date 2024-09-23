import 'package:flutter/material.dart';
import 'dart:math';

class MapConfig {
  String image = "./";
  double resolution = 0.1;
  double originX = 0;
  double originY = 0;
  double originTheta = 0;
  int width = 0;
  int height = 0;
}

class OccupancyMap {
  MapConfig mapConfig = MapConfig();
  List<List<int>> data = [[]];
  int Rows() {
    return mapConfig.height;
  }

  int Cols() {
    return mapConfig.width;
  }

  int width() {
    return mapConfig.width;
  }

  int height() {
    return mapConfig.height;
  }

  void setFlip() {
    data = List.from(data.reversed);
  }

  /**
   * @description: 래스터 지도의 좌표를 입력하고 위치의 전역 좌표를 반환
   * @return {*}
   */
  Offset idx2xy(Offset occPoint) {
    double y =
        (height() - occPoint.dy) * mapConfig.resolution + mapConfig.originY;
    double x = occPoint.dx * mapConfig.resolution + mapConfig.originX;
    return Offset(x, y);
  }

  /**
   * @description: 전역 좌표를 입력하고 래스터 지도의 행 및 열 번호를 반환
   * @return {*}
   */
  Offset xy2idx(Offset mapPoint) {
    double x = (mapPoint.dx - mapConfig.originX) / mapConfig.resolution;
    double y =
        height() - (mapPoint.dy - mapConfig.originY) / mapConfig.resolution;
    return Offset(x, y);
  }
}
