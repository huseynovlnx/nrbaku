import 'package:intl/intl.dart';

/// Tarih/saat formatlama için ortak utility sınıfı.
/// Kod tekrarını önlemek ve tutarlı davranış sağlamak için kullanılır.
class DateTimeUtils {
  /// Son görülme zamanını insan dostu formatta döndürür.
  /// 
  /// Kullanım:
  /// - Chat app bar'ında partnerin çevrimiçi durumu
  /// - Harita ekranında partnerin son konum güncellemesi
  /// 
  /// Format:
  /// - < 60 saniye: "indi"
  /// - < 60 dakika: "X dəq. əvvəl"
  /// - < 24 saat: "HH:mm" (örn: "14:30")
  /// - ≥ 24 saat: "d MMM HH:mm" (örn: "15 İyul 14:30")
  static String formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'indi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dəq. əvvəl';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    return DateFormat('d MMM HH:mm').format(dt);
  }

  /// Mesaj zaman damgasını formatlar (chat balonlarında kullanılır).
  static String formatMessageTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  /// Tarih ayırıcı için formatlar (chat'te gün değişimlerinde).
  static String formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Bugün';
    }
    if (now.difference(dt).inDays == 1) {
      return 'Dünən';
    }
    return DateFormat('d MMM yyyy').format(dt);
  }
}