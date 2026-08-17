import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/access_repository.dart';
import 'auth_providers.dart';

final accessRepositoryProvider =
    Provider((ref) => AccessRepository());

/// Cari istifadəçinin rolunu canlı (async) olaraq verir.
/// authStateProvider dəyişəndə (giriş/çıxış) yenidən hesablanır.
final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (user) {
      if (user == null) return Future.value(UserRole.device);
      return ref.watch(accessRepositoryProvider).getUserRole();
    },
    orElse: () => Future.value(UserRole.device),
  );
});
