import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:blue/blue.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_headset_detector/flutter_headset_detector.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qms2/layout/wrl_app/status/cubit/status_cubit.dart';
import 'package:qms2/layout/wrl_app/status/status_layout.dart';
import 'package:qms2/layout/wrl_app/wifi_layout/scanning_layout.dart';
import 'package:qms2/models/user/user_model.dart';
import 'package:qms2/shared/bloc_observer.dart';
import 'package:qms2/shared/components/constants.dart';
import 'package:qms2/shared/network/end_points.dart';
import 'package:qms2/shared/network/local/database_helper.dart';
import 'package:qms2/shared/network/remote/dio_helper.dart';
import 'package:qms2/shared/styles/colors.dart';
import 'package:stats/stats.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'layout/wrl_app/login/cubit/login_cubit.dart';
import 'layout/wrl_app/login/cubit/login_states.dart';
import 'layout/wrl_app/login/wrl_login_screen.dart';
import 'layout/wrl_app/wifi_layout/cubit/scanning_cubit.dart';
import 'shared/network/local/cache_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = MyBlocObserver();
  DioHelper.init();
  await CacheHelper.init();
  await initializeService();

  token = await CacheHelper.getData(key: 'token');
  isDone = await CacheHelper.getData(key: 'DoneScanning');
  username = await CacheHelper.getData(key: 'username');
  password = await CacheHelper.getData(key: 'password');
  getEncodedSigData = await CacheHelper.getData(key: 'sig');
  getEncodedSigStats = await CacheHelper.getData(key: 'sigStats');

  Widget widget;

  // print(token);

  // print(username);
  // print(password);

  // await back.onStart();

  if (token != null) {
    if (isDone != null) {
      widget = const StatusLayout();
    } else {
      widget = const ScanningLayout();
    }
  } else {
    widget = const HomeQuarantineLoginScreen();
  }
  // Session.shared.username ='aaa';
// Session().getDirPath();


  await Session().writeData(username ?? '', 'username');
  await Session().writeData(password ?? '', 'password');
  await Session().writeData(token ?? '', 'token');
  await Session().writeData(isDone.toString() ?? '', 'done');
  await Session().writeData(getEncodedSigData ?? '', 'sig');
  await Session().writeData(getEncodedSigStats ?? '', 'sigStats');

// Session().readData('username').then((value) {
//   print('$value this is value from main');
// });

  runApp(MyApp(
    startWidget: widget,
  ));
}

List<WifiNetwork> wifiNetwork = [];
List devicesList = [];
String connectedSSID = 'Unknown';
String connectedBSSID = 'Unknown';
List<String> bssids = [];
List<double> levels = [];
// List<String> bssid = [];
List<String> capBssids = [];

// List<double> level = [];
List<double> capLevels = [];

var uniqeBSSIDLevelsMap = {};
List uniqueLevelsList = [];
List uniqueBSSIDSList = [];
List<double> sigMean = [];
double sigMedian = 0.0;
double sigSTD = 0.0;
double sigVar = 0.0;
double sigSkew = 0.0;
double sigKurt = 0.0;
double capMean = 0.0;
double capMedian = 0.0;
double capSTD = 0.0;
double capVar = 0.0;
double capSkew = 0.0;
double capKurt = 0.0;
double myCorrel = 0.0;
bool isInside = false;
bool isPaired = false;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will executed when app is in foreground or background in separated isolate
      onStart: runToRun,

      // auto start service
      autoStart: true,
      isForegroundMode: false,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will executed when app is in foreground in separated isolate
      onForeground: onStartFore,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
}

void onIosBackground() {
  WidgetsFlutterBinding.ensureInitialized();
  // print('FLUTTER BACKGROUND FETCH');
}

runToRun() {
  Session().onStart();
  // print(username);
}

