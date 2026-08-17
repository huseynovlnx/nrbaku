import 'dart:math';

/// Karışmaya açık karakterleri (0/O, 1/I/L) çıkararak
/// okunabilir 6 haneli eşleştirme kodu üretir.
class CodeGenerator {
  static const _chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static final _random = Random.secure();

  static String generatePairCode({int length = 6}) {
    return List.generate(
      length,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }
}
