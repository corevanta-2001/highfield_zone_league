import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDdaCSGopIo17lsu1JwK5jFTDO3If-YouA",
    authDomain: "highfields-78e12.firebaseapp.com",
    projectId: "highfields-78e12",
    storageBucket: "highfields-78e12.firebasestorage.app",
    messagingSenderId: "906294378990",
    appId: "1:906294378990:web:2c02f4ee29bbf0b3400eff",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyBtdZlbtD8vHML1JpuM2DP58sjlK0V2MV4",
    appId: "1:906294378990:android:a7ee3c8d90e3cde5400eff",
    messagingSenderId: "906294378990",
    projectId: "highfields-78e12",
    storageBucket: "highfields-78e12.firebasestorage.app",
  );
}