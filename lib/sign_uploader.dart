import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';

final uuid = Uuid();

// TODO: replace this list with your full signs list
    final List<Map<String, String>> signs = [
    //food and drinks
    {'title': 'Bread', 'category': 'Food & Drinks', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Bread.mp4'},
    {'title': 'Juice', 'category': 'Food & Drinks', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Juice.mp4'},
    {'title': 'Drink', 'category': 'Food & Drinks', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Drink.mp4'},
    {'title': 'Eat', 'category': 'Food & Drinks', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Eat.mp4'},
    {'title': 'Water', 'category': 'Food & Drinks', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Water.mp4'},
    //family
    {'title': 'Brother', 'category': 'Family', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Brother.mp4'},
    {'title': 'Elder Sister', 'category': 'Family', 'difficulty': 'Medium', 'video': 'assets/assets/videos/ElderSister.mp4'},
    {'title': 'Father', 'category': 'Family', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Father.mp4'},
    {'title': 'Mother', 'category': 'Family', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Mother.mp4'},
    //travel
    {'title': 'Bus', 'category': 'Travel', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Bus.mp4'},
    {'title': 'Hotel', 'category': 'Travel', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Hotel.mp4'},
    {'title': 'Toilet', 'category': 'Travel', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Toilet.mp4'},
    //emotions
    {'title': 'Help', 'category': 'Emotions', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Help.mp4'},
    {'title': 'Hungry', 'category': 'Emotions', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Hungry.mp4'},
    {'title': 'Thirsty', 'category': 'Emotions', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Thirsty.mp4'},
    //others
    {'title': 'Objects', 'category': 'Others', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Objects.mp4'},
    //numbers
    {'title': '0', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/0.mp4'},
    {'title': '1', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/1.mp4'},
    {'title': '2', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/2.mp4'},
    {'title': '3', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/3.mp4'},
    {'title': '4', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/4.mp4'},
    {'title': '5', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/5.mp4'},
    {'title': '6', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/6.mp4'},
    {'title': '7', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/7.mp4'},
    {'title': '8', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/8.mp4'},
    {'title': '9', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/9.mp4'},
    {'title': '10', 'category': 'Numbers', 'difficulty': 'Easy', 'video': 'assets/assets/videos/10.mp4'},
    //alphabets
    {'title': 'A', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/A.mp4'},
    {'title': 'B', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/B.mp4'},
    {'title': 'C', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/C.mp4'},
    {'title': 'D', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/D.mp4'},
    {'title': 'E', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/E.mp4'},
    {'title': 'F', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/F.mp4'},
    {'title': 'G', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/G.mp4'},
    {'title': 'H', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/H.mp4'},
    {'title': 'I', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/I.mp4'},
    {'title': 'J', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/J.mp4'},
    {'title': 'K', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/K.mp4'},
    {'title': 'L', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/L.mp4'},
    {'title': 'M', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/M.mp4'},
    {'title': 'N', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/N.mp4'},
    {'title': 'O', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/O.mp4'},
    {'title': 'P', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/P.mp4'},
    {'title': 'Q', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Q.mp4'},
    {'title': 'R', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/R.mp4'},
    {'title': 'S', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/S.mp4'},
    {'title': 'T', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/T.mp4'},
    {'title': 'U', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/U.mp4'},
    {'title': 'V', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/V.mp4'},
    {'title': 'W', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/videos/W.mp4'},
    {'title': 'S', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/X.mp4'},
    {'title': 'Y', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Y.mp4'},
    {'title': 'Z', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Z.mp4'},
    {'title': 'Backspace', 'category': 'Alphabets', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Backspace.mp4'},
    {'title': 'Space', 'category': 'Alphabets', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Space.mp4'},
    // greetings and others
    {'title': 'Today', 'category': 'Greetings', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Today.mp4'},
    {'title': 'Hello', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Hello.mp4'},
    {'title': 'I', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/I(Saya).mp4'},
    {'title': 'I love you', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/ILoveYou.mp4'},
    {'title': 'Friends', 'category': 'Family', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Friend.mp4'},
    {'title': 'Night', 'category': 'Greetings', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Night.mp4'},
    {'title': 'Morning', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Morning.mp4'},
    {'title': 'Selamat', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Selamat.mp4'},
    {'title': 'Noon', 'category': 'Greetings', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Noon.mp4'},
    {'title': 'Thank you', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/ThankYou.mp4'},
    {'title': 'Ucapan', 'category': 'Greetings', 'difficulty': 'Medium', 'video': 'assets/assets/videos/Ucapan.mp4'},
    {'title': 'How much', 'category': 'Greetings', 'difficulty': 'Hard', 'video': 'assets/assets/videos/HowMuch.mp4'},
    {'title': 'No', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/No.mp4'},
    {'title': 'Yes', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Yes.mp4'},
    {'title': 'Sorry', 'category': 'Greetings', 'difficulty': 'Easy', 'video': 'assets/assets/videos/Sorry.mp4'},
  ];



/// Category mapping (replace with your real IDs from Firebase)
final Map<String, String> categoryMap = {
  "Food & Drinks": "f8xFnK9iilcwAFwbTNp2",
  "Family": "uRMfGPdZZKzE9T4tnWKh",
  "Travel": "PUnf0oYfMgBHu4aIxaUr",
  "Emotions": "0TyBEx5MLMCOESbjuiLv",
  "Others": "YDV95Ovd2bd7OdrtkvRt",
  "Numbers": "K4wQbtv1GdtMuVJnm3GR",
  "Alphabets": "r6DgDNZ6qLQ6X7llA47L",
  "Greetings": "bzdouKMVF3XzKSAGaxEt",
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore firestore = FirebaseFirestore.instance;
  CollectionReference signsCollection = firestore.collection("signs");

  for (var s in signs) {
    final id = uuid.v4(); // custom generated document ID

    final now = DateTime.now().toIso8601String();

    await signsCollection.doc(id).set({
      "signId": id,
      "title": s["title"],
      "meaning": s["title"],
      "categoryId": categoryMap[s["category"]] ?? "unknown",
      "videoUrl": s["video"], // replace with Supabase URL later
      "thumbnailUrl": "",
      "difficultyLevel": s["difficulty"],
      "description": "${s['title']} sign in Malaysian Sign Language",
      "createdAt": now,
      "updatedAt": now,
      "createdBy": "Ahmed",
    });

    print("Uploaded → ${s['title']}");
  }

  print("✅ DONE — All signs uploaded to Firestore!");
}