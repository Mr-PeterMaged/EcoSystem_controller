import 'package:flutter/material.dart';
void main(){
  runApp(MainApp());
}

class MainApp extends StatelessWidget{
const MainApp();

@override
  Widget build (BuildContext context){
  return MaterialApp(
    home:Scaffold(
      floatingActionButton: FloatingActionButton(onPressed:(){}),
      appBar: AppBar(title:const Text('Sample Code')),
      body:Center(
        child:Container(
          width:200, height: 200,
        alignment: Alignment.center,
          decoration: BoxDecoration(
            color:Colors.blue,
            borderRadius: BorderRadius.circular(10),
          child:Text('Hello World',
            style:TextStyle(
              fontSize: 25,
              color:Colors.black

            )
          ),
          ),
        ),
      ),
    ),
  );
}


}