void onStartFore() {
  WidgetsFlutterBinding.ensureInitialized();

  final service = FlutterBackgroundService();
  service.onDataReceived.listen((event) {
    if (event["action"] == "setAsForeground") {
      service.setForegroundMode(true);
      return;
    }

    if (event["action"] == "setAsBackground") {
      service.setForegroundMode(false);
    }

    if (event["action"] == "stopService") {
      service.stopBackgroundService();
    }
  });

  // bring to foreground
  service.setForegroundMode(true);
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (!(await service.isServiceRunning())) timer.cancel();
    service.setNotificationInfo(
      title: "My App Service",
      content: "Updated at ${DateTime.now()}",
    );

    // status using external plugin
    final deviceInfo = DeviceInfoPlugin();
    String device;
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      device = androidInfo.model;
    }

    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      device = iosInfo.model;
    }

    service.sendData(
      {
        "current_date": DateTime.now().toIso8601String(),
        "device": device,
      },
    );
  });
}

class Session {
  final dbHelper = DatabaseHelper.instance;

  // singleton
  static final Session _singleton = Session._internal();

  factory Session() => _singleton;

  Session._internal();

  static Session get shared => _singleton;

  String username;
  String password;
  String done;
  String token;
  int id=0;
  final _headsetDetector = HeadsetDetector();
  BluetoothConnection connection;

  Map<HeadsetType, HeadsetState> _headsetState = {
    HeadsetType.WIRED: HeadsetState.DISCONNECTED,
    HeadsetType.WIRELESS: HeadsetState.DISCONNECTED,
  };

  BluetoothDevice btDevice = const BluetoothDevice(
    address: 'AB:CD:EF:GH:IJ:KL', //'98:D3:61:FD:7D:22'
    name: '',
    isConnected: true,
  );

  Future<String> getLocalPath() async {
    var folder = await getApplicationDocumentsDirectory();
    return folder.path;
  }

  Future<File> getLocalFile(String fileName) async {
    // String path = await getLocalPath();
    return File('/data/user/0/com.example.qms2/$fileName.txt');
  }

  Future<File> writeData(String data, String fileName) async {
    File file = await getLocalFile(fileName);
    return file.writeAsString(data);
  }

  Future<String> readData(String fileName) async {
    try {
      final file = await getLocalFile(fileName);
      String content = await file.readAsString();
      return content;
    } catch (e) {
      return e.toString();
      // print('the error is $e');
    }
  }

  void openBlue(bool onOff) async {
    await Blue.blueOnOff(onOff);
    bool blueOpenState = await Blue.getBlueIsEnabled;
    // print("Bluetooth switch callback:  $blueOpenState");
    blueOpenState = blueOpenState;
  }

