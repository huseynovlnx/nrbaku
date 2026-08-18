import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

/// Firebase konfiqurasiya seçimləri.
///
/// ⚠️ TƏHLÜKƏSİNLİK: Bu faylı heç vaxt public repo-da saxlamayın!
/// API açarları məhdudlaşdırılmalıdır (Firebase Console → API Keys → Restrictions).
///
/// Android üçün: SHA-1 fingerprint ilə məhdudlaşdırma tövsiyə olunur.
/// iOS üçün: ayrıca Firebase proyekti yaratmaq və ya eyni proyektdən
/// GoogleService-Info.plist istifadə etmək lazımdır.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web platformu dəstəklənmir.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS konfiqurasiyası tamamlanmayıb. '
          'Firebase Console-dan GoogleService-Info.plist əldə edin.',
        );
      default:
        throw UnsupportedError('Bu platform dəstəklənmir.');
    }
  }

  /// Android konfiqurasiyası.
  /// API açarı yalnız Android tətbiqi üçün məhdudlaşdırılmalıdır.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDgI2SRjIH8SLaFaDZZonvBCA_2pokdXKc',
    appId: '1:97947807566:android:67f4a648a1e5a514ac781f',
    messagingSenderId: '97947807566',
    projectId: 'nrbaku-app',
    storageBucket: 'nrbaku-app.firebasestorage.app',
  );
}
