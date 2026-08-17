import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/admin_message_model.dart';
import '../data/repositories/admin_chat_repository.dart';
import 'auth_providers.dart';

final adminChatRepositoryProvider =
    Provider<AdminChatRepository>((ref) => AdminChatRepository());

/// Seçilmiş cihaz ilə mesaj axını
final adminMessagesProvider =
    StreamProvider.family<List<AdminMessage>, String>((ref, deviceUid) {
  return ref.watch(adminChatRepositoryProvider).watchMessages(deviceUid);
});

/// Cihazın admin ilə oxunmamış mesaj sayı (admin tərəf üçün)
final adminUnreadCountProvider =
    StreamProvider.family<int, String>((ref, deviceUid) {
  return ref
      .watch(adminChatRepositoryProvider)
      .watchUnreadCount(deviceUid: deviceUid, forAdmin: true);
});

/// Cihaz tərəfi — admindən gələn oxunmamış mesaj sayı
final deviceUnreadCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(userDocProvider).value;
  if (user == null) return Stream.value(0);
  return ref
      .watch(adminChatRepositoryProvider)
      .watchUnreadCount(deviceUid: user.uid, forAdmin: false);
});

class AdminChatController extends StateNotifier<AsyncValue<void>> {
  final AdminChatRepository _repo;
  AdminChatController(this._repo) : super(const AsyncData(null));

  Future<void> send({
    required String deviceUid,
    required String text,
    required String senderUid,
    required bool isFromAdmin,
  }) async {
    if (text.trim().isEmpty) return;
    state = const AsyncLoading();
    try {
      await _repo.sendMessage(
        deviceUid: deviceUid,
        text: text,
        senderUid: senderUid,
        isFromAdmin: isFromAdmin,
      );
      state = const AsyncData(null);
    } catch (e, s) {
      state = AsyncError(e, s);
    }
  }

  Future<void> markRead({
    required String deviceUid,
    required bool readByAdmin,
  }) async {
    try {
      await _repo.markRead(deviceUid: deviceUid, readByAdmin: readByAdmin);
    } catch (_) {}
  }
}

final adminChatControllerProvider =
    StateNotifierProvider<AdminChatController, AsyncValue<void>>(
  (ref) => AdminChatController(ref.watch(adminChatRepositoryProvider)),
);
