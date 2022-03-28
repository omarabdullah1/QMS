part of 'scanning_cubit.dart';

@immutable
abstract class ScanningStates {}

class ScanningInitial extends ScanningStates {}

class ScanningCountChangeState extends ScanningStates {}

class ScanningDoneState extends ScanningStates {}

class LoginSuccessState extends ScanningStates {}

class GetScanningAccessCount extends ScanningStates {}

class LoginErrorState extends ScanningStates {
  final String error;

  LoginErrorState(this.error);
}
