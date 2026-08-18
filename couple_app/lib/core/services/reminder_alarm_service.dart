import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ReminderAlarmService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/reminder_alarm');

  static int notifId(String docId) {
    final bytes = utf8.encode(docId);
    final hash = md5.convert(bytes);
    return hash.hashCode & 0x7fffffff;
  }

  static Future<void> schedule({
    required String id,
    required String title,
    required String body,
    required DateTime dateTime,
    required bool recurringYearly,
  }) async {
    try {
      await _channel.invokeMethod('scheduleReminder', {
        'id': notifId(id),
        'title': title,
        'body': body,
        'timestampMillis': dateTime.millisecondsSinceEpoch,
        'recurringYearly': recurringYearly,
      });
    } catch (_) {}
  }

  static Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod('cancelReminder', {'id': notifId(id)});
    } catch (_) {}
  }

  static Future<void> syncAll(List<Map<String, dynamic>> reminders) async {
    try {
      await _channel.invokeMethod('syncReminders', {
        'items': reminders
            .map((r) => {
                  'id': notifId(r['id'] as String),
                  'title': r['title'],
                  'body': r['body'],
                  'timestampMillis':
                      (r['dateTime'] as DateTime).millisecondsSinceEpoch,
                  'recurringYearly': r['recurringYearly'],
                })
            .toList(),
      });
    } catch (_) {}
  }
}
