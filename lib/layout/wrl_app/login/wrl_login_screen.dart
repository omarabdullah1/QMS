// ignore_for_file: avoid_print

import 'package:conditional_builder/conditional_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../../../shared/components/components.dart';
import '../../../shared/components/constants.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../wifi_layout/scanning_layout.dart';
import 'cubit/login_cubit.dart';
import 'cubit/login_states.dart';

class HomeQuarantineLoginScreen extends StatefulWidget {
  const HomeQuarantineLoginScreen({Key key}) : super(key: key);

  @override
  State<HomeQuarantineLoginScreen> createState() =>
      _HomeQuarantineLoginScreenState();
}

class _HomeQuarantineLoginScreenState extends State<HomeQuarantineLoginScreen> {
  var formKey = GlobalKey<FormState>();

  var usernameController = TextEditingController();

  var passwordController = TextEditingController();
@override
  void initState() {
  FlutterBackgroundService().sendData({"action": "setAsForeground"});
}
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) => HomeQuarantineLoginCubit(),
      child: BlocConsumer<HomeQuarantineLoginCubit, HomeQuarantineLoginStates>(
        listener: (context, state) {
          if (state is HomeQuarantineLoginSuccessState) {
            if (state.loginModel.status == 200) {
              print(state.loginModel.message);
              print(state.loginModel.data.token);

              CacheHelper.saveData(
                key: 'token',
                value: state.loginModel.data.token,
              ).then((value) {
                token = state.loginModel.data.token;

                navigateAndFinish(
                  context,
                  const ScanningLayout(),
                );
              });
            } else {
              print(state.loginModel.message);

              // showToast(
              //   text: state.loginModel.message,
              //   state: ToastStates.ERROR,
              // );
            }
          }
        },
        builder: (context, state) {
          double width = MediaQuery.of(context).size.width;
          double height = MediaQuery.of(context).size.height;
          return Scaffold(
            backgroundColor: const Color.fromRGBO(247, 248, 250, 1),
            // appBar: AppBar(
            //   backgroundColor: const Color.fromRGBO(247, 248, 250, 1),
            //   elevation: 0.0,
            //   systemOverlayStyle: SystemUiOverlayStyle.light,
            //
            //   // brightness: Brightness.light,
            // ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(0.0, 60.0, 0.0, 0.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/New.png',
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(
                              height: height / 12,
                            ),
                            Form(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              key: formKey,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    height: 50,
                                  ),
                                  defaultFormField(
                                    controller: usernameController,
                                    validate: (String value) {
                                      if (value.isEmpty) {
                                        return 'please enter your email address';
                                      }
                                    },
                                    type: TextInputType.emailAddress,
                                    label: 'username',
                                    prefix: Icons.person,
                                  ),
                                  const SizedBox(height: 30),
                                  defaultFormField(
                                    controller: passwordController,
                                    validate: (String value) {
                                      if (value.isEmpty) {
                                        return 'password is too short';
                                      }
                                    },
                                    type: TextInputType.visiblePassword,
                                    isPassword: true,
                                    label: 'password',
                                    prefix: Icons.password,
                                  ),
                                  const SizedBox(height: 40),
                                  ConditionalBuilder(
                                    condition: state
                                        is! HomeQuarantineLoginLoadingState,
                                    builder: (context) => SizedBox(
                                      height: 40,
                                      width: width - 100,
                                      child: MaterialButton(
                                        onPressed: () async {
                                          if (formKey.currentState.validate()) {
                                            HomeQuarantineLoginCubit.get(
                                                    context)
                                                .userLogin(
                                              username: usernameController.text,
                                              password: passwordController.text,
                                            );
                                            CacheHelper.saveData(
                                                key: 'username',
                                                value: usernameController.text);
                                            CacheHelper.saveData(
                                                key: 'password',
                                                value: passwordController.text);
                                          }
                                        },
                                        child: const Text(
                                          'Log in',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        color: Colors.indigo[900],
                                      ),
                                    ),
                                    fallback: (context) => const Center(
                                        child: CircularProgressIndicator(
                                      color: Colors.indigo,
                                    )),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
