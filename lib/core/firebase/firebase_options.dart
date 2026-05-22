import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase config for `com.imt.sales_visit_pro` (salesvisitpro project).
/// Values match [android/app/google-services.json].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase is not configured for web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDuWxEAwNDiWqT3zyuPTFdxhisjOvDtiLc',
    appId: '1:672339294776:android:067ce89085dbc560b3c4cd',
    messagingSenderId: '672339294776',
    projectId: 'salesvisitpro',
    storageBucket: 'salesvisitpro.firebasestorage.app',
  );
}
