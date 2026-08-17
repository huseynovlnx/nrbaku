import 'package:flutter/services.dart';

/// Cihaz rejimindəki telefonun batareya, WiFi vəziyyətini Firestore-a
/// yazan native körpü. Mövcud `LocationTrackingService`-in yanında,
/// eyni arxa plan xidməti dövrəsinin içindən çağrılır.
///
/// Native tərəf üçün ayrıca bir Kotlin xidməti yazmaq əvəzinə,
/// tətbiq açıq olarkən (foreground) dövrəli yeniləmə edirik — bu,
/// "cihaz rejimi" üçün kifayətdir, çünki həmin telefonlar əsasən
/// davamlı işlənir (mağaza/anbar cihazları).
class DeviceReporterService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/device_reporter');

  static Future<Map<String, dynamic>> getDeviceStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getDeviceStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (_) {
      return {};
    }
  }
}