  String _mapStateToText(HeadsetState state) {
    switch (state) {
      case HeadsetState.CONNECTED:
        return 'Connected';
      case HeadsetState.DISCONNECTED:
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  }

  Future<void> login() async {
    await DioHelper.postData(
      url: LOGIN,
      data: {
        'username': username,
        'password': password,
      },
    ).then((value) {
      UserModel loginModel = UserModel.fromJson(value.data);
      token = loginModel.data.token;
      id = loginModel.data.id;
      btDevice = const BluetoothDevice(
        address: '75:53:D4:B0:2B:2D',
        //loginModel.data.braceletID, //'98:D3:61:FD:7D:22'
        name: '',
        isConnected: true,
      );
      // print(token);
      // print(loginModel.data.sig??'null');
    }).catchError((error) {
      // print(error.toString());
    });
  }

  Future<void> checkInsideOutside() async {
    await loadWifiList().then(
      (value) {
        wifiNetwork = value;
      },
    ).catchError(
      (error) {
        // print(error);
      },
    );

    for (var device in wifiNetwork) {
      capBssids.add(device.bssid);
      capLevels.add(device.level.toDouble() + 180);
      // }
    }
    // print(capBssids);
    // print(capLevels);

    Map decodedSigData;
    String getEncodedSigData;
    await readData('sig').then((value) {
      getEncodedSigData = value;
    });
    decodedSigData = json.decode(getEncodedSigData);
    List comonAverage = [];
    List<double> comonLevels = [];
    List averageLevels = decodedSigData['averageLevels'];
    for (var element in decodedSigData['uniqueBssids']) {
      comonAverage
          .add(averageLevels[decodedSigData['uniqueBssids'].indexOf(element)]);

      if (capBssids.contains(element)) {
        comonLevels.add(capLevels[capBssids.indexOf(element)]);
      } else {
        // print("not exist");
      }
    }
    if (comonLevels.isNotEmpty && comonLevels.length > 3) {
      final st = Stats.fromData(comonLevels);
      List<double> statsList = [];
      capMean = comonLevels.average;
      capMedian = st.median;
      capSTD = std(comonLevels);
      capVar = pow(capSTD, 2);
      capKurt = kurtosis(comonLevels);
      capSkew = skewness(comonLevels);

      statsList.add(comonLevels.average);
      statsList.add(st.median);
      statsList.add(std(comonLevels));
      statsList.add(pow(std(comonLevels), 2));
      statsList.add(kurtosis(comonLevels));
      statsList.add(skewness(comonLevels));

      Map decodedSigStats;
      String getEncodedSigStats;
      await readData('sigStats').then((value) {
        getEncodedSigStats = value;
      });
      decodedSigStats = json.decode(getEncodedSigStats);
      List<double> decoded = [];
      for (var element in decodedSigStats.values) {
        decoded.add(element);
      }
      var fact = comonAverage.length / averageLevels.length;

      myCorrel = correl(decoded, statsList) + fact;
      // print('correlation value    $myCorrel');

      myCorrel >= 0.7 ? isInside = true : isInside = false;
    } else {
      // showToast(text: 'Outside', state: ToastStates.ERROR);
      isInside = false;
    }

    capBssids = [];
    capLevels = [];
    comonLevels = [];
    comonAverage = [];
    // /print(isInside);

    // print(token);
    DioHelper.putData(
      url: UpdateViolationStatus,
      token: token,
      data: {
        "user_id": id,
        "isInside": isInside,
        "isPaired": isPaired,
      },
    ).then((value) {
      // print(value.data);
      // print('is inside $isInside');
      // print('is paired $isPaired');
    }).catchError((error) {});
  }

  Future<void> checkIsPairedOnOff() async {

    bool isConnected = await Blue.getBlueIsEnabled;
    if (!isConnected) {
      openBlue(true);
    }
    _headsetDetector.getCurrentState.then((value) => _headsetState = value);
    if (_mapStateToText(_headsetState[HeadsetType.WIRELESS]) == 'Connected') {
      isPaired = true;
    } else {
      isPaired = false;
    }
    // print('$isPaired is paired');
  }

  // Future<void> checkIsBonded() async {
  //   if (await FlutterBluetoothSerial.instance
  //           .getBondStateForAddress(btDevice.address) !=
  //       BluetoothBondState.bonded) {
  //     await FlutterBluetoothSerial.instance
  //         .bondDeviceAtAddress(btDevice.address,
  //             passkeyConfirm: true, pin: '1234')
  //         .then((_connection) {
  //       // print('Connected to the device');
  //       connection = _connection as BluetoothConnection;
  //     }).catchError((error) {
  //       // print('Cannot connect, exception occured');
  //       // print(error);
  //     });
  //   }
  // }

  void insideOutsideRing() {
    !isInside
        ? FlutterRingtonePlayer.playRingtone(
            looping: true,
            volume: 10.0,
            asAlarm: true,
          )
        // : !isPaired
        //     ? FlutterRingtonePlayer.playRingtone(
        //         looping: true,
        //         volume: 10.0,
        //         asAlarm: true,
        //       )
            : FlutterRingtonePlayer.stop();
  }

  Future<void> everySecondFunc() async {
    checkIsPairedOnOff();
    insideOutsideRing();
  }

  void onStart({user, pass}) {
    WidgetsFlutterBinding.ensureInitialized();
    final service = FlutterBackgroundService();
    service.onDataReceived.listen((event) {
      if (event["action"] == "setAsForeground") {
        service.setForegroundMode(true);

        return;
      }
      if (event["action"] == "setAsBackground") {
        service.setForegroundMode(false);
      }
      if (event["action"] == "stopService") {
        service.stopBackgroundService();
      }
    });

    // bring to foreground
    service.setForegroundMode(true);
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!(await service.isServiceRunning())) timer.cancel();
      service.setNotificationInfo(
        title: "QMS App Running",
        content: "Updated at ${DateTime.now()}",
      );
      final deviceInfo = DeviceInfoPlugin();
      String device;
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        device = androidInfo.model;
      }

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        device = iosInfo.model;
      }

      service.sendData(
        {
          "current_date": DateTime.now().toIso8601String(),
          "device": device,
        },
      );

      await Session().readData('username').then((value) {
        username = value;
        // print(username);
      });
      await Session().readData('password').then((value) {
        password = value;
        // print(password);
      });
      await Session().readData('done').then((value) {
        done = value;
        // print(done);
      });
      if (done == 'true') {
        await DioHelper.init();
        await login();
      }
    }
    );
      Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (done == 'true') {
        everySecondFunc();
        await checkInsideOutside();

      }
      });
      // Timer.periodic(const Duration(minutes: 1), (timer) async {
      //   checkIsBonded();
      // });
  }
}

