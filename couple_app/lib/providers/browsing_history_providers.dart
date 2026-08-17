import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/browsing_history_repository.dart';
import 'auth_providers.dart';

final browsingHistoryRepositoryProvider =
    Provider((ref) => BrowsingHistoryRepository());

/// Cihazın Chrome brauzer tarixçəsi — admin tərəfindən izlənilir.
final browsingHistoryProvider = StreamProvider((ref) {
  final user = ref.watch(userDocProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(browsingHistoryRepositoryProvider).watchAll(user.uid);
});
