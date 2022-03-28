// ignore_for_file: avoid_print, non_constant_identifier_names

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';
import 'package:stats/stats.dart';
import 'package:wifi_iot/wifi_iot.dart';

import '../../../../models/user/user_model.dart';
import '../../../../shared/network/end_points.dart';
import '../../../../shared/network/local/cache_helper.dart';
import '../../../../shared/network/remote/dio_helper.dart';

part 'scanning_states.dart';

class ScanningCubit extends Cubit<ScanningStates> {
  ScanningCubit() : super(ScanningInitial());
  static ScanningCubit get(context) => BlocProvider.of(context);

  //VARS AND OBJECTS SECTION
  //////////////////////////////////////////////////////////////////////////////

  //some view variables
  var capturesCount = 0;
  // var capturesCountc = -3;
  var isInside = false;
  UserModel loginModel;
  var scansCount = 1;
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
  bool minAccessFounded = false;

////////////////////////////////////////////////////////////////////////////////
  // Capture original =Capture();
  // Capture combinedSignature = Capture();
  // Capture localCurrentCapture = Capture();
  //objects of Capture
  Capture mSignature = Capture();
  MyStates sigStates = MyStates();

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//
//   //get cell id func
//   Future<String> getCID() async {
//     Map _platformVersion;
//     try {
//       _platformVersion = await FlutterGsmcelllocation.getGsmCell;
//     } on PlatformException {
//       _platformVersion = 'Failed to get platform version.' as Map;
//       return null;
//     }
//     _platformVersion = _platformVersion;
//     return "LAC:" +
//         _platformVersion['lac'].toString() +
//         ",CID:" +
//         _platformVersion['cid'].toString();
//   }

////////////////////////////////////////////////////////////////////////////////

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
    await loadWifiList().then(
      (value) {
        wifiNetwork = value;
        capturesCount++;
        emit(ScanningCountChangeState());
        // print(capturesCount);
      },
    ).catchError(
      (error) {
        print(error);
      },
    );

    for (var device in wifiNetwork) {
      // print(device.ssid);
      // print(device.bssid);
      // print(device.level.toDouble());
      bssids.add(device.bssid);
      levels.add(device.level.toDouble() + 150);
    }

    // print(bssids);
    // print(levels);
    // print(bssids);
    // print(levels);
    // print(levels);
    // print('wifi scanned');
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

/////////////////////////////////////////////////////////////////////////////
  ///new algorithm
  void checkAvailablity() {
    // var uniqeBSSIDLevelsMap ={};
    // for (var element in bssids) {
    //   if (!uniqeBSSIDLevelsMap.containsKey(element)) {
    //     uniqeBSSIDLevelsMap[element] = [];
    //   } else {
    //     uniqeBSSIDLevelsMap[element] = getLevels(element);
    //   }
    // }
    var unique = bssids;
    unique = bssids.toSet().toList();
    // print(unique);
    print('this is my uniqeBSSIDLevelsMap keys      $unique');
    if (unique.length < 5) {
      minAccessFounded = true;
    } else {
      minAccessFounded = false;
    }
  }

  void getUnique() {
    var unique = bssids.toSet().toList();

    for (var element in bssids) {
      if (!uniqeBSSIDLevelsMap.containsKey(element)) {
        uniqeBSSIDLevelsMap[element] = [];
      } else {
        uniqeBSSIDLevelsMap[element] = getLevels(element);
      }
    }
    uniqueLevelsList = uniqeBSSIDLevelsMap.values.toList();
    uniqueBSSIDSList = uniqeBSSIDLevelsMap.keys.toList();
    List uniqeLev = [];
    for (var element in unique) {
      uniqeLev.add(uniqueLevelsList[uniqueBSSIDSList.indexOf(element)]);
    }
    // get list of averages of unique list
    sigMean = [];
    for (List<double> element in uniqeLev) {
      sigMean.add(element.average);
    }
    // print(sigMean);

    //get states for list of averages of unique list
    final st = Stats.fromData(sigMean);

    sigMedian = st.median;
    sigSTD = STD(sigMean);
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
    print(mSignature.toJson());
    print(sigStates.toJson());

    // return uniqeBSSIDLevelsMap.toString();
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
    capturesCount = 0;
  }

  void saveData() {
    String encodedSigData = json.encode(mSignature.toJson());
    CacheHelper.saveData(key: 'sig', value: encodedSigData);
    print('endcoded sig data  ' + encodedSigData);

    String encodedSigStats = json.encode(sigStates.toJson());
    CacheHelper.saveData(key: 'sigStats', value: encodedSigStats);

    CacheHelper.saveData(key: 'DoneScanning', value: true);
    String getEncodedSigData = CacheHelper.getData(key: 'sig');
    Map decodedSigData = json.decode(getEncodedSigData);
    print('decoded sig data  ' + decodedSigData.toString());

    String getEncodedSigStats = CacheHelper.getData(key: 'sigStats');
    Map decodedSigStats = json.decode(getEncodedSigStats);
    print('decoded sig states  ' + decodedSigStats.toString());
  }

//Function to get std
  double STD(List<double> arr) {
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
  double Covar(List<double> arr1, List<double> arr2) {
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
  double Correl(List<double> arr1, List<double> arr2) {
    double mCov = Covar(arr1, arr2);
    double stdA = STD(arr1);
    double stdB = STD(arr2);
    return mCov / (stdA * stdB);
  }

  userLogin() {
    String user = CacheHelper.getData(key: 'username');
    String pass = CacheHelper.getData(key: 'password');
    DioHelper.postData(
      url: LOGIN,
      data: {
        'username': user,
        'password': pass,
      },
    ).then((value) {
      // print(value.data);
      loginModel = UserModel.fromJson(value.data);
      scansCount = loginModel.data.scanCount;
      emit(LoginSuccessState());
    }).catchError((error) {
      print(error.toString());
      emit(LoginErrorState(error.toString()));
    });
  }

  getScanningAccessCount() {
    userLogin();
    emit(GetScanningAccessCount());
    // return remainingDays;
  }

/////////////////////////////////////////////////////////////////////////////
  doneFunc(context) {
    getUnique();
    saveData();
    CacheHelper.saveData(key: 'DoneScanning', value: true);
    emit(ScanningDoneState());
  }
}

class Capture {
  List bssids = [];
  List levels = [];
  List uniqueBssidsLevels = [];
  List uniqueBssids = [];
  List averageLevels = [];

  // String connectedCellId;
  // String connectedSsid;

  Capture({
    this.levels,
    this.bssids,
    this.averageLevels,
    // this.connectedCellId,
    // this.connectedSsid,
    this.uniqueBssidsLevels,
    this.uniqueBssids,
  });

  Map<dynamic, dynamic> toJson() => {
        'bssids': bssids,
        'levels': levels,
        'uniqueBssidsLevels': uniqueBssidsLevels,
        'averageLevels': averageLevels,
        // 'connectedCellId': connectedCellId,
        // 'connectedSsid': connectedSsid,
        'uniqueBssids': uniqueBssids,
      };

  Capture.fromJson(Map json) {
    bssids = json['bssids'];
    levels = json['levels'];
    uniqueBssidsLevels = json['uniqueBssidsLevels'];
    averageLevels = json['averageLevels'];
    // connectedCellId = json['connectedCellId'];
    // connectedSsid = json['connectedSsid'];
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
