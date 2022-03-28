// import 'dart:convert';

// UserModel userFromJson(String str) => UserModel.toObject(json.decode(str));
//
// class UserModel {
//   Data data;
//   int status;
//   String message;
//
//   UserModel({this.data,this.status,this.message});
//
//   factory UserModel.toObject(Map<String, dynamic> json) =>
//       UserModel(
//         data: Data.toObject(json['data']),
//         status: json['status'],
//         message: json['message'],
//       );
//
//   Map<String, dynamic> toJson() =>
//       {
//         "data": data.toJson(),
//       };
// }
//
// class Data {
//   int id;
//   String name;
//   String braceletID;
//   int remainingDays;
//   int startDate;
//   int endDate;
//   String token;
//
//   Data(
//   {this.id, this.name, this.braceletID, this.endDate, this.remainingDays, this.startDate, this.token});
//
//   factory Data.toObject(Map<String, dynamic> json) =>
//       Data(
//       id : json['id'],
//       name : json['name'],
//       braceletID : json['bracelet_ID'],
//       remainingDays : json['remaining_days'],
//       startDate : json['start_date'],
//       endDate : json['end_date'],
//       token : json['token'],
//       );
//
//   Map<String, dynamic> toJson() =>
//       {
//         'id': id,
//         'name': name,
//         'bracelet_ID': braceletID,
//         'remaining_days': remainingDays,
//         'start_date': startDate,
//         'end_date': endDate,
//         'token': token,
//
//       };
//
// }

/*
UserModel userModelFromJson(String str) => UserModel.fromJson(json.decode(str));

String userModelToJson(UserModel data) => json.encode(data.toJson());

class UserModel {
  User user;
  String token;

  UserModel({required this.user, required this.token});

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      UserModel(user: User.fromJson(json["user"]), token: json['token']);
}

class User {
  String name;
  String email;
  String password;

  User({required this.name, required this.email, required this.password});

  factory User.fromJson(Map<String, dynamic> json) =>
      User(name: json["name"], email: json['email'], password: json['password']);

Map<String, dynamic> toJson() =>
    {
      "name": name,
      "email": email,
      "password": password
    };



}*/

class UserModel {
  int status;
  String message;
  UserData data;

  UserModel.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    message = json['message'];
    data = json['data'] != null ? UserData.fromJson(json['data']) : null;
  }
}

class UserData {
  int id;
  String name;
  String braceletID;
  int remainingDays;
  int totalDate;
  int scanCount;
  // int endDate;
  String token;
  String sig;
  String stats;

  // named constructor
  UserData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    braceletID = json['bracelet_ID'];
    remainingDays = json['remaining_days'];
    totalDate = json['total_days'];
    scanCount = json['scans_count'];
    sig = json['sig'];
    stats = json['stats'];
    // startDate:
    // json['start_date'];
    // endDate:
    // json['end_date'];
    token = json['token'];
  }
}
