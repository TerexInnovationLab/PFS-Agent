
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class PendingPage extends StatefulWidget{

  PendingPageState createState() => PendingPageState();

}

class PendingPageState extends State<PendingPage>{
  @override
  Widget build(BuildContext context) {
    // TODO: implement build


    return Scaffold(

      body: Stack(


        fit: StackFit.expand,
        children: [


          Image.asset('assets/images/orange background.jpg', fit: BoxFit.cover),

          Center(
            child: Container(
              margin: EdgeInsets.only(top: 150, bottom: 150, right: 50, left: 50),
              padding: EdgeInsets.only(left: 20, right: 20),
              width: double.infinity,
              decoration: BoxDecoration(


                color: Color(0x7B000000),
                borderRadius: BorderRadius.circular(16),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  Text("PENDING", style: TextStyle(

                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),),


                  SizedBox(height: 20,),
                  Text("Please, wait while we are verifying your details and documents.\n \n You will be sent a confirmation and can log in the system once verified.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white),)

                ],

              ),
            ),
          )
        ],
      ),
    );
  }



}