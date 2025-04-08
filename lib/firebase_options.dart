// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDWGobHYhnrjPM_U3VfFJsdXfGEo3OJj80',
    appId: '1:994388729420:web:e7e047585d582713035ee9',
    messagingSenderId: '994388729420',
    projectId: 'weekendmingle-cbe85',
    authDomain: 'weekendmingle-cbe85.firebaseapp.com',
    storageBucket: 'weekendmingle-cbe85.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB94wSeI7o-y9WVykxHDlmpzrv0L3sZ8iM',
    appId: '1:994388729420:android:b9101ec9eddf822a035ee9',
    messagingSenderId: '994388729420',
    projectId: 'weekendmingle-cbe85',
    storageBucket: 'weekendmingle-cbe85.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCHrI-UaxTLK1Vc96UhUarb6IAqueN67Rk',
    appId: '1:994388729420:ios:2a41801c2d4138e6035ee9',
    messagingSenderId: '994388729420',
    projectId: 'weekendmingle-cbe85',
    storageBucket: 'weekendmingle-cbe85.firebasestorage.app',
    androidClientId: '994388729420-slo0sr4gbbanae220r1jl5dscr4mkf6b.apps.googleusercontent.com',
    iosClientId: '994388729420-i8be3ab9g5sq1ofklh83trn2c8dt0gir.apps.googleusercontent.com',
    iosBundleId: 'com.example.weekendMingle',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCHrI-UaxTLK1Vc96UhUarb6IAqueN67Rk',
    appId: '1:994388729420:ios:2a41801c2d4138e6035ee9',
    messagingSenderId: '994388729420',
    projectId: 'weekendmingle-cbe85',
    storageBucket: 'weekendmingle-cbe85.firebasestorage.app',
    androidClientId: '994388729420-slo0sr4gbbanae220r1jl5dscr4mkf6b.apps.googleusercontent.com',
    iosClientId: '994388729420-i8be3ab9g5sq1ofklh83trn2c8dt0gir.apps.googleusercontent.com',
    iosBundleId: 'com.example.weekendMingle',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDWGobHYhnrjPM_U3VfFJsdXfGEo3OJj80',
    appId: '1:994388729420:web:a132902f8c300337035ee9',
    messagingSenderId: '994388729420',
    projectId: 'weekendmingle-cbe85',
    authDomain: 'weekendmingle-cbe85.firebaseapp.com',
    storageBucket: 'weekendmingle-cbe85.firebasestorage.app',
  );
}
