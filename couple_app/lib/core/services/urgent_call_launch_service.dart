import 'package:flutter/services.dart';

/// `UrgentCallMessagingService.kt` (native) tam ekranlı bildirişdən
/// tətbiqi açanda/önə gətirəndə, hansı çağırışdan açıldığını bu kanal
/// vasitəsilə Dart tərəfə ötürür.
class UrgentCallLaunchService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/urgent_call_launch');

  static void Function(Map<String, String> data)? onLaunch;
  static bool _initialized = false;

  /// Tətbiq artıq açıq olarkən (arxa planda) native bildiriş tıklanarsa
  /// çağırılır.
  static void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onUrgentCallLaunch') {
        final raw = call.arguments as Map;
        final data = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
        onLaunch?.call(data);
      }
    });
  }

  /// Tətbiq tamamilə bağlı ikən (cold start) native bildirişdən açılıbsa,
  /// başlanğıc datasını bir dəfəlik oxumaq üçün.
  static Future<Map<String, String>?> getPendingLaunch() async {
    try {
      final result = await _channel.invokeMethod('getPendingUrgentCall');
      if (result == null) return null;
      final raw = result as Map;
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return null;
    }
  }
}