class MyApp extends StatefulWidget {
  final bool isDark;
  final Widget startWidget;

  const MyApp({Key key,
    this.isDark,
    this.startWidget,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (BuildContext context) => HomeQuarantineLoginCubit(),
        ),
        BlocProvider(
          create: (BuildContext context) => ScanningCubit(),
        ),
        BlocProvider(create: (context) => StatusCubit() //..createDatabase(),
            ),
      ],
      child: BlocConsumer<HomeQuarantineLoginCubit, HomeQuarantineLoginStates>(
        listener: (context, state) {},
        builder: (context, state) {
          return MaterialApp(
            builder: BotToastInit(),
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: defaultColor,
              appBarTheme: AppBarTheme(
                titleSpacing: 20.0,
                // ignore: deprecated_member_use
                backwardsCompatibility: false,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.indigo[900],
                  statusBarIconBrightness: Brightness.light,
                ),
                elevation: 0.0,
                titleTextStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // darkTheme: darkTheme,
            // themeMode:
            //     AppCubit.get(context).isDark ? ThemeMode.dark : ThemeMode.light,
            home: widget.startWidget,
          );
        },
      ),
    );
  }
}

//
// Future<void> ccheck() async {
//   await loadWifiList().then(
//     (value) {
//       wifiNetwork = value;
//       // emit(TestChangeWifiState());
//     },
//   ).catchError(
//     (error) {
//       print(error);
//     },
//   );
//
//   for (var device in wifiNetwork) {
//     // print(device.ssid);
//     // print(device.bssid);
//     // print(device.level.toDouble());
//     capBssids.add(device.bssid);
//     capLevels.add(device.level.toDouble() + 180);
//     // }
//   }
//   print(capBssids);
//   print(capLevels);
//
//   String getEncodedSigData = CacheHelper.getData(key: 'sig');
//   Map decodedSigData = json.decode(getEncodedSigData);
//   // print('decoded sig data     $decodedSigData');
//   /*
//     * {bssids: [22:53:49:1e:b1:46, 30:74:96:08:35:64, ec:3e:b3:23:d7:02, 90:9a:4a:fd:75:1e, 30:c5:0f:f9:37:40, 84:d8:1b:2d:0b:80, 22:53:49:1e:b1:46, 30:74:96:08:35:64, ec:3e:b3:23:d7:02, 90:9a:4a:fd:75:1e, 30:c5:0f:f9:37:40, 84:d8:1b:2d:0b:80, 22:53:49:1e:b1:46, 30:74:96:08:35:64, ec:3e:b3:23:d7:02, 90:9a:4a:fd:75:1e, 30:c5:0f:f9:37:40, 84:d8:1b:2d:0b:80],
//     *  levels: [109.0, 77.0, 75.0, 72.0, 66.0, 65.0, 109.0, 77.0, 75.0, 72.0, 66.0, 65.0, 109.0, 77.0, 75.0, 72.0, 66.0, 65.0],
//     *  uniqueBssidsLevels: [[109.0, 109.0, 109.0], [77.0, 77.0, 77.0], [75.0, 75.0, 75.0], [72.0, 72.0, 72.0], [66.0, 66.0, 66.0], [65.0, 65.0, 65.0]],
//     *  averageLevels: [109.0, 77.0, 75.0, 72.0, 66.0, 65.0],
//     *  connectedCellId: null,
//     *  connectedSsid: null,
//     *  uniqueBssids: [22:53:49:1e:b1:46, 30:74:96:08:35:64, ec:3e:b3:23:d7:02, 90:9a:4a:fd:75:1e, 30:c5:0f:f9:37:40, 84:d8:1b:2d:0b:80]}*/
//   // Map comonData = {};
//   List comonAverage = [];
//   List<double> comonLevels = [];
//   List averageLevels = decodedSigData['averageLevels'];
// // print('fdddddddddddddddddddddd        ${uniqueBssids}');
//   for (var element in decodedSigData['uniqueBssids']) {
//     comonAverage
//         .add(averageLevels[decodedSigData['uniqueBssids'].indexOf(element)]);
//     // print(capLevels[capBssids.indexOf(element)]);
//     print(decodedSigData['uniqueBssids'].indexOf(element));
//     if (capBssids.contains(element)) {
//       comonLevels.add(capLevels[capBssids.indexOf(element)]);
//     } else {
//       print("not exist");
//     }
//   }
//   print('common levels length : ${comonLevels.length}');
//   // for(var element in capBssids){
//   //
//   //   if(decodedSigData['uniqueBssids'].contains(element)){
//   //     commonBssids.add(element);
//   //     comonAverage.add(averageLevels[uniqueBssids.indexOf(element)]);
//   //     comonLevels.add(capLevels[capBssids.indexOf(element)]);
//   //   }
//   // }
//
//   // print('My List : ' + comonLevels.toString());
//   // print('My cap levels : ' + capLevels.toString());
//   // print('My cap bssid : ' + capBssids.toString());
//   // print('My comon levels : ' + comonLevels.toString());
//   // print('My comon average : ' + comonAverage.toString());
//
//   if (comonLevels.isNotEmpty && comonLevels.length > 3) {
//     final st = Stats.fromData(comonLevels);
//     List<double> statsList = [];
//     capMean = comonLevels.average;
//     capMedian = st.median;
//     capSTD = STD(comonLevels);
//     capVar = pow(capSTD, 2);
//     capKurt = kurtosis(comonLevels);
//     capSkew = skewness(comonLevels);
//     print(' st ccccccccccccccccccccccccccccccccc${st.count}');
//
//     statsList.add(comonLevels.average);
//     print(comonLevels.average);
//     statsList.add(st.median);
//     print(st.median);
//     statsList.add(STD(comonLevels));
//     print(STD(comonLevels));
//     statsList.add(pow(STD(comonLevels), 2));
//     print(pow(STD(comonLevels), 2));
//     statsList.add(kurtosis(comonLevels));
//     print(kurtosis(comonLevels));
//     statsList.add(skewness(comonLevels));
//     print(skewness(comonLevels));
//
//     // capStates.mean =capMean;
//     // capStates.median =capMedian;
//     // capStates.standardDeviation =capSTD;
//     // capStates.variance =capVar;
//     // capStates.skewness =capSkew;
//     // capStates.kurtosis =capKurt;
//
//     String getEncodedSigStats = CacheHelper.getData(key: 'sigStats');
//     Map decodedSigStats = json.decode(getEncodedSigStats);
//     // print(
//     //     'decoded sig states  ' + decodedSigStats.values.toList().toString());
//
//     List<double> decoded = [];
//     for (var element in decodedSigStats.values) {
//       decoded.add(element);
//     }
//     var fact = comonAverage.length / averageLevels.length;
//     // print(capStates.toJson());
//     print('states List   $statsList');
//     // print(sigStates.toJson());
//     myCorrel = Correl(decoded, statsList) + fact;
//     print('correlation value    $myCorrel');
//
//     // showToast(text: myCorrel.toString(), state: ToastStates.SUCCESS);
//     // print(div());
//     myCorrel >= 0.7 ? isInside = true : isInside = false;
//   } else {
//     // showToast(text: 'Outside', state: ToastStates.ERROR);
//     isInside = false;
//     // emit(TestIsInsideChangeState());
//   }
//   // emit(TestCheckRepeatedState());
//   capBssids = [];
//   capLevels = [];
//   comonLevels = [];
//   comonAverage = [];
//   print('comonLevels size : ${comonLevels.length}');
// }
//
// Future<List<WifiNetwork>> loadWifiList() async {
//   List<WifiNetwork> htResultNetwork;
//   try {
//     htResultNetwork = await WiFiForIoTPlugin.loadWifiList();
//   } on PlatformException {
//     htResultNetwork = <WifiNetwork>[];
//   }
//   return htResultNetwork;
// }
//
// //Function to get std
// double STD(List<double> arr) {
//   double sum1 = 0;
//   double std = 0;
//   final st = Stats.fromData(arr);
//   for (int i = 0; i < st.count; i++) {
//     sum1 += pow((arr[i] - st.average).abs(), 2);
//   }
//   std = sqrt((sum1 / (st.count - 1)));
//   return std;
// }
//
// // Function to calculate skewness.
// double skewness(List<double> arr) {
//   // Find skewness using above formula
//   final st = Stats.fromData(arr);
//   double sum = 0;
//   double sum1 = 0;
//   double sum2 = 0;
//   double std = 0;
//   double fact = 0;
//
//   fact = (st.count / ((st.count - 1) * (st.count - 2)));
//
//   for (int i = 0; i < st.count; i++) {
//     sum1 += pow((arr[i] - st.average).abs(), 2);
//   }
//   std = sqrt((sum1 / (st.count - 1)));
//
//   for (int i = 0; i < arr.length; i++) {
//     sum += pow((arr[i] - st.average).abs(), 3);
//   }
//   sum2 = pow(std, 3);
//
//   return fact * (sum / sum2);
// }
//
// // Function to calculate kurtosis.
// double kurtosis(List<double> arr) {
//   // Find skewness using above formula
//   final st = Stats.fromData(arr);
//   double sum = 0;
//   double sum2 = 0;
//   double fact = 0;
//   double fact2 = 0;
//   double sum3 = 0;
//   double std = 0;
//
//   for (int i = 0; i < st.count; i++) {
//     sum3 += pow((arr[i] - st.average).abs(), 2);
//   }
//   std = sqrt((sum3 / (st.count - 1)));
//
//   fact = ((st.count * (st.count + 1)) /
//       ((st.count - 1) * (st.count - 2) * (st.count - 3)));
//   fact2 =
//       ((3 * pow((st.count - 1).abs(), 2)) / ((st.count - 2) * (st.count - 3)));
//
//   for (int i = 0; i < st.count; i++) {
//     sum += pow((arr[i] - st.average).abs(), 4);
//   }
//   sum2 = sum / pow((std).abs(), 4);
//
//   return (fact * (sum2)) - fact2;
// }
//
// //Function to calculate covariance
// double Covar(List<double> arr1, List<double> arr2) {
//   final st1 = Stats.fromData(arr1);
//   final st2 = Stats.fromData(arr2);
//   List xListSubAvg = [];
//   List yListSubAvg = [];
//   List mulList = [];
//   double mulListSum = 0;
//
//   for (var element in arr1) {
//     xListSubAvg.add(element - st1.average);
//   }
//   for (var element in arr2) {
//     yListSubAvg.add(element - st2.average);
//   }
//   for (var element in xListSubAvg) {
//     mulList.add(element * yListSubAvg[xListSubAvg.indexOf(element)]);
//   }
//   mulListSum = mulList.reduce((value, element) => value + element);
//   return (mulListSum / (arr1.length - 1));
// }
//
// //Function to calculate correlation
// double Correl(List<double> arr1, List<double> arr2) {
//   double mCov = Covar(arr1, arr2);
//   double stdA = STD(arr1);
//   double stdB = STD(arr2);
//   return mCov / (stdA * stdB);
// }
//
// Future<void> callback() async {
//   developer.log('Alarm fired!');
//   WidgetsFlutterBinding.ensureInitialized();
//   await CacheHelper.init();
//   CacheHelper.getData(key: 'sig');
//   // TestCubit().scanWifi();
//   // await loadWifiList().then(
//   //   (value) {
//   //     wifiNetwork = value;
//   //     // emit(TestChangeWifiState());
//   //   },
//   // ).catchError(
//   //   (error) {
//   //     print(error);
//   //   },
//   // );
//   //
//   // for (var device in wifiNetwork) {
//   //   // print(device.ssid);
//   //   // print(device.bssid);
//   //   // print(device.level.toDouble());
//   //   capBssids.add(device.bssid);
//   //   capLevels.add(device.level.toDouble() + 180);
//   //   // }
//   // }
//   // print(capBssids);
//   // print(capLevels);
// // Get the previous cached count and increment it.
// // showToast(text: 'text', state: ToastStates.SUCCESS);
// // This will be null if we're running in the background.
// // uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
// // uiSendPort?.send(null);
// }
Future<List<WifiNetwork>> loadWifiList() async {
  List<WifiNetwork> htResultNetwork;
  try {
    htResultNetwork = await WiFiForIoTPlugin.loadWifiList();
  } on PlatformException {
    htResultNetwork = <WifiNetwork>[];
  }
  return htResultNetwork;
}

