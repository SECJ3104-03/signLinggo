import 'package:flutter/material.dart';
//import 'package:camera/camera.dart';
import 'package:signlinggo/screens/sign_recognition/sign_recognition_screen.dart';
import 'package:signlinggo/screens/Community_Module/community_hub.dart'; 
import 'package:signlinggo/screens/Offline_Mode/offline_view.dart';
import 'package:signlinggo/screens/conversation_mode/conversation_mode_screen.dart';

//List<CameraDescription> cameras = [];

Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  //cameras = await availableCameras();
// --- STEP 1: Call runApp() ONLY ONCE ---import 'package:signlinggo/screens/home/home_screen.dart';

void main() {
  runApp(MaterialApp (
    home: HomePage(),
  ));
}

}