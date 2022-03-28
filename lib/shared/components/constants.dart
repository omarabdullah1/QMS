// POST
// UPDATE
// DELETE

// GET

// base url : https://newsapi.org/
// method (url) : v2/top-headlines?
// queries : country=eg&category=business&apiKey=65f7f556ec76449fa7dc7c0069f040ca

// https://newsapi.org/v2/everything?q=tesla&apiKey=65f7f556ec76449fa7dc7c0069f040ca





// void signOut(context)
// {
//   CacheHelper.removeData(
//     key: 'token',
//   ).then((value)
//   {
//     if (value)
//     {
//       navigateAndFinish(
//         context,
//         ShopLoginScreen(),
//       );
//     }
//   });
// }

// ignore_for_file: avoid_print

void printFullText(String text) {
  final pattern = RegExp('.{1,800}'); // 800 is the size of each chunk
  pattern.allMatches(text).forEach((match) => print(match.group(0)));
}

String token = '';
bool isDone;
String username = '';
String password = '';
String getEncodedSigData ='';
String getEncodedSigStats ='';