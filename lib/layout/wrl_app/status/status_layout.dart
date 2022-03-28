
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_file/open_file.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:qms2/shared/components/constants.dart';
import '../../../main.dart';
import '../../../shared/network/local/cache_helper.dart';
import 'cubit/status_cubit.dart';

class StatusLayout extends StatefulWidget {
  const StatusLayout({Key key}) : super(key: key);

  @override
  _StatusLayoutState createState() => _StatusLayoutState();
}

class _StatusLayoutState extends State<StatusLayout> {
  @override
  void initState() {
    super.initState();

    StatusCubit.get(context).btFunction();
    token = CacheHelper.getData(key: 'token');
    isDone = CacheHelper.getData(key: 'DoneScanning');
    username = CacheHelper.getData(key: 'username');
    password = CacheHelper.getData(key: 'password');
    getEncodedSigData = CacheHelper.getData(key: 'sig');
    getEncodedSigStats = CacheHelper.getData(key: 'sigStats');
    Session().writeData(username ?? '', 'username');
    Session().writeData(password ?? '', 'password');
    Session().writeData(token ?? '', 'token');
    Session().writeData('true' ?? '', 'done');
    Session().writeData(getEncodedSigData ?? '', 'sig');
    Session().writeData(getEncodedSigStats ?? '', 'sigStats');
    FlutterBackgroundService().sendData({"action": "setAsForeground"});
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      StatusCubit.get(context).checkRepeated();
      await Session().writeData('true' ?? '', 'done');
    });
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      StatusCubit.get(context).userLogin(CacheHelper.getData(key: 'username'),
          CacheHelper.getData(key: 'password'));
      var tok = StatusCubit.get(context).loginModel.data.token;
      var id = StatusCubit.get(context).loginModel.data.id;
      StatusCubit.get(context).userPut(
        token: tok,
        id: id,
        isInside: StatusCubit.get(context).isInside,
        isPaired: StatusCubit.get(context).isPaired,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: StatusCubit.get(context).getRemainingDays(),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        // AsyncSnapshot<Your object type>
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Text('Please wait its loading...'));
        } else {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            return BlocConsumer<StatusCubit, StatusStates>(
              listener: (context, state) {},
              builder: (context, state) {
                var statusCubit = StatusCubit.get(context);
                return Scaffold(
                  backgroundColor: const Color.fromRGBO(247, 248, 250, 1),
                  appBar: AppBar(
                    leading: null,
                    elevation: 0.0,
                    backgroundColor: const Color.fromRGBO(247, 248, 250, 1),
                  ),
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              'Your Status',
                              style: TextStyle(
                                color: Colors.indigo[900],
                                fontWeight: FontWeight.bold,
                                fontSize: 22.0,
                              ),
                            ),
                            const SizedBox(
                              height: 150.0,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularPercentIndicator(
                                  radius: 200.0,
                                  lineWidth: 8.0,
                                  animation: true,
                                  percent: (statusCubit.remainingDays /
                                      statusCubit.totalDays),
                                  center: SizedBox(
                                    height: 200,
                                    width: 200.0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${statusCubit.remainingDays}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 60.0,
                                            color: Colors.indigo[900],
                                          ),
                                        ),
                                        // const SizedBox(
                                        //   width: 15.0,
                                        // ),
                                        const SizedBox(
                                          width: 15.0,
                                        ),
                                        Text(
                                          'Remaining\nQuarantine\nDays',
                                          style: TextStyle(
                                            color: Colors.indigo[900],
                                            fontSize: 16.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  circularStrokeCap: CircularStrokeCap.round,
                                  progressColor: Colors.indigo[900],
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(
                                  height: 120.0,
                                ),
                                ElevatedButton(
                                    onPressed: () async {
                                      statusCubit.isInside = false;
                                      await statusCubit
                                          .readData('log')
                                          .then((value) async {
                                        String v = value;
                                        await statusCubit.writeData(
                                            '$v ${DateTime.now()}  outSide from me \n',
                                            'log');
                                      });
                                    },
                                    child: const Text('outSide')),
                                const SizedBox(
                                  height: 10,
                                ),
                                ElevatedButton(
                                    onPressed: () {
                                      statusCubit
                                          .readData('log')
                                          .then((value) async {
                                        printFullText(value);
                                        String path =
                                            await statusCubit.getLocalPath();
                                        OpenFile.open('$path/log.txt')
                                            .then((value) => null);
                                      });
                                    },
                                    child: const Text('get Log')),
                                ElevatedButton(
                                    onPressed: () async {
                                      // FlutterRingtonePlayer.stop();
                                      StatusCubit.get(context).userLogin(
                                          CacheHelper.getData(key: 'username'),
                                          CacheHelper.getData(key: 'password'));
                                      File mFile =
                                          await statusCubit.getLocalFile('log');
                                      var tok = StatusCubit.get(context)
                                          .loginModel
                                          .data
                                          .token;
                                      var id = StatusCubit.get(context)
                                          .loginModel
                                          .data
                                          .id;
                                      StatusCubit.get(context)
                                          .uploadLogFile(id, tok, mFile);
                                    },
                                    child: const Text('upload')),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Your Home Status',
                                      style: TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                    const Spacer(),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: statusCubit.isInside
                                            ? Colors.green
                                            : Colors.red,
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Center(
                                        child: Text(
                                          statusCubit.isInside
                                              ? 'Inside'
                                              : 'Outside',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.0,
                                          ),
                                        ),
                                      ),
                                      width: 120.0,
                                      height: 30.0,
                                    ),
                                  ],
                                ),
                                // Text('isInside ${}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          } // snapshot.data  :- get your object which is pass from your downloadData() function
        }
      },
    );
  }
}
