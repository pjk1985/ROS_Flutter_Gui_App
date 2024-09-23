import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, TextEditingController> newControllers = {};
    for (String key in keys) {
      final dynamic value = prefs.get(key); // 모든 유형의 value
      String stringValue;
      if (value is String) {
        stringValue = value;
      } else if (value is int) {
        stringValue = value.toString();
      } else if (value is double) {
        stringValue = value.toString();
      } else if (value is bool) {
        stringValue = value ? 'true' : 'false';
      } else {
        stringValue = 'Unsupported type';
      }
      newControllers[key] = TextEditingController(text: stringValue);
    }
    setState(() {
      _controllers.addAll(newControllers);
    });
  }

  void _saveSettings(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    // 이는 단지 예시일 뿐이며 실제 사용 시 저장된 유형이 읽기 유형과 일치하는지 확인해야 합니다.
    await prefs.setString(key, value);
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: ListView(
        children: _controllers.entries.map((entry) {
          return ListTile(
            title: TextField(
              controller: entry.value,
              decoration: InputDecoration(labelText: entry.key),
              onChanged: (value) => _saveSettings(entry.key, value),
            ),
          );
        }).toList(),
      ),
    );
  }
}
