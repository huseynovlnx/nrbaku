import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/reminder_alarm_service.dart';
import '../data/models/reminder_model.dart';
import '../data/repositories/reminder_repository.dart';
import 'auth_providers.dart';

final reminderRepositoryProvider =
    Provider((ref) => ReminderRepository());

final remindersProvider = StreamProvider<List<ReminderModel>>((ref) {
  final user = ref.watch(userDocProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(reminderRepositoryProvider).watchAll(user.uid);
});

class ReminderController extends StateNotifier<AsyncValue<void>> {
  final ReminderRepository _repo;
  ReminderController(this._repo) : super(const AsyncData(null));

  Future<void> add(ReminderModel reminder) async {
    state = const AsyncLoading();
    try {
      final id = await _repo.add(reminder);
      final fireAt = reminder.nextOccurrence();
      if (fireAt != null) {
        await ReminderAlarmService.schedule(
          id: id,
          title: reminder.title,
          body: reminder.isRecurringYearly
              ? 'Bu gün xüsusi gününüzdür 🎉'
              : 'Xatırladıcınızın vaxtı gəldi',
          dateTime: fireAt,
          recurringYearly: reminder.isRecurringYearly,
        );
      }
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> delete(String uid, String id) async {
    await ReminderAlarmService.cancel(id);
    await _repo.delete(uid, id);
  }

  Future<void> syncAlarms(List<ReminderModel> reminders) async {
    final items = <Map<String, dynamic>>[];
    for (final r in reminders) {
      final fireAt = r.nextOccurrence();
      if (fireAt == null) continue;
      items.add({
        'id': r.id,
        'title': r.title,
        'body': r.isRecurringYearly
            ? 'Bu gün xüsusi gününüzdür 🎉'
            : 'Xatırladıcınızın vaxtı gəldi',
        'dateTime': fireAt,
        'recurringYearly': r.isRecurringYearly,
      });
    }
    await ReminderAlarmService.syncAll(items);
  }
}

final reminderControllerProvider =
    StateNotifierProvider<ReminderController, AsyncValue<void>>(
  (ref) => ReminderController(ref.watch(reminderRepositoryProvider)),
);