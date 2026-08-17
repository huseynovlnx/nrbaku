import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/notification_vault_repository.dart';
import '../data/repositories/shared_notification_repository.dart';

final notificationVaultRepositoryProvider =
    Provider((ref) => NotificationVaultRepository());

final sharedNotificationRepositoryProvider =
    Provider((ref) => SharedNotificationRepository());

/// Cihazın öz bildiriş vault-u — lokal SQLite, uid əsasında filtrləmə yoxdur
/// (hər cihaz öz lokal bazasına yazır).
final notificationVaultProvider = StreamProvider((ref) {
  return ref.watch(notificationVaultRepositoryProvider).watchAll();
});
