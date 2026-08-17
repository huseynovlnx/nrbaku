import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/urgent_call_model.dart';

/// SOS sistemi hazırda gizlədilmişdir (UI-dan çıxarılıb).
/// Provider-lar compile xətası olmasın deyə saxlanılıb — boş stream qaytarır.

final incomingUrgentCallProvider = StreamProvider<UrgentCallModel?>((ref) {
  return const Stream.empty();
});

final myUrgentCallsProvider = StreamProvider<List<UrgentCallModel>>((ref) {
  return Stream.value(const []);
});

final newlyRespondedUrgentCallProvider =
    StreamProvider<UrgentCallModel>((ref) {
  return const Stream.empty();
});

class UrgentCallController extends StateNotifier<bool> {
  UrgentCallController() : super(false);
  Future<void> send({
    required String fromName,
    required String message,
  }) async {}
}

final urgentCallControllerProvider =
    StateNotifierProvider<UrgentCallController, bool>(
  (ref) => UrgentCallController(),
);
