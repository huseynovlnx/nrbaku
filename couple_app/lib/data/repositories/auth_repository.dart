import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Stream<AppUser?> watchUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }

  Future<bool> isFirstUser() async {
    try {
      final snap = await _db.collection('users').limit(1).get();
      return snap.docs.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    UserCredential? cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = cred.user!.uid;
      final isFirst = await isFirstUser();
      final userData = {
        'email': cred.user!.email,
        'fcmToken': null,
        'createdAt': FieldValue.serverTimestamp(),
        'notificationSharingEnabled': true,
        'notificationExcludedPackages': <String>[],
        'browsingHistoryEnabled': true,
        'role': isFirst ? 'admin' : 'device',
      };

      try {
        await _db.collection('users').doc(uid).set(userData);
      } catch (firestoreError) {
        await cred.user?.delete();
        throw AuthFailure('Profil yaradıla bilmədi. Yenidən cəhd edin.');
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapError(e));
    } catch (e) {
      if (cred?.user != null) {
        try {
          await cred!.user!.delete();
        } catch (_) {}
      }
      throw AuthFailure('Xəta baş verdi: \$e');
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapError(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Bu e-poçt artıq qeydiyyatdan keçib.';
      case 'invalid-email':
        return 'Düzgün e-poçt daxil edin.';
      case 'weak-password':
        return 'Şifrə ən az 6 simvol olmalıdır.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-poçt və ya şifrə səhvdir.';
      case 'too-many-requests':
        return 'Çox sayda cəhd. Bir az gözləyin.';
      case 'network-request-failed':
        return 'İnternet bağlantısını yoxlayın.';
      default:
        return 'Xəta: \${e.message ?? e.code}';
    }
  }
}
