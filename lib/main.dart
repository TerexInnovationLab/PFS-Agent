import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pfs_agent/pages/Home.dart';
import 'package:pfs_agent/pages/login.dart';


void main(){

  runApp(MyApp());
}

class MyApp extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    // TODO: implement build

    return MaterialApp(

      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }



}