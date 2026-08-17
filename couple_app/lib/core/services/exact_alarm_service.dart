import 'package:flutter/services.dart';

/// Android 12+ (API 31) `SCHEDULE_EXACT_ALARM` icazəsini idarə edən körpü.
/// Bu icazə olmadan xatırladıcılar dəqiq vaxtda deyil, sistemin uyğun
/// gördüyü təxmini vaxtda (bəzən saatlarla gecikərək) işə düşə bilər.
class ExactAlarmService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/exact_alarm');

  static Future<bool> canScheduleExactAlarms() async {
    try {
      return await _channel.invokeMethod<bool>(
            'canScheduleExactAlarms',
          ) ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openExactAlarmSettings');
    } catch (_) {}
  }
}