//Function to get std
double std(List<double> arr) {
  double sum1 = 0;
  double std = 0;
  final st = Stats.fromData(arr);
  for (int i = 0; i < st.count; i++) {
    sum1 += pow((arr[i] - st.average).abs(), 2);
  }
  std = sqrt((sum1 / (st.count - 1)));
  return std;
}

// Function to calculate skewness.
double skewness(List<double> arr) {
  // Find skewness using above formula
  final st = Stats.fromData(arr);
  double sum = 0;
  double sum1 = 0;
  double sum2 = 0;
  double std = 0;
  double fact = 0;

  fact = (st.count / ((st.count - 1) * (st.count - 2)));

  for (int i = 0; i < st.count; i++) {
    sum1 += pow((arr[i] - st.average).abs(), 2);
  }
  std = sqrt((sum1 / (st.count - 1)));

  for (int i = 0; i < arr.length; i++) {
    sum += pow((arr[i] - st.average).abs(), 3);
  }
  sum2 = pow(std, 3);

  return fact * (sum / sum2);
}

// Function to calculate kurtosis.
double kurtosis(List<double> arr) {
  // Find skewness using above formula
  final st = Stats.fromData(arr);
  double sum = 0;
  double sum2 = 0;
  double fact = 0;
  double fact2 = 0;
  double sum3 = 0;
  double std = 0;

  for (int i = 0; i < st.count; i++) {
    sum3 += pow((arr[i] - st.average).abs(), 2);
  }
  std = sqrt((sum3 / (st.count - 1)));

  fact = ((st.count * (st.count + 1)) /
      ((st.count - 1) * (st.count - 2) * (st.count - 3)));
  fact2 =
      ((3 * pow((st.count - 1).abs(), 2)) / ((st.count - 2) * (st.count - 3)));

  for (int i = 0; i < st.count; i++) {
    sum += pow((arr[i] - st.average).abs(), 4);
  }
  sum2 = sum / pow((std).abs(), 4);

  return (fact * (sum2)) - fact2;
}

//Function to calculate covariance
double covar(List<double> arr1, List<double> arr2) {
  final st1 = Stats.fromData(arr1);
  final st2 = Stats.fromData(arr2);
  List xListSubAvg = [];
  List yListSubAvg = [];
  List mulList = [];
  double mulListSum = 0;

  for (var element in arr1) {
    xListSubAvg.add(element - st1.average);
  }
  for (var element in arr2) {
    yListSubAvg.add(element - st2.average);
  }
  for (var element in xListSubAvg) {
    mulList.add(element * yListSubAvg[xListSubAvg.indexOf(element)]);
  }
  mulListSum = mulList.reduce((value, element) => value + element);
  return (mulListSum / (arr1.length - 1));
}

//Function to calculate correlation
double correl(List<double> arr1, List<double> arr2) {
  double mCov = covar(arr1, arr2);
  double stdA = std(arr1);
  double stdB = std(arr2);
  return mCov / (stdA * stdB);
}
