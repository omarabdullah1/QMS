part of 'status_cubit.dart';

@immutable
abstract class StatusStates {}

class TestInitial extends StatusStates {}

class TestChangeWifiState extends StatusStates {}

class TestCheckRepeatedState extends StatusStates {}

class TestIsInsideChangeState extends StatusStates {}

class InitForeGroundState extends StatusStates {}

class StartForeGroundState extends StatusStates {}

class RestartForeGroundState extends StatusStates {}

class UploadFileSuccessState extends StatusStates {}

class UploadFileErrorState extends StatusStates {
  final String error;

  UploadFileErrorState(this.error);
}

class LoginSuccessState extends StatusStates {
  // final UserModel loginModel;

  // LoginSuccessState(this.loginModel);
}

class LoginErrorState extends StatusStates {
  final String error;

  LoginErrorState(this.error);
}

class UpdateSuccessState extends StatusStates {}

class GetRemainingDaysState extends StatusStates {}
class AppCreateDatabaseState extends StatusStates {}
class AppInsertDatabaseState extends StatusStates {}
class AppGetDatabaseLoadingState extends StatusStates {}
class AppGetDatabaseState extends StatusStates {}
