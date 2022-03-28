import '../../../../models/user/user_model.dart';

abstract class HomeQuarantineLoginStates {}

class HomeQuarantineLoginInitialState extends HomeQuarantineLoginStates {}

class HomeQuarantineLoginLoadingState extends HomeQuarantineLoginStates {}

class HomeQuarantineLoginSuccessState extends HomeQuarantineLoginStates {
  final UserModel loginModel;

  HomeQuarantineLoginSuccessState(this.loginModel);
}

class HomeQuarantineLoginErrorState extends HomeQuarantineLoginStates {
  final String error;

  HomeQuarantineLoginErrorState(this.error);
}

class HomeQuarantineChangePasswordVisibilityState
    extends HomeQuarantineLoginStates {}
