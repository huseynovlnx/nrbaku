import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/access_repository.dart';
import 'auth_providers.dart';

final accessRepositoryProvider = Provider((ref) => AccessRepository());

final userRoleProvider = FutureProvider<UserRole>((ref) async {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (user) async {
      if (user == null) return UserRole.device;
      return await ref.watch(accessRepositoryProvider).getUserRole();
    },
    orElse: () => UserRole.device,
  );
});
