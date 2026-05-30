import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAMBtdoWTfZC7apPaVmh9TJ0CXVdCiOxxE',
    appId: '1:333325883612:android:cd332cd809ceb6b1fb3c19',
    messagingSenderId: '333325883612',
    projectId: 'comback-5a080',
    storageBucket: 'comback-5a080.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '333325883612',
    projectId: 'comback-5a080',
    storageBucket: 'comback-5a080.firebasestorage.app',
    iosBundleId: 'com.comeback.app',
  );
}
