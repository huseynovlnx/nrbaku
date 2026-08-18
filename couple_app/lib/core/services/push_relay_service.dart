import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class PushRelayService {
  static String? _workerUrl;
  static String? _authSecret;

  static bool get _configured => _workerUrl != null && _authSecret != null;

  static void configure({required String workerUrl, required String authSecret}) {
    _workerUrl = workerUrl;
    _authSecret = authSecret;
  }

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

  static Future<void> notify({
    required String partnerUid,
    required String title,
    required String body,
  }) async {
    if (!_configured) {
      if (kDebugMode) debugPrint('PushRelay: Worker not configured');
      return;
    }
    final token = await _partnerToken(partnerUid);
    if (token == null) return;
    await _post({
      'token': token,
      'title': title,
      'body': body,
    });
  }

  static Future<void> notifyDataOnly({
    required String partnerUid,
    required Map<String, dynamic> data,
  }) async {
    if (!_configured) {
      if (kDebugMode) debugPrint('PushRelay: Worker not configured');
      return;
    }
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
            Uri.parse(_workerUrl!),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer \$_authSecret',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) debugPrint('PushRelay error: \$e');
    }
  }
}
