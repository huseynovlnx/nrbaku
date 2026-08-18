import 'package:intl/intl.dart';

/// Tarix/saat formatlama üçün ortaq utility sinfi.
/// Kod təkrarını önləmək və tutarlı davranış təmin etmək üçün istifadə olunur.
class DateTimeUtils {
  /// Son görülmə zamanını insan dostu formatda qaytarır.
  ///
  /// İstifadə:
  /// - Chat app bar'ında partnerin çevrimiçi durumu
  /// - Xəritə ekranında partnerin son konum yeniləməsi
  ///
  /// Format:
  /// - < 60 saniyə: "indi"
  /// - < 60 dəqiqə: "X dəq. əvvəl"
  /// - < 24 saat: "HH:mm" (məs: "14:30")
  /// - ≥ 24 saat: "d MMM HH:mm" (məs: "15 İyul 14:30")
  static String formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'indi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dəq. əvvəl';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    return DateFormat('d MMM HH:mm').format(dt);
  }

  /// Mesaj zaman damgasını formatlar (chat balonlarında istifadə olunur).
  static String formatMessageTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  /// Tarix ayırıcı üçün formatlar (chat'tə gün dəyişimlərində).
  static String formatDateDivider(DateTime dt) {
    final now = DateTime.now();
    // Bugün
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Bugün';
    }
    // Dünən (təqvim günü ilə müqayisə)
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Dünən';
    }
    return DateFormat('d MMM yyyy').format(dt);
  }
}
