import 'package:easy_loading_button/easy_loading_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ros_flutter_gui_app/provider/ros_channel.dart';
import 'package:ros_flutter_gui_app/global/setting.dart';
import 'package:ros_flutter_gui_app/provider/them_provider.dart';
import 'package:toast/toast.dart';

class RobotConnectionPage extends StatefulWidget {
  @override
  _RobotConnectionPageState createState() => _RobotConnectionPageState();
}

class _RobotConnectionPageState extends State<RobotConnectionPage> {
  TextEditingController _ipController =
      TextEditingController(text: '127.0.0.1');
  TextEditingController _portController = TextEditingController(text: '9090');

  @override
  Widget build(BuildContext context) {
    ToastContext().init(context);
    return Scaffold(
      body: FutureBuilder<bool>(
        future: initGlobalSetting(),
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('오류：${snapshot.error}');
          } else {
            _ipController.text = globalSetting.robotIp;
            _portController.text = globalSetting.robotPort;
            return Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _ipController,
                    decoration: InputDecoration(labelText: 'Robot IP'),
                  ),
                  SizedBox(height: 16.0),
                  TextField(
                    controller: _portController,
                    decoration: InputDecoration(labelText: 'Robot Port'),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16.0),
                  EasyButton(
                      type: EasyButtonType.text,
                      idleStateWidget: const Text(
                        '연결',
                        style: TextStyle(
                          color: Colors.blue,
                        ),
                      ),
                      loadingStateWidget: const CircularProgressIndicator(
                        strokeWidth: 3.0,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.green,
                        ),
                      ),
                      useWidthAnimation: true,
                      useEqualLoadingStateWidgetDimension: true,
                      onPressed: () async {
                        // 로봇 연결 처리
                        String ip = _ipController.text;
                        int port = int.tryParse(_portController.text) ?? 9090;
                        // 여기서 로봇에 연결하는 작업을 위해 ip 및 port 변수를 사용
                        print('Connecting to robot at $ip:$port');
                        var provider =
                            Provider.of<RosChannel>(context, listen: false);
                        globalSetting.setRobotIp(ip);
                        globalSetting.setRobotPort(_portController.text);
                        provider.connect("ws://$ip:$port").then((success) {
                          if (success) {
                            // 연결이 성공하면 다음 페이지로 이동할 수 있습니다.
                            Navigator.pushNamed(context, "/map");
                          } else {
                            print('연결 실패');
                            Toast.show("connect to ros failed!",
                                duration: Toast.lengthShort,
                                gravity: Toast.bottom);
                          }
                        });
                      }),
                  TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, "/setting");
                      },
                      child: const Text("설정")),
                  Spacer(),
                  Row(
                    children: [
                      Spacer(),
                      ToggleButtons(
                        isSelected: [
                          Provider.of<ThemeProvider>(context).themeMode ==
                              ThemeMode.system,
                          Provider.of<ThemeProvider>(context).themeMode ==
                              ThemeMode.light,
                          Provider.of<ThemeProvider>(context).themeMode ==
                              ThemeMode.dark,
                        ],
                        onPressed: (int index) {
                          Provider.of<ThemeProvider>(context, listen: false)
                              .updateThemeMode(index);
                        },
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('자동'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('밝게'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('어둡게'),
                          ),
                        ],
                      )
                    ],
                  )
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
