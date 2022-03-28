import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:blue/blue.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_headset_detector/flutter_headset_detector.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stats/stats.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../../../../models/user/user_model.dart';
import '../../../../shared/network/end_points.dart';
import '../../../../shared/network/local/cache_helper.dart';
import '../../../../shared/network/remote/dio_helper.dart';

part 'status_states.dart';

class StatusCubit extends Cubit<StatusStates> {
  StatusCubit() : super(TestInitial());

  static StatusCubit get(context) => BlocProvider.of(context);

  ////////////////////////////////////////////////////////////////////////////////
  //some view variables
  var isInside = false;
  var isPaired = false;
  var remainingDays = 0;
  var totalDays = 0;
  final String btAddress = '75:53:D4:B0:2B:2D';
  UserModel loginModel;

  // bool isOutside = false;
  double myCorrel = 0.0;

  // ReceivePort _receivePort;

  //////////////////////////////////////////////////////////////////////////////
//wifi objects and variables
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

  bool done = false;

////////////////////////////////////////////////////////////////////////////////
  // Capture original =Capture();
  // Capture combinedSignature = Capture();
  // Capture localCurrentCapture = Capture();
  //objects of Capture
  Capture mSignature = Capture();
  MyStates sigStates = MyStates();

////////////////////////////////////////////////////////////////////////////////
  FlutterBluetoothSerial bluetooth = FlutterBluetoothSerial.instance;
  BluetoothState bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection connection;
  BluetoothConnection myConnection;
  BluetoothDevice btDevice = const BluetoothDevice(
    address: 'AB:CD:EF:GH:IJ:KL', //'98:D3:61:FD:7D:22'
    name: '',
    isConnected: true,
  );
  Map<HeadsetType, HeadsetState> _headsetState = {
    HeadsetType.WIRED: HeadsetState.DISCONNECTED,
    HeadsetType.WIRELESS: HeadsetState.DISCONNECTED,
  };
  var bt = FlutterBluetoothSerial.instance;
  final _headsetDetector = HeadsetDetector();

////////////////////////////////////////////////////////////////////////////////

  //wifi scanning funcs

  Future<List<WifiNetwork>> loadWifiList() async {
    List<WifiNetwork> htResultNetwork;
    try {
      htResultNetwork = await WiFiForIoTPlugin.loadWifiList();
    } on PlatformException {
      htResultNetwork = <WifiNetwork>[];
    }
    return htResultNetwork;
  }

  void scanWifi() async {
    List<String> bssids = [];
    List<double> levels = [];
    await loadWifiList().then(
      (value) {
        emit(TestChangeWifiState());
        wifiNetwork = value;
        // print(capturesCount);
      },
    ).catchError(
      (error) {
        // print(error);
      },
    );

    for (var device in wifiNetwork) {
      // print(device.ssid);
      // print(device.bssid);
      // print(device.level.toDouble());
      bssids.add(device.bssid);
      levels.add(device.level.toDouble() + 150);
      // }
    }
    // print(bssids);
    // print(levels);
    // print(bssids);
    // print(levels);
    // print(levels);
    // print('wifi scanned');
    bssids = [];
    bssids = [];
  }

  Future<List<APClient>> getClientList(
      bool onlyReachables, int reachableTimeout) async {
    List<APClient> htResultClient;
    try {
      htResultClient = await WiFiForIoTPlugin.getClientList(
          onlyReachables, reachableTimeout);
    } on PlatformException {
      htResultClient = <APClient>[];
    }

    return htResultClient;
  }

