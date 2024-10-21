import 'dart:async';
import 'dart:math';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:provider/provider.dart';
import 'package:ros_flutter_gui_app/basic/RobotPose.dart';
import 'package:ros_flutter_gui_app/basic/gamepad_widget.dart';
import 'package:ros_flutter_gui_app/basic/math.dart';
import 'package:ros_flutter_gui_app/basic/matrix_gesture_detector.dart';
import 'package:ros_flutter_gui_app/basic/occupancy_map.dart';
import 'package:ros_flutter_gui_app/display/display_laser.dart';
import 'package:ros_flutter_gui_app/display/display_path.dart';
import 'package:ros_flutter_gui_app/display/display_robot.dart';
import 'package:ros_flutter_gui_app/display/display_pose_direction.dart';
import 'package:ros_flutter_gui_app/global/setting.dart';
import 'package:ros_flutter_gui_app/provider/global_state.dart';
import 'package:ros_flutter_gui_app/provider/ros_channel.dart';
import 'package:ros_flutter_gui_app/display/display_map.dart';
import 'package:ros_flutter_gui_app/display/display_grid.dart';
import 'package:toast/toast.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:ros_flutter_gui_app/display/display_waypoint.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  ValueNotifier<bool> manualCtrlMode_ = ValueNotifier(false);
  ValueNotifier<List<RobotPose>> navPointList_ =
      ValueNotifier<List<RobotPose>>([]);
  final ValueNotifier<Matrix4> gestureTransform =
      ValueNotifier(Matrix4.identity());

  bool showCamera = false;

  Offset camPosition = Offset(30, 10); // 初始位置
  bool isCamFullscreen = false; // 是否全屏
  Offset camPreviousPosition = Offset(30, 10); // 保存进入全屏前的位置
  late double camWidgetWidth;
  late double camWidgetHeight;

  Matrix4 cameraFixedTransform = Matrix4.identity(); //카메라 고정(로봇 중심)
  double cameraFixedScaleValue_ = 1; //카메라 각도 고정 시 줌 값

  late AnimationController animationController;
  late Animation<double> animationValue;

  final ValueNotifier<RobotPose> robotPose_ = ValueNotifier(RobotPose(0, 0, 0));
  final ValueNotifier<double> gestureScaleValue_ = ValueNotifier(1);
  OverlayEntry? _overlayEntry;
  RobotPose currentNavGoal_ = RobotPose.zero();

  int poseDirectionSwellSize = 10; //로봇 방향 회전 제어 확장 사이즈
  double navPoseSize = 15; //탐색 포인터 크기
  double robotSize = 20; //로봇 좌표의 크기
  RobotPose poseSceneStartReloc = RobotPose(0, 0, 0);
  RobotPose poseSceneOnReloc = RobotPose(0, 0, 0);
  double calculateApexAngle(double r, double d) {
    // 코사인 정리를 사용하여 꼭지점 각도의 코사인
    double cosC = (r * r + r * r - d * d) / (2 * r * r);
    // 꼭짓점 라디안 계산
    double apexAngleRadians = acos(cosC);
    return apexAngleRadians;
  }

  @override
  void initState() {
    super.initState();
    globalSetting.init();
    // 初始化 AnimationController
    animationController = AnimationController(
      duration: const Duration(seconds: 2), // 애니메이션은 1초 동안 지속
      vsync: this,
    );

    // 1.0에서 2.0으로 트윈 초기화
    animationValue =
        Tween<double>(begin: 1.0, end: 4.0).animate(animationController)
          ..addListener(() {
            setState(() {
              cameraFixedScaleValue_ =
                  animationValue.value; // CameraFixedScaleValue_ 업데이트
            });
          });
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final overlay =
        Overlay.of(context)?.context.findRenderObject() as RenderBox;
    final menuOverlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextButton(onPressed: () {}, child: const Text("확인")),
                    TextButton(
                        onPressed: () {
                          _hideContextMenu();
                        },
                        child: const Text("취소"))
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );

    menuOverlay?.insert(_overlayEntry!);
  }

  void _hideContextMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    ToastContext().init(context);
    final _key = GlobalKey<ExpandableFabState>();
    final screenSize = MediaQuery.of(context).size;
    final screenCenter = Offset(screenSize.width / 2, screenSize.height / 2);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    camWidgetWidth = screenSize.width / 3.5;
    camWidgetHeight =
        camWidgetWidth / (globalSetting.imageWidth / globalSetting.imageHeight);

    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: gestureTransform,
            builder: (ctx, child) {
              return Container(
                  width: screenSize.width,
                  height: screenSize.height,
                  child: MatrixGestureDetector(
                    onMatrixUpdate:
                        (matrix, transDelta, scaleValue, rotateDelta) {
                      if (Provider.of<GlobalState>(context, listen: false)
                              .mode
                              .value ==
                          Mode.robotFixedCenter) {
                        Toast.show("카메라 각도가 고정되면 레이어를 조정할 수 없습니다!",
                            duration: Toast.lengthShort, gravity: Toast.bottom);
                        return;
                      }

                      gestureTransform.value = matrix;
                      gestureScaleValue_.value = scaleValue;
                    },
                    child: ValueListenableBuilder<RobotPose>(
                        valueListenable:
                            Provider.of<RosChannel>(context, listen: false)
                                .robotPoseScene,
                        builder: (context, robotPoseScene, child) {
                          double scaleValue = gestureScaleValue_.value;
                          var globalTransform = gestureTransform.value;
                          var originPose = Offset.zero;
                          if (Provider.of<GlobalState>(context, listen: false)
                                  .mode
                                  .value ==
                              Mode.robotFixedCenter) {
                            scaleValue = cameraFixedScaleValue_;
                            globalTransform = Matrix4.identity()
                              ..translate(screenCenter.dx - robotPoseScene.x,
                                  screenCenter.dy - robotPoseScene.y)
                              ..rotateZ(robotPoseScene.theta - deg2rad(90))
                              ..scale(scaleValue);
                            originPose =
                                Offset(robotPoseScene.x, robotPoseScene.y);
                          }

                          return Stack(
                            children: [
                              //그리드
                              Container(
                                child: DisplayGrid(
                                  step: (1 /
                                          Provider.of<RosChannel>(context)
                                              .map
                                              .value
                                              .mapConfig
                                              .resolution) *
                                      (scaleValue > 0.8 ? scaleValue : 0.8),
                                  width: screenSize.width,
                                  height: screenSize.height,
                                ),
                              ),
                              //지도
                              Transform(
                                transform: globalTransform,
                                origin: originPose,
                                child: GestureDetector(
                                  child: const DisplayMap(),
                                  onTapDown: (details) {
                                    if (Provider.of<GlobalState>(context,
                                                listen: false)
                                            .mode
                                            .value ==
                                        Mode.addNavPoint) {
                                      navPointList_.value.add(RobotPose(
                                          details.localPosition.dx,
                                          details.localPosition.dy,
                                          0));
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),

                              //전역 경로
                              Transform(
                                transform: globalTransform,
                                origin: originPose,
                                child: RepaintBoundary(
                                  child: ValueListenableBuilder<List<Offset>>(
                                    valueListenable: Provider.of<RosChannel>(
                                            context,
                                            listen: false)
                                        .globalPath,
                                    builder: (context, path, child) {
                                      return Container(
                                        child: CustomPaint(
                                          painter: DisplayPath(
                                              pointList: path,
                                              color: Colors.green),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              //로컬 경로
                              Transform(
                                transform: globalTransform,
                                origin: originPose,
                                child: RepaintBoundary(
                                    child: ValueListenableBuilder<List<Offset>>(
                                  valueListenable: Provider.of<RosChannel>(
                                          context,
                                          listen: false)
                                      .localPath,
                                  builder: (context, path, child) {
                                    return Container(
                                      child: CustomPaint(
                                        painter: DisplayPath(
                                            pointList: path,
                                            color: Colors.yellow[200]!),
                                      ),
                                    );
                                  },
                                )),
                              ),

                              Transform(
                                transform: globalTransform,
                                origin: originPose,
                                child: RepaintBoundary(
                                    child: ValueListenableBuilder<LaserData>(
                                        valueListenable:
                                            Provider.of<RosChannel>(context,
                                                    listen: false)
                                                .laserPointData,
                                        builder: (context, laserData, child) {
                                          RobotPose robotPoseMap =
                                              laserData.robotPose;
                                          var map = Provider.of<RosChannel>(
                                                  context,
                                                  listen: false)
                                              .map
                                              .value;
                                          //재배치 모드 레이어 좌표에서 변환
                                          if (Provider.of<GlobalState>(context,
                                                      listen: false)
                                                  .mode
                                                  .value ==
                                              Mode.reloc) {
                                            Offset poseMap = map.idx2xy(Offset(
                                                poseSceneOnReloc.x,
                                                poseSceneOnReloc.y));
                                            robotPoseMap = RobotPose(
                                                poseMap.dx,
                                                poseMap.dy,
                                                poseSceneOnReloc.theta);
                                          }

                                          List<Offset> laserPointsScene = [];
                                          for (var point
                                              in laserData.laserPoseBaseLink) {
                                            RobotPose pointMap = absoluteSum(
                                                robotPoseMap,
                                                RobotPose(
                                                    point.dx, point.dy, 0));
                                            Offset pointScene = map.xy2idx(
                                                Offset(pointMap.x, pointMap.y));
                                            laserPointsScene.add(pointScene);
                                          }
                                          return IgnorePointer(
                                              ignoring: true,
                                              child: DisplayLaser(
                                                  pointList: laserPointsScene));
                                        })),
                              ),
                              //내비게이션 포인트
                              ...navPointList_.value.map((pose) {
                                return Transform(
                                  transform: globalTransform,
                                  origin: originPose,
                                  child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()
                                        ..translate(
                                            pose.x -
                                                navPoseSize / 2 -
                                                poseDirectionSwellSize / 2,
                                            pose.y -
                                                navPoseSize / 2 -
                                                poseDirectionSwellSize / 2)
                                        ..rotateZ(-pose.theta),
                                      child: MatrixGestureDetector(
                                          onMatrixUpdate: (matrix, transDelta,
                                              scaleDelta, rotateDelta) {
                                            // print("transDelta:${transDelta}");
                                            if (Provider.of<GlobalState>(
                                                        context,
                                                        listen: false)
                                                    .mode
                                                    .value ==
                                                Mode.addNavPoint) {
                                              //이동 거리의 델타 거리를 현재 축척 값으로 나누어야 합니다. (확대한 후에는 동일한 이동 거리에 대해 실제로 지도가 덜 이동합니다.)
                                              double dx =
                                                  transDelta.dx / scaleValue;
                                              double dy =
                                                  transDelta.dy / scaleValue;
                                              double tmpTheta = pose.theta;
                                              pose = absoluteSum(
                                                  RobotPose(pose.x, pose.y,
                                                      pose.theta),
                                                  RobotPose(dx, dy, 0));
                                              pose.theta = tmpTheta;
                                              print("trans pose:${pose}");
                                              setState(() {});
                                            }
                                          },
                                          child: Container(
                                            height: navPoseSize +
                                                poseDirectionSwellSize,
                                            width: navPoseSize +
                                                poseDirectionSwellSize,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Visibility(
                                                    visible:
                                                        Provider.of<GlobalState>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .mode
                                                                .value ==
                                                            Mode.addNavPoint,
                                                    child: DisplayPoseDirection(
                                                      size: navPoseSize +
                                                          poseDirectionSwellSize,
                                                      initAngle: -pose.theta,
                                                      resetAngle: false,
                                                      onRotateCallback:
                                                          (angle) {
                                                        pose.theta = -angle;
                                                        setState(() {});
                                                      },
                                                    )),
                                                GestureDetector(
                                                    onTapDown: (details) {
                                                      if (Provider.of<GlobalState>(
                                                                  context,
                                                                  listen: false)
                                                              .mode
                                                              .value ==
                                                          Mode.noraml) {
                                                        // _showContextMenu(context,
                                                        //     details.globalPosition);
                                                        Provider.of<RosChannel>(
                                                                context,
                                                                listen: false)
                                                            .sendNavigationGoal(
                                                                RobotPose(
                                                                    pose.x,
                                                                    pose.y,
                                                                    pose.theta));
                                                        currentNavGoal_ = pose;
                                                        setState(() {});
                                                      }
                                                    },
                                                    child: DisplayWayPoint(
                                                      size: navPoseSize,
                                                      color: currentNavGoal_ ==
                                                              pose
                                                          ? Colors.pink
                                                          : Colors.green,
                                                      count: 4,
                                                    )),
                                              ],
                                            ),
                                          ))),
                                );
                              }).toList(),
                              //로봇 위치(고정 원근)
                              Visibility(
                                visible: Provider.of<GlobalState>(context,
                                            listen: false)
                                        .mode
                                        .value ==
                                    Mode.robotFixedCenter,
                                child: Positioned(
                                  left: screenCenter.dx -
                                      (robotSize / 2 * cameraFixedScaleValue_),
                                  top: screenCenter.dy -
                                      (robotSize / 2 * cameraFixedScaleValue_),
                                  child: Transform(
                                    transform: Matrix4.identity()
                                      ..scale(cameraFixedScaleValue_),
                                    child: DisplayRobot(
                                      direction: deg2rad(-90),
                                      size: robotSize,
                                      color: Colors.blue,
                                      count: 2,
                                    ),
                                  ),
                                ),
                              ),
                              //로봇 위치(고정된 관점이 아님)
                              Visibility(
                                  visible: Provider.of<GlobalState>(context,
                                              listen: false)
                                          .mode
                                          .value !=
                                      Mode.robotFixedCenter,
                                  child: Transform(
                                    transform: Provider.of<GlobalState>(context,
                                                    listen: false)
                                                .mode
                                                .value ==
                                            Mode.robotFixedCenter
                                        ? cameraFixedTransform
                                        : gestureTransform.value,
                                    child: Consumer<RosChannel>(
                                      builder: (context, rosChannel, child) {
                                        if (!(Provider.of<GlobalState>(context,
                                                    listen: false)
                                                .mode
                                                .value ==
                                            Mode.reloc)) {
                                          robotPose_.value = robotPoseScene;
                                        }

                                        return Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()
                                              ..translate(
                                                  robotPose_.value.x -
                                                      robotSize / 2 -
                                                      poseDirectionSwellSize /
                                                          2,
                                                  robotPose_.value.y -
                                                      robotSize / 2 -
                                                      poseDirectionSwellSize /
                                                          2)
                                              ..rotateZ(
                                                  -robotPose_.value.theta),
                                            child: MatrixGestureDetector(
                                              onMatrixUpdate: (matrix,
                                                  transDelta,
                                                  scaleDelta,
                                                  rotateDelta) {
                                                if (Provider.of<GlobalState>(
                                                            context,
                                                            listen: false)
                                                        .mode
                                                        .value ==
                                                    Mode.reloc) {
                                                  //전역 스케일 값을 가져옵니다.

                                                  //이동 거리의 델타 거리를 현재 축척 값으로 나누어야 합니다. (확대한 후에는 동일한 이동 거리에 대해 실제로 지도가 덜 이동합니다.)
                                                  double dx = transDelta.dx /
                                                      scaleValue;
                                                  double dy = transDelta.dy /
                                                      scaleValue;
                                                  double theta =
                                                      poseSceneOnReloc.theta;
                                                  poseSceneOnReloc =
                                                      absoluteSum(
                                                          RobotPose(
                                                              poseSceneOnReloc
                                                                  .x,
                                                              poseSceneOnReloc
                                                                  .y,
                                                              0),
                                                          RobotPose(dx, dy, 0));
                                                  poseSceneOnReloc.theta =
                                                      theta;
                                                  //좌표변환합
                                                  robotPose_.value =
                                                      poseSceneOnReloc;
                                                }
                                              },
                                              child: Container(
                                                height: robotSize +
                                                    poseDirectionSwellSize,
                                                width: robotSize +
                                                    poseDirectionSwellSize,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    //스핀 상자 위치 변경
                                                    Visibility(
                                                      visible:
                                                          Provider.of<GlobalState>(
                                                                      context,
                                                                      listen:
                                                                          false)
                                                                  .mode
                                                                  .value ==
                                                              Mode.reloc,
                                                      child:
                                                          DisplayPoseDirection(
                                                        size: robotSize +
                                                            poseDirectionSwellSize,
                                                        resetAngle: Provider.of<
                                                                        GlobalState>(
                                                                    context,
                                                                    listen:
                                                                        false)
                                                                .mode
                                                                .value !=
                                                            Mode.reloc,
                                                        onRotateCallback:
                                                            (angle) {
                                                          poseSceneOnReloc
                                                                  .theta =
                                                              (poseSceneStartReloc
                                                                      .theta -
                                                                  angle);
                                                          //좌표변환합
                                                          robotPose_.value =
                                                              RobotPose(
                                                                  poseSceneOnReloc
                                                                      .x,
                                                                  poseSceneOnReloc
                                                                      .y,
                                                                  poseSceneOnReloc
                                                                      .theta);
                                                        },
                                                      ),
                                                    ),

                                                    //로봇 아이콘
                                                    DisplayRobot(
                                                      size: robotSize,
                                                      color: Colors.blue,
                                                      count: 2,
                                                    ),
                                                    // IconButton(
                                                    //   onPressed: () {},
                                                    //   iconSize: robotSize / 2,
                                                    //   icon: Icon(Icons.check),
                                                    // ),
                                                  ],
                                                ),
                                              ),
                                            ));
                                      },
                                    ),
                                  )),
                            ],
                          );
                        }),
                  ));
            },
          ),

          //메뉴바
          Positioned(
              left: 5,
              top: 1,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // 가로 스크롤
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: RawChip(
                          avatar: Icon(
                            const IconData(0xe606, fontFamily: "Speed"),
                            color: Colors.green[400],
                          ),
                          label: ValueListenableBuilder<RobotSpeed>(
                              valueListenable:
                                  Provider.of<RosChannel>(context, listen: true)
                                      .robotSpeed_,
                              builder: (context, speed, child) {
                                return Text(
                                    '${(speed.vx).toStringAsFixed(2)} m/s');
                              }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: RawChip(
                          avatar:
                              const Icon(IconData(0xe680, fontFamily: "Speed")),
                          label: ValueListenableBuilder<RobotSpeed>(
                              valueListenable:
                                  Provider.of<RosChannel>(context, listen: true)
                                      .robotSpeed_,
                              builder: (context, speed, child) {
                                return Text(
                                    '${rad2deg(speed.vx).toStringAsFixed(2)} deg/s');
                              }),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: RawChip(
                          avatar: Icon(
                            const IconData(0xe995, fontFamily: "Battery"),
                            color: Colors.amber[300],
                          ),
                          label: ValueListenableBuilder<double>(
                              valueListenable: Provider.of<RosChannel>(context,
                                      listen: false)
                                  .battery_,
                              builder: (context, battery, child) {
                                return Text('${battery.toStringAsFixed(2)} %');
                              }),
                        ),
                      ),
                    ],
                  ),
                ),
              )),

          //图像
          Visibility(
            visible: showCamera, // 根据需要显示或隐藏
            child: Positioned(
              left: camPosition.dx,
              top: camPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  if (!isCamFullscreen) {
                    setState(() {
                      double newX = camPosition.dx + details.delta.dx;
                      double newY = camPosition.dy + details.delta.dy;
                      // 限制位置在屏幕范围内
                      newX = newX.clamp(0.0, screenSize.width - camWidgetWidth);
                      newY =
                          newY.clamp(0.0, screenSize.height - camWidgetHeight);
                      camPosition = Offset(newX, newY);
                    });
                  }
                },
                child: Container(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // 在非全屏状态下，获取屏幕宽高
                          double containerWidth = isCamFullscreen
                              ? screenSize.width
                              : camWidgetWidth;
                          double containerHeight = isCamFullscreen
                              ? screenSize.height
                              : camWidgetHeight;

                          return Mjpeg(
                            stream:
                                'http://${globalSetting.robotIp}:${globalSetting.imagePort}/stream?topic=${globalSetting.imageTopic}',
                            isLive: true,
                            width: containerWidth,
                            height: containerHeight,
                            fit: BoxFit.fill,
                            // BoxFit.fill：拉伸填充满容器，可能会改变图片的宽高比。
                            // BoxFit.contain：按照图片的原始比例缩放，直到一边填满容器。
                            // BoxFit.cover：按照图片的原始比例缩放，直到容器被填满，可能会裁剪图片。
                          );
                        },
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton(
                          icon: Icon(
                            isCamFullscreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            color: Colors.black,
                          ),
                          constraints: BoxConstraints(), // 移除按钮的默认大小约束，变得更加紧凑
                          onPressed: () {
                            setState(() {
                              isCamFullscreen = !isCamFullscreen;
                              if (isCamFullscreen) {
                                // 进入全屏时，保存当前位置，并将位置设为 (0, 0)
                                camPreviousPosition = camPosition;
                                camPosition = Offset(0, 0);
                              } else {
                                // 退出全屏时，恢复之前的位置
                                camPosition = camPreviousPosition;
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          //왼쪽 도구 모음
          Positioned(
              left: 5,
              top: 60,
              child: FittedBox(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 10,
                    child: Container(
                      child: Row(
                        children: [
                          IconButton(
                              onPressed: () {
                                if (!(Provider.of<GlobalState>(context,
                                            listen: false)
                                        .mode
                                        .value ==
                                    Mode.reloc)) {
                                  Provider.of<GlobalState>(context,
                                          listen: false)
                                      .mode
                                      .value = Mode.reloc;
                                  poseSceneStartReloc = Provider.of<RosChannel>(
                                          context,
                                          listen: false)
                                      .robotPoseScene
                                      .value;

                                  poseSceneOnReloc = Provider.of<RosChannel>(
                                          context,
                                          listen: false)
                                      .robotPoseScene
                                      .value;
                                  setState(() {});
                                } else {
                                  Provider.of<GlobalState>(context,
                                          listen: false)
                                      .mode
                                      .value = Mode.noraml;
                                }
                                setState(() {});
                              },
                              icon: Icon(
                                const IconData(0xe60f, fontFamily: "Reloc"),
                                color: Provider.of<GlobalState>(context,
                                                listen: false)
                                            .mode
                                            .value ==
                                        Mode.reloc
                                    ? Colors.green
                                    : theme.iconTheme.color,
                              )),
                          Visibility(
                              visible: Provider.of<GlobalState>(context,
                                          listen: false)
                                      .mode
                                      .value ==
                                  Mode.reloc,
                              child: IconButton(
                                  onPressed: () {
                                    Provider.of<GlobalState>(context,
                                            listen: false)
                                        .mode
                                        .value = Mode.noraml;
                                    setState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ))),
                          Visibility(
                              visible: Provider.of<GlobalState>(context,
                                          listen: false)
                                      .mode
                                      .value ==
                                  Mode.reloc,
                              child: IconButton(
                                  onPressed: () {
                                    Provider.of<GlobalState>(context,
                                            listen: false)
                                        .mode
                                        .value = Mode.noraml;
                                    Provider.of<RosChannel>(context,
                                            listen: false)
                                        .sendRelocPoseScene(poseSceneOnReloc);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.check,
                                      color: Colors.green))),
                        ],
                      ),
                    ),
                  ),
                  //내비게이션 목표지점 설정
                  Card(
                    elevation: 10,
                    child: IconButton(
                      icon: Icon(
                        const IconData(0xeba1, fontFamily: "NavPoint"),
                        color: (Provider.of<GlobalState>(context, listen: false)
                                    .mode
                                    .value ==
                                Mode.addNavPoint)
                            ? Colors.green
                            : theme.iconTheme.color,
                      ),
                      onPressed: () {
                        if (!(Provider.of<GlobalState>(context, listen: false)
                                .mode
                                .value ==
                            Mode.addNavPoint)) {
                          Provider.of<GlobalState>(context, listen: false)
                              .mode
                              .value = Mode.addNavPoint;
                          setState(() {});
                        } else {
                          Provider.of<GlobalState>(context, listen: false)
                              .mode
                              .value = Mode.noraml;
                          setState(() {});
                        }
                      },
                    ),
                  ),

                  //显示相机图像
                  Card(
                    elevation: 10,
                    child: IconButton(
                      icon: Icon(Icons.camera_alt),
                      color: showCamera ? Colors.green : theme.iconTheme.color,
                      onPressed: () {
                        showCamera = !showCamera;
                        setState(() {});
                      },
                    ),
                  ),

                  //수동 제어
                  Card(
                    elevation: 10,
                    child: IconButton(
                      icon: Icon(const IconData(0xea45, fontFamily: "GamePad"),
                          color:
                              Provider.of<GlobalState>(context, listen: false)
                                      .isManualCtrl
                                      .value
                                  ? Colors.green
                                  : theme.iconTheme.color),
                      onPressed: () {
                        if (Provider.of<GlobalState>(context, listen: false)
                            .isManualCtrl
                            .value) {
                          Provider.of<GlobalState>(context, listen: false)
                              .isManualCtrl
                              .value = false;
                          Provider.of<RosChannel>(context, listen: false)
                              .stopMunalCtrl();
                          setState(() {});
                        } else {
                          Provider.of<GlobalState>(context, listen: false)
                              .isManualCtrl
                              .value = true;
                          Provider.of<RosChannel>(context, listen: false)
                              .startMunalCtrl();
                          setState(() {});
                        }
                      },
                    ),
                  )
                ],
              ))),
          //왼쪽 상단 상태 표시줄
          // Positioned(
          //     right: 5,
          //     top: 10,
          //     child: Card(
          //       color: Colors.white70,
          //       elevation: 10,
          //       child: Container(
          //         child: Column(
          //           children: [
          //             IconButton(
          //                 onPressed: () {}, icon: const Icon(Icons.layers)),
          //             IconButton(
          //                 onPressed: () {}, icon: const Icon(Icons.podcasts)),
          //             IconButton(
          //                 onPressed: () {},
          //                 icon: Icon(Icons.location_on_outlined))
          //           ],
          //         ),
          //       ),
          //     )),
          //오른쪽 메뉴바

          Positioned(
            right: 5,
            top: 30,
            child: FittedBox(
              child: Column(
                children: [
                  IconButton(
                      onPressed: () {
                        if (Provider.of<GlobalState>(context, listen: false)
                                .mode
                                .value ==
                            Mode.robotFixedCenter) {
                          cameraFixedScaleValue_ += 0.3;
                        } else {}
                        setState(() {});
                      },
                      icon: const Icon(Icons.zoom_in)),
                  IconButton(
                      onPressed: () {
                        setState(() {
                          cameraFixedScaleValue_ -= 0.3;
                        });
                      },
                      icon: const Icon(
                        Icons.zoom_out,
                      )),
                  IconButton(
                      onPressed: () {
                        if (Provider.of<GlobalState>(context, listen: false)
                                .mode
                                .value ==
                            Mode.robotFixedCenter) {
                          Provider.of<GlobalState>(context, listen: false)
                              .mode
                              .value = Mode.noraml;
                          cameraFixedScaleValue_ = 1;
                        } else {
                          Provider.of<GlobalState>(context, listen: false)
                              .mode
                              .value = Mode.robotFixedCenter;
                        }
                        if (animationController.isAnimating)
                          return; // 애니메이션이 여러 번 실행되는 것을 방지

                        animationController.reset(); // 애니메이션 컨트롤러 재설정
                        animationController.forward(); // 애니메이션 시작
                        setState(() {});
                      },
                      icon: Icon(Icons.location_searching,
                          color:
                              Provider.of<GlobalState>(context, listen: false)
                                          .mode
                                          .value ==
                                      Mode.robotFixedCenter
                                  ? Colors.green
                                  : theme.iconTheme.color))
                ],
              ),
            ),
          ),
          Visibility(
            child: GamepadWidget(),
          )
        ],
      ),
    );
  }
}
