import 'package:flutter/services.dart';

/// Native `AlarmManager.setAlarmClock()` əsaslı xatırladıcı planlaşdırıcısına
/// körpü — telefonun daxili Alarm tətbiqi ilə eyni mexanizm, heç bir icazə
/// tələb etmir, Doze/batareya optimallaşdırmasından tam müstəsnadır.
class ReminderAlarmService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/reminder_alarm');

  /// Dart-ın `String.hashCode`-u Android-in 32-bit tam ədəd sərhədini
  /// keçə bilər — həmişə təhlükəsiz müsbət diapazona sıxışdırırıq.
  static int notifId(String docId) => docId.hashCode & 0x7fffffff;

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
    } catch (_) {
      // Sükutla keç — istifadəçi planı görməyə davam edir, sadəcə alarm
      // qurula bilmədi (məs. çox köhnə Android versiyası).
    }
  }

  static Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod('cancelReminder', {'id': notifId(id)});
    } catch (_) {}
  }

  /// Cari (hazırkı) xatırladıcı siyahısını native tərəfə göndərir — native
  /// tərəf bunu artıq qurulmuş alarmlarla müqayisə edib, siyahıda OLMAYAN
  /// (silinmiş) hər hansı alarmı özü ləğv edir. Bu, təkcə "əlavə et"
  /// əməliyyatı üçün deyil, HƏM DƏ silinməni partnerin cihazına da
  /// "çatdırmaq" üçün istifadə olunur (bax: reminder_providers.dart).
  ///
  /// Hər map bu sahələri daşımalıdır: id, title, body, dateTime, recurringYearly
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
