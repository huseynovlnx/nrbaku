import 'package:flutter/services.dart';

/// Native `LocationTrackingService`-i idarə edən körpü. Bu, tətbiq bağlı
/// olsa belə yerin arxa planda (~2-3 dəqiqədə bir) güncəllənməsini təmin
/// edir — adi `LocationService`-dəki `Geolocator.getPositionStream` isə
/// yalnız tətbiq açıq olarkən işləyir (widget lifecycle-a bağlıdır).
class BackgroundLocationService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/location_tracking');

  static Future<bool> isBackgroundLocationGranted() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isBackgroundLocationGranted',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openBackgroundLocationSettings() async {
    try {
      await _channel.invokeMethod('openBackgroundLocationSettings');
    } catch (_) {}
  }

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startLocationTracking');
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopLocationTracking');
    } catch (_) {}
  }

  static Future<bool> isActive() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isLocationTrackingActive',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
