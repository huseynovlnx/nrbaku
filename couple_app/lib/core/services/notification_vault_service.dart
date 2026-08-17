import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Telefona gələn bütün bildirişləri (istənilən tətbiqdən) yerli SQLite
/// bazasından oxuyan xidmət. Bildirişlərin özü native tərəfdə
/// (NotificationVaultListener.kt) tutulub eyni baza faylına yazılır;
/// burada sadəcə oxuyuruq/silirik — heç bir buluda göndərilmir.
class CapturedNotification {
  final int id;
  final String packageName;
  final String appLabel;
  final String title;
  final String text;
  final DateTime postedAt;
  final bool synced;

  CapturedNotification({
    required this.id,
    required this.packageName,
    required this.appLabel,
    required this.title,
    required this.text,
    required this.postedAt,
    this.synced = false,
  });

  factory CapturedNotification.fromMap(Map<String, dynamic> m) {
    return CapturedNotification(
      id: m['id'] as int,
      packageName: m['package_name'] as String,
      appLabel: m['app_label'] as String,
      title: m['title'] as String,
      text: m['text'] as String,
      postedAt: DateTime.fromMillisecondsSinceEpoch(m['posted_at'] as int),
      synced: (m['synced'] as int? ?? 0) == 1,
    );
  }
}

/// Yerli cihazda görünən bir tətbiqin qısa təsviri (filtrləmə ekranı üçün).
class AppSummary {
  final String packageName;
  final String appLabel;
  const AppSummary({required this.packageName, required this.appLabel});
}

class NotificationVaultService {
  static const _channel =
      MethodChannel('com.example.private_couple_app/notification_vault');
  static const _dbName = 'notification_vault.db';
  static const _table = 'captured_notifications';

  /// iOS cihazıdır — bildiriş tutma funksiyaları işləməz (Apple qadağan
  /// edir). Hazırda tətbiq yalnız Android üçün fəal inkişaf olunur, iOS
  /// tərəfi sonraya saxlanılıb — bu getter yalnız kodun platform
  /// yoxlaması aparan hissələrini (permission_flow_runner və s.)
  /// pozmamaq üçündür.
  static bool get isIOS => Platform.isIOS;

  static Future<bool> isAccessEnabled() async {
    if (isIOS) return false;
    try {
      final result =
          await _channel.invokeMethod<bool>('isNotificationAccessEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// İstifadəçini birbaşa Android-in "Bildiriş girişi" ayarlarına yönləndirir.
  /// Bu addımı kod avtomatikləşdirə bilməz — istifadəçi əl ilə aktivləşdirməlidir.
  static Future<void> openAccessSettings() async {
    if (isIOS) return;
    const intent = AndroidIntent(
      action: 'android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS',
    );
    await intent.launch();
  }

  static Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(path, readOnly: false);
  }

  /// Bütün tutulmuş bildirişləri ən yenidən köhnəyə doğru qaytarır.
  static Future<List<CapturedNotification>> getAll() async {
    try {
      final db = await _openDb();
      final rows = await db.query(_table, orderBy: 'posted_at DESC');
      await db.close();
      return rows.map((r) => CapturedNotification.fromMap(r)).toList();
    } catch (_) {
      // Baza hələ yaranmayıb (heç bir bildiriş tutulmayıb) ola bilər
      return [];
    }
  }

  static Future<void> deleteOne(int id) async {
    try {
      final db = await _openDb();
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
      await db.close();
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final db = await _openDb();
      await db.delete(_table);
      await db.close();
    } catch (_) {}
  }

  /// Bank / OTP / kimlik təsdiqi kimi həssas tətbiqləri paylaşımdan
  /// avtomatik istisna etmək üçün açar sözlər (paket adında axtarılır).
  static const List<String> defaultSensitiveKeywords = [
    'shargia',
  ];

  static bool isLikelySensitive(String packageName) {
    final lower = packageName.toLowerCase();
    return defaultSensitiveKeywords.any((k) => lower.contains(k));
  }

  /// Cihazda görünən bütün fərqli tətbiqlərin siyahısı (filtrləmə ekranı üçün).
  static Future<List<AppSummary>> getDistinctApps() async {
    try {
      final db = await _openDb();
      final rows = await db.query(
        _table,
        columns: ['package_name', 'app_label'],
        groupBy: 'package_name',
        orderBy: 'app_label ASC',
      );
      await db.close();
      return rows
          .map((r) => AppSummary(
                packageName: r['package_name'] as String,
                appLabel: r['app_label'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Hələ partnerlə sinxronlaşdırılmamış, [excludedPackages] siyahısında
  /// olmayan bildirişləri qaytarır.
  static Future<List<CapturedNotification>> getUnsyncedForSharing(
      Set<String> excludedPackages) async {
    try {
      final db = await _openDb();
      final rows = await db.query(
        _table,
        where: 'synced = 0',
        orderBy: 'posted_at ASC',
      );
      await db.close();
      return rows
          .map((r) => CapturedNotification.fromMap(r))
          .where((n) => !excludedPackages.contains(n.packageName))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Firestore-a paylaşılmış bildirişləri "sinxronlaşdırılmış" kimi işarələyir.
  /// İstisna siyahısına düşənlər BURAYA daxil edilmir — beləliklə istifadəçi
  /// sonradan bir tətbiqi istisna siyahısından çıxarsa, köhnə bildirişlər
  /// təbii şəkildə paylaşıla bilər.
  static Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await _openDb();
      final batch = db.batch();
      for (final id in ids) {
        batch.update(_table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
      await db.close();
    } catch (_) {}
  }
}
