import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return android; // fallback
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAoW5Niu_BqESP3BhEHdehhadd0TBuHSvQ',
    appId: '1:822070046804:android:bdba41453f8cdf2150fdc1',
    messagingSenderId: '822070046804',
    projectId: 'sanlam-chronic-care',
    storageBucket: 'sanlam-chronic-care.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAoW5Niu_BqESP3BhEHdehhadd0TBuHSvQ',
    appId: '1:822070046804:android:bdba41453f8cdf2150fdc1',
    messagingSenderId: '822070046804',
    projectId: 'sanlam-chronic-care',
    storageBucket: 'sanlam-chronic-care.firebasestorage.app',
    iosBundleId: 'co.za.sanlam.sanlamChronic',
  );
}
