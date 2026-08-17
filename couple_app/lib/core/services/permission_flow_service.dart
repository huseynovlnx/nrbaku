import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Full-Screen Intent (Android 14+) və DND (Do Not Disturb) girişi kimi
/// yeni icazələr üçün native tərəflə körpü. Bu icazələr Android-in
/// `permission_handler` paketinin bilmədiyi xüsusi Settings ekranlarına
/// yönləndirmə tələb etdiyi üçün ayrıca method channel istifadə olunur.
class PermissionFlowService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/permission_flow');

  static bool get isAndroid => Platform.isAndroid;

  /// Android 14 (API 34) altında bu icazə mövcud deyil — sistem
  /// avtomatik icazə verir, ona görə "grantedmiş kimi" true qaytarılır.
  static Future<bool> isFullScreenIntentGranted() async {
    if (!isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod<bool>('isFullScreenIntentGranted');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> openFullScreenIntentSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openFullScreenIntentSettings');
    } catch (_) {}
  }

  static Future<bool> isDndAccessGranted() async {
    if (!isAndroid) return true;
    try {
      final result = await _channel.invokeMethod<bool>('isDndAccessGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openDndAccessSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openDndAccessSettings');
    } catch (_) {}
  }
}