  //////////////////////////////////////////////////////////////////////////////
//////////////BT\
  btFunction() async {
    bool isConnected = await Blue.getBlueIsEnabled;

    if (!isConnected) {
      openBlue(true);
    }
    _headsetDetector.setListener((_val) {
      switch (_val) {
        case HeadsetChangedEvent.WIRED_CONNECTED:
          _headsetState[HeadsetType.WIRED] = HeadsetState.CONNECTED;
          break;
        case HeadsetChangedEvent.WIRED_DISCONNECTED:
          _headsetState[HeadsetType.WIRED] = HeadsetState.DISCONNECTED;
          break;
        case HeadsetChangedEvent.WIRELESS_CONNECTED:
          _headsetState[HeadsetType.WIRELESS] = HeadsetState.CONNECTED;
          break;
        case HeadsetChangedEvent.WIRELESS_DISCONNECTED:
          _headsetState[HeadsetType.WIRELESS] = HeadsetState.DISCONNECTED;
          break;
      }
    });
    // Timer.periodic(const Duration(seconds: 8), (Timer t) async {
    //   checkRepeated();
    // });
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      !isInside
          ? FlutterRingtonePlayer.playRingtone(
              looping: true,
              volume: 10.0,
              asAlarm: true,
            )
          //     : !isPaired
          //     ? FlutterRingtonePlayer.playRingtone(
          //   looping: true,
          //   volume: 10.0,
          //   asAlarm: true,
          // )
          : FlutterRingtonePlayer.stop();
      readData('log').then((value) async {
        String v = value;
        writeData(
          '$v${DateTime.now()} ${isInside ? ', isInside' : ', isOutside'} from App \n',
          'log',
        );
      });
      bool isConnected = await Blue.getBlueIsEnabled;
      if (!isConnected) {
        openBlue(true);
      }
      _headsetDetector.getCurrentState.then((value) => _headsetState = value);
      if (mapStateToText(_headsetState[HeadsetType.WIRELESS]) == 'Connected') {
        isPaired = true;
        // print(' is inside true');
      } else {
        isPaired = false;
        // print(' is inside false');
      }
      // print(+
      //     'this is headset state');
    });

    Timer.periodic(const Duration(seconds: 1), (timer) async {
      pair();
    });
  }

  Future<void> pair() async {
    if (await bt.getBondStateForAddress(btDevice.address) !=
        BluetoothBondState.bonded) {
      await bt
          .bondDeviceAtAddress(btDevice.address,
              passkeyConfirm: true, pin: '1234')
          .then((_connection) {
        // print('Connected to the device');
        connection = _connection as BluetoothConnection;
      }).catchError((error) {
        // print('Cannot connect, exception occured');
        // print(error);
      });
    }
    await connect();
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      bluetoothState = state;
    });
  }

