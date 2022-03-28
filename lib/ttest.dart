import 'package:flutter/material.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({Key key}) : super(key: key);

  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  // static const platform = MethodChannel('samples.flutter.dev/battery');
  // void getBatteryLevel() {
  //   String batteryLevel = 'Unknown battery level.';
  //   platform.invokeMethod('getBatteryLevel').then((value) {
  //     setState(() {
  //       batteryLevel = 'Battery level at $value';
  //       print(batteryLevel);
  //     });
  //   }).catchError((error) {
  //     setState(() {
  //       batteryLevel = 'Failed to get battery level: $error';
  //       print(batteryLevel);
  //     });
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              child: const Text('stop'),
              onPressed: () {
                // FlutterRingtonePlayer.stop();
              },
            ),
            ElevatedButton(
              onPressed: () {
                // FlutterRingtonePlayer.playRingtone(
                //   looping: true,
                //   volume: 1.0,
                //   asAlarm: true,
                // );
                // getBatteryLevel();
                // print(batteryLevel);
              },
              child: const Text('play'),
            ),
          ],
        ),
      ),
    );
  }
}
