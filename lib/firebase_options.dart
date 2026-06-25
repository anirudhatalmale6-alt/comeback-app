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
    apiKey: 'AIzaSyAt2OPAfGsHivQ6UqA0yAmFwv3mo2X8QdQ',
    appId: '1:1056346327905:android:8ee6d494abe5727d281320',
    messagingSenderId: '1056346327905',
    projectId: 'come-back-8e61d',
    storageBucket: 'come-back-8e61d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB-BkeEeTf2tpfLL8YMv8Kb6C61B7DQjFY',
    appId: '1:1056346327905:ios:45fb153acd267327281320',
    messagingSenderId: '1056346327905',
    projectId: 'come-back-8e61d',
    storageBucket: 'come-back-8e61d.firebasestorage.app',
    iosBundleId: 'com.comeback.app',
  );
}
