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
    apiKey: 'AIzaSyB2wMO6HqDUZ7EqSwWJB0AEpc0fcE1lzO8',
    appId: '1:768545987217:android:57f8c64b295d852b29bd30',
    messagingSenderId: '768545987217',
    projectId: 'come-back-ce7ab',
    storageBucket: 'come-back-ce7ab.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDFB4kuo8pxdO401PQaaxWDp9JgSkFMkkY',
    appId: '1:768545987217:ios:011a4031c6f1e0e829bd30',
    messagingSenderId: '768545987217',
    projectId: 'come-back-ce7ab',
    storageBucket: 'come-back-ce7ab.firebasestorage.app',
    iosBundleId: 'com.comeback.app',
  );
}
