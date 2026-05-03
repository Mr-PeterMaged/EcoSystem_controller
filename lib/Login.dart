import 'package:flutter/material.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Login",
          style: TextStyle(
            color: Colors.black,
            fontSize: 25,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        backgroundColor: Colors.grey,
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: 30),
          Center(
            child: Image.asset("lib/assets/image.jpg", height: 200, width: 200),
          ),
          SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                label: Text(
                  "email",
                  style: TextStyle(color: Colors.amber, fontSize: 20),
                ),
                prefixIcon: Icon(Icons.email_outlined),
                prefixIconColor: Colors.red,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(height: 30,),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              decoration: InputDecoration(
                label: Text(
                  "password",
                  style: TextStyle(color: Colors.amber, fontSize: 20),
                ),
                prefixIcon: Icon(Icons.remove_red_eye),
                prefixIconColor: Colors.red,
                border: OutlineInputBorder(),
              ),
            ),
          ),

          SizedBox(height: 30,),
          Row (
            children: [
              Checkbox(value: isChecked, onChanged: (value){
                setState(() {
                  isChecked=value!;
                });

              }),
              Text("Remember Me" , style: TextStyle(color:Colors.deepOrange,fontSize: 25),),

            ],
          ),
          Divider(
            thickness:3,
            color: Colors.deepOrange,
            indent: 70,
            endIndent: 70,
          ),

          Text(isChecked? "ON" : "OFF",style: TextStyle(
            color: isChecked? Colors.green :Colors.red,
            fontSize: 25,
            fontWeight: FontWeight.bold
          ),)


        ],
      ),
    );
  }
}
