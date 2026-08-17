import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

/// Firebase Auth oturumu
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Giriş edən istifadəçinin Firestore sənədi
final userDocProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.maybeWhen(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authRepositoryProvider).watchUser(user.uid);
    },
    orElse: () => Stream.value(null),
  );
});

enum AuthStatus { idle, loading, error }

class AuthController
    extends StateNotifier<({AuthStatus status, String? error})> {
  final AuthRepository _repo;
  AuthController(this._repo) : super((status: AuthStatus.idle, error: null));

  Future<bool> register(String email, String password) async {
    state = (status: AuthStatus.loading, error: null);
    try {
      await _repo.register(email: email, password: password);
      state = (status: AuthStatus.idle, error: null);
      return true;
    } catch (e) {
      state = (status: AuthStatus.error, error: e.toString());
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = (status: AuthStatus.loading, error: null);
    try {
      await _repo.signIn(email: email, password: password);
      state = (status: AuthStatus.idle, error: null);
      return true;
    } catch (e) {
      state = (status: AuthStatus.error, error: e.toString());
      return false;
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, ({AuthStatus status, String? error})>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
