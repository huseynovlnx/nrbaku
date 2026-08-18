import 'dart:async';
import 'package:collection/collection.dart';
import '../../core/services/notification_vault_service.dart';

class NotificationVaultRepository {
  final _controller = StreamController<List<CapturedNotification>>.broadcast();
  Timer? _pollTimer;
  List<CapturedNotification> _lastData = [];

  Stream<List<CapturedNotification>> watchAll() {
    if (_pollTimer == null) {
      _startPolling();
    }
    return _controller.stream;
  }

  void _startPolling() {
    _fetchAndEmit();

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
      if (!const ListEquality<CapturedNotification>().equals(newData, _lastData)) {
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
    _fetchAndEmit();
  }

  Future<void> clearAll() async {
    await NotificationVaultService.clearAll();
    _fetchAndEmit();
  }

  Future<List<AppSummary>> getDistinctApps() async {
    return NotificationVaultService.getDistinctApps();
  }

  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}