//bluetooth funcs
  void openBlue(bool onOff) async {
    await Blue.blueOnOff(onOff);
    bool blueOpenState = await Blue.getBlueIsEnabled;
    // print("Bluetooth switch callback:  $blueOpenState");
    blueOpenState = blueOpenState;
  }

  String mapStateToText(HeadsetState state) {
    switch (state) {
      case HeadsetState.CONNECTED:
        return 'Connected';
      case HeadsetState.DISCONNECTED:
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  }

  Future<void> connect() async {
    if (mapStateToText(_headsetState[HeadsetType.WIRELESS]) == 'Disconnected') {
      await bt.getBondStateForAddress(btDevice.address).then((value) {
        if (value == BluetoothBondState.bonded) {
          BluetoothConnection.toAddress(btDevice.address).then((_connection) {
            // print('Connected to the device');
            connection = _connection;
          }).catchError((error) {
            if (error ==
                'getBluetoothService() called with no BluetoothManagerCallback') {
              // print('error');
            }
            // print('Cannot connect, exception occured');
          });
        }
      });
    }
  }

  /////////////////////////////////////////////////////////////////////////////
  ///new algorithm
  String getUnique() {
    for (var element in bssids) {
      if (!uniqeBSSIDLevelsMap.containsKey(element)) {
        uniqeBSSIDLevelsMap[element] = [];
      } else {
        uniqeBSSIDLevelsMap[element] = getLevels(element);
      }
    }
    // print(map);

    uniqueLevelsList = uniqeBSSIDLevelsMap.values.toList();
    uniqueBSSIDSList = uniqeBSSIDLevelsMap.keys.toList();

    // map.keys.forEach((mapElement) {mmap.keys.forEach((mmapElement) {mmapElement=mapElement; });});

    // get list of averages of unique list
    sigMean = [];
    for (List<double> element in uniqueLevelsList) {
      sigMean.add(element.average);
    }
    // print(sigMean);

    //get states for list of averages of unique list
    final st = Stats.fromData(sigMean);

    sigMedian = st.median;
    sigSTD = std(sigMean);
    sigVar = pow(sigSTD, 2);
    sigKurt = kurtosis(sigMean);
    sigSkew = skewness(sigMean);

    // //put data to signature
    mSignature.bssids = bssids;
    mSignature.levels = levels;
    mSignature.averageLevels = sigMean;
    mSignature.uniqueBssidsLevels = uniqueLevelsList;
    mSignature.uniqueBssids = uniqueBSSIDSList;
    //
    // //put states data to sig states
    sigStates.mean = sigMean.average;
    sigStates.median = sigMedian;
    sigStates.standardDeviation = sigSTD;
    sigStates.variance = sigVar;
    sigStates.skewness = sigSkew;
    sigStates.kurtosis = sigKurt;
    //
    // print(uniqeBSSIDLevelsMap);

    return uniqeBSSIDLevelsMap.toString();
  }

  List<double> getLevels(String bssid) {
    List<double> _levels = [];
    for (var i = 0; i < bssids.length; i++) {
      if (bssids[i] == bssid) {
        _levels.add(levels[i]);
      }
    }
    return _levels;
  }

  void clear() {
    bssids.clear();
    levels.clear();
  }

  Future<void> checkRepeated({bool back}) async {
    await loadWifiList().then(
      (value) {
        wifiNetwork = value;
        emit(TestChangeWifiState());
      },
    ).catchError(
      (error) {
        // print(error);
      },
    );

    for (var device in wifiNetwork) {
      capBssids.add(device.bssid);
      capLevels.add(device.level.toDouble() + 180);
    }
    // print(capBssids);
    // print(capLevels);

    String getEncodedSigData = CacheHelper.getData(key: 'sig');
    Map decodedSigData = json.decode(getEncodedSigData);

    List comonAverage = [];
    List<double> comonLevels = [];
    List averageLevels = decodedSigData['averageLevels'];
    for (var element in decodedSigData['uniqueBssids']) {
      comonAverage
          .add(averageLevels[decodedSigData['uniqueBssids'].indexOf(element)]);
      // print(decodedSigData['uniqueBssids'].indexOf(element));
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
      // print(' st ccccccccccccccccccccccccccccccccc${st.count}');

      statsList.add(comonLevels.average);
      statsList.add(st.median);
      statsList.add(std(comonLevels));
      statsList.add(pow(std(comonLevels), 2));
      statsList.add(kurtosis(comonLevels));
      statsList.add(skewness(comonLevels));

      String getEncodedSigStats = CacheHelper.getData(key: 'sigStats');
      Map decodedSigStats = json.decode(getEncodedSigStats);

      List<double> decoded = [];
      for (var element in decodedSigStats.values) {
        decoded.add(element);
      }
      var fact = comonAverage.length / averageLevels.length;
      // print('states List   $statsList');
      myCorrel = correl(decoded, statsList) + fact;
      myCorrel >= 0.7 ? isInside = true : isInside = false;
    } else {
      // showToast(text: 'Outside', state: ToastStates.ERROR);
      isInside = false;
    }
    emit(TestCheckRepeatedState());
    capBssids = [];
    capLevels = [];
    comonLevels = [];
    comonAverage = [];
    // print('comonLevels size : ${comonLevels.length}');
  }

  void saveData() {
    String encodedSigData = json.encode(mSignature.toJson());
    CacheHelper.saveData(key: 'sig', value: encodedSigData);
    // print('endcoded sig data  ' + encodedSigData);

    String encodedSigStats = json.encode(sigStates.toJson());
    CacheHelper.saveData(key: 'sigStats', value: encodedSigStats);

    // String getEncodedSigData = CacheHelper.getData(key: 'sig');
    // Map decodedSigData = json.decode(getEncodedSigData);
    // print('decoded sig data  ' + decodedSigData.toString());

    // String getEncodedSigStats = CacheHelper.getData(key: 'sigStats');
    // Map decodedSigStats = json.decode(getEncodedSigStats);
    // print('decoded sig states  ' + decodedSigStats.toString());
  }

  getRemainingDays() {
    userLogin(CacheHelper.getData(key: 'username'),
        CacheHelper.getData(key: 'password'));
    emit(GetRemainingDaysState());
    // return remainingDays;
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
    fact2 = ((3 * pow((st.count - 1).abs(), 2)) /
        ((st.count - 2) * (st.count - 3)));

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

  Future<dynamic> doUpdate(context) async {
    DioHelper.putData(
            url: UpdateViolationStatus,
            data: {
              'user_id': 1,
              'isInside': true,
              'isPaired': false,
            },
            token: loginModel.data.token)
        .then((value) {
      if (value != null) {
        // print(value.data);
      }
      // print();
    }).catchError(
      (error) {
        // print(error.toString());
      },
    );
  }

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// new algorithm
  void userPut({
    @required String token,
    @required int id,
    @required bool isInside,
    @required bool isPaired,
  }) {
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

  void userLogin(user, pass) {
    DioHelper.postData(
      url: LOGIN,
      data: {
        'username': user,
        'password': pass,
      },
    ).then((value) {
      // print(value.data);
      loginModel = UserModel.fromJson(value.data);
      remainingDays = loginModel.data.remainingDays;
      totalDays = loginModel.data.totalDate;
      btDevice = const BluetoothDevice(
        address: '75:53:D4:B0:2B:2D',
        //loginModel.data.braceletID, //'98:D3:61:FD:7D:22'
        name: '',
      );
      // print('${btDevice.isConnected} is device addresss');
      emit(LoginSuccessState());
    }).catchError((error) {
      // print(error.toString());
      emit(LoginErrorState(error.toString()));
    });
  }

  Future<String> getLocalPath() async {
    var folder = await getApplicationDocumentsDirectory();
    return folder.path;
  }

  Future<File> getLocalFile(String fileName) async {
    String path = await getLocalPath();
    return File('$path/$fileName.txt');
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

  void uploadLogFile(
    id,
    token,
      file,
  ) async {
    String fileName = file.path.split('/').last;
    FormData formData = FormData.fromMap({
      "log_file":
      await MultipartFile.fromFile(file.path, filename:fileName),
      'user_id':'1',
    });
  DioHelper.dio.options.headers = {
  'Authorization': 'bearer '+token,
  'Content-Type': 'application/json',
  };

  await DioHelper.dio.post(
  UploadLogFiles,
  data: formData,
  );
  // print(res.data.toString());
  }


}

class Capture {
  List bssids = [];
  List levels = [];
  List uniqueBssidsLevels = [];
  List uniqueBssids = [];
  List averageLevels = [];
  String connectedCellId;
  String connectedSsid;

  Capture({
    this.levels,
    this.bssids,
    this.averageLevels,
    this.connectedCellId,
    this.connectedSsid,
    this.uniqueBssidsLevels,
    this.uniqueBssids,
  });

  Map<dynamic, dynamic> toJson() => {
        'bssids': bssids,
        'levels': levels,
        'uniqueBssidsLevels': uniqueBssidsLevels,
        'averageLevels': averageLevels,
        'connectedCellId': connectedCellId,
        'connectedSsid': connectedSsid,
        'uniqueBssids': uniqueBssids,
      };

  Capture.fromJson(Map json) {
    bssids = json['bssids'];
    levels = json['levels'];
    uniqueBssidsLevels = json['uniqueBssidsLevels'];
    averageLevels = json['averageLevels'];
    connectedCellId = json['connectedCellId'];
    connectedSsid = json['connectedSsid'];
    uniqueBssids = json['uniqueBssids'];
  }
}

class MyStates {
  double mean;
  double median;
  double standardDeviation;
  double variance;
  double skewness;
  double kurtosis;

  MyStates({
    this.standardDeviation,
    this.median,
    this.kurtosis,
    this.mean,
    this.skewness,
    this.variance,
  });

  Map<dynamic, dynamic> toJson() => {
        'mean': mean,
        'median': median,
        'standardDeviation': standardDeviation,
        'variance': variance,
        'skewness': skewness,
        'kurtosis': kurtosis,
      };

  MyStates.fromJson(Map json) {
    mean = json['mean'];
    median = json['median'];
    standardDeviation = json['standardDeviation'];
    variance = json['variance'];
    skewness = json['skewness'];
    kurtosis = json['kurtosis'];
  }
}
