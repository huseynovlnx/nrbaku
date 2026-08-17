import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Chrome URL Accessibility Service-in aktiv olub-olmadığını yoxlamaq və
/// Ayarlar ekranına yönləndirmək üçün native körpü.
class ChromeAccessibilityService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/chrome_accessibility');

  static bool get isAndroid => Platform.isAndroid;

  static Future<bool> isEnabled() async {
    if (!isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }
}
