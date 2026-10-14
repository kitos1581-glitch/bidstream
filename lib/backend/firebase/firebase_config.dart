import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyAv4NTSMLxVFjCkhMIadMMcMFTxf9SYPVc",
            authDomain: "bidstream-656cf.firebaseapp.com",
            projectId: "bidstream-656cf",
            storageBucket: "bidstream-656cf.firebasestorage.app",
            messagingSenderId: "454079777397",
            appId: "1:454079777397:web:551228d3b459e34e21463c"));
  } else {
    await Firebase.initializeApp();
  }
}
