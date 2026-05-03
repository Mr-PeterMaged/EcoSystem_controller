// import 'package:flutter/material.dart';
//
// void main() {
//   runApp(
//     MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: Scaffold(
//         appBar: AppBar(
//           leading: Icon(Icons.arrow_back, size: 30, color: Colors.black),
//           title: Text(
//             "My First App",
//             style: TextStyle(fontSize: 25, color: Colors.black),
//           ),
//           actions: [
//             Icon(Icons.menu_book_outlined, color: Colors.black, size: 30),
//             Text("menu", style: TextStyle(fontSize: 20, color: Colors.black)),
//           ],
//           backgroundColor: Colors.green[300],
//           centerTitle: true,
//         ),
//
//         body: SizedBox(
//           width: double.infinity,
//           height: double.infinity,
//           child: Column(
//             children: [Container(
//                 color: Colors.red, height: 200, width: 400),
//             SizedBox(
//               height: 10,
//             ),
//             Row(
//               children: [
//                 Container(
//                   width:190,
//                   height: 200,
//                     color:Colors.blue,
//                 ),
//                 SizedBox(width: 10,),
//                 Container(
//                   width:190,
//                   height: 200,
//                   color:Colors.blue,
//                 ),
//
//               ],
//             )
//             ],
//           ),
//         ),



        //SizedBox(
        //   width: double.infinity,
        //   height: double.infinity,
        //   child: Column(
        //     mainAxisAlignment: MainAxisAlignment.end,
        //     crossAxisAlignment: CrossAxisAlignment.center,
        //     children: [
        //       Text(
        //         "First Column",
        //         style: TextStyle(color: Colors.black, fontSize: 30),
        //       ),
        //       Icon(Icons.eighteen_up_rating, size: 50),
        //     ],
        //   ),
        // ),

        // Center(
        //   child: Container(
        //     width:200,
        //     height:200,
        //     padding: EdgeInsets.all(20),
        //     color:Colors.amber,
        //     child:Center(
        //       child: Text("My First App", style:TextStyle(color:Colors.black , fontSize: 20),
        //       ),
        //     ),
        //   ),
//       ),
//     ),
//   );
// }



//=========================================================



import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }

}












