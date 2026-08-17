import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Firebase Cloud Functions (Blaze planı tələb edir) əvəzinə, push
/// bildirişlərini Cloudflare Worker vasitəsilə göndəririk — tamamilə
/// pulsuz. Worker sənin Firebase layihən adından FCM-ə push göndərir.
///
/// `cloudflare-worker/deploy.ps1` skriptini işlətdikdən sonra çıxan
/// WORKER_URL və WORKER_AUTH_SECRET dəyərlərini AŞAĞIDA yerinə yaz.
class PushRelayService {
  // Cloudflare Worker — 14.07.2026 tarixində deploy olundu
  static const String _workerUrl =
      'https://sesi-push-relay.instagramim-az.workers.dev';
  static const String _authSecret = '9fMWX21HIf90VeMkZVedkD1xfHVCfCCbQpu5lcY';

  static bool get _configured => true;

  /// Partnerin FCM token-ini Firestore-dan oxuyur.
  static Future<String?> _partnerToken(String partnerUid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(partnerUid)
          .get();
      final token = doc.data()?['fcmToken'] as String?;
      return (token == null || token.isEmpty) ? null : token;
    } catch (_) {
      return null;
    }
  }

  /// Adi bildiriş (çat mesajı, "Evdeyəm" və s.) — başlıq+mətn görünür,
  /// sistem özü göstərir.
  static Future<void> notify({
    required String partnerUid,
    required String title,
    required String body,
  }) async {
    if (!_configured) return; // Worker hələ qurulmayıb — sükutla keç
    final token = await _partnerToken(partnerUid);
    if (token == null) return;
    await _post({
      'token': token,
      'title': title,
      'body': body,
    });
  }

  /// Data-only bildiriş (Təcili Çağırış) — "notification" bloku YOXDUR,
  /// tam ekran + səs + vibrasiyanı NATIVE tərəf (UrgentCallMessagingService.kt)
  /// qurur (Dart-ın FCM foreground handler-i bu axına ümumiyyətlə daxil
  /// deyil — bax: main.dart-dakı arxitektura qeydləri).
  static Future<void> notifyDataOnly({
    required String partnerUid,
    required Map<String, String> data,
  }) async {
    if (!_configured) return;
    final token = await _partnerToken(partnerUid);
    if (token == null) return;
    await _post({
      'token': token,
      'data': data,
      'apns': {
        'headers': {'apns-priority': '10'},
        'payload': {
          'aps': {'content-available': 1, 'sound': 'default'}
        }
      },
    });
  }

  static Future<void> _post(Map<String, dynamic> body) async {
    try {
      await http
          .post(
            Uri.parse(_workerUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authSecret',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Push uğursuz olsa belə, Firestore yazısı (əsas funksionallıq)
      // artıq tamamlanıb — sükutla keçirik, tətbiqi bloklamırıq.
    }
  }
}
