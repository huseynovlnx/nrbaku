import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platformu desteklenmiyor.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Bu platform desteklenmiyor.');
    }
  }

  // ✅ Gerçek değerler google-services.json dosyasından alındı

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDgI2SRjIH8SLaFaDZZonvBCA_2pokdXKc',
    appId: '1:97947807566:android:67f4a648a1e5a514ac781f',
    messagingSenderId: '97947807566',
    projectId: 'nrbaku-app',
    storageBucket: 'nrbaku-app.firebasestorage.app',
  );
  // ⚠️  iOS için: Firebase Console → Proje Ayarları → iOS uygulaması ekle
  // Ekledikten sonra GoogleService-Info.plist indir ve ios/Runner/ klasörüne koy
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'BURAYA_IOS_API_KEY_YAZ',         // Firebase Console'dan al
    appId: 'BURAYA_IOS_APP_ID_YAZ',           // Firebase Console'dan al
    messagingSenderId: '962845711313',
    projectId: 'flutter-ai-playground-a0afa',
    storageBucket: 'flutter-ai-playground-a0afa.firebasestorage.app',
    iosBundleId: 'com.example.privateCoupleApp',
  );
}
