// Firebase configuration for NIKSHA OS.
//
// Hand-authored from android/app/google-services.json (Firebase project
// `akshara-erp`). Equivalent to the FlutterFire-CLI output, but only the
// Android platform is wired today — that is the only config the owner provided.
// When the iOS GoogleService-Info.plist is added, extend [ios] below with the
// real values and the rest of the push stack already supports it.
//
// The Android `apiKey`/`appId` here are client identifiers (restricted by the
// app's package name + signing key); they are not secrets. The push *sending*
// credential (the Firebase service account) lives only on the server.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Firebase is not configured for web — NIKSHA OS ships Android/iOS only.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS Firebase config not added yet — provide GoogleService-Info.plist '
          'and populate DefaultFirebaseOptions.ios.',
        );
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3VhTFrV7VWu-hhdIrDRbk-BZX_xWUsiw',
    appId: '1:35714138686:android:5c4b64cd7ef680300d876f',
    messagingSenderId: '35714138686',
    projectId: 'akshara-erp',
    storageBucket: 'akshara-erp.firebasestorage.app',
  );
}
