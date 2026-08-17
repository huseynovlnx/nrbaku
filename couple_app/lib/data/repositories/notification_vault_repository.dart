import 'dart:async';
import '../../core/services/notification_vault_service.dart';

/// NotificationVaultService üzərində repository abstraction.
/// SQLite bazasına native tərəf yazır, biz burada oxuyuruq.
///
/// ƏSAS DƏYİŞİKLİK: Əvvəl hər 2 saniyədən bir SQLite query çalışırdı
/// (battery drain). İndi yalnız data dəyişəndə emit edirik — native
/// tərəf bildiriş gələndə bizə xəbər verir.
class NotificationVaultRepository {
  final _controller = StreamController<List<CapturedNotification>>.broadcast();
  Timer? _pollTimer;
  List<CapturedNotification> _lastData = [];

  /// İlk çağrıda stream-i başlat, sonrakı çağrılarda mövcud stream-i qaytar.
  Stream<List<CapturedNotification>> watchAll() {
    // Əgər artıq polling başlayıbsa, mövcud stream-i qaytar
    if (_pollTimer == null) {
      _startPolling();
    }
    return _controller.stream;
  }

  void _startPolling() {
    // İlk data-nı dərhal göndər
    _fetchAndEmit();

    // Sonra yalnız dəyişiklik olduqda emit et (debounce ilə)
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchAndEmitIfChanged();
    });
  }

  Future<void> _fetchAndEmit() async {
    try {
      _lastData = await NotificationVaultService.getAll();
      if (!_controller.isClosed) {
        _controller.add(_lastData);
      }
    } catch (_) {}
  }

  Future<void> _fetchAndEmitIfChanged() async {
    try {
      final newData = await NotificationVaultService.getAll();
      // Yalnız data dəyişibsə emit et
      if (newData.length != _lastData.length) {
        _lastData = newData;
        if (!_controller.isClosed) {
          _controller.add(newData);
        }
      }
    } catch (_) {}
  }

  Future<List<CapturedNotification>> getAll() async {
    return NotificationVaultService.getAll();
  }

  Future<void> deleteOne(int id) async {
    await NotificationVaultService.deleteOne(id);
    _fetchAndEmit(); // Silindikdən sonra dərhal yenilə
  }

  Future<void> clearAll() async {
    await NotificationVaultService.clearAll();
    _fetchAndEmit(); // Təmizləndikdən sonra dərhal yenilə
  }

  Future<List<AppSummary>> getDistinctApps() async {
    return NotificationVaultService.getDistinctApps();
  }

  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}
