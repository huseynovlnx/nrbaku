import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccessRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  bool? _cachedIsAdmin;
  DateTime? _cachedAt;
  static const _cacheDuration = Duration(minutes: 5);

  AccessRepository({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    if (_cachedIsAdmin != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) < _cacheDuration) {
        return _cachedIsAdmin!;
      }
    }

    bool result = false;

    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final role = userDoc.data()?['role'] as String?;
        if (role == 'admin') result = true;
      }
    } catch (_) {}

    if (!result) {
      try {
        final doc = await _db.collection('adminAccess').doc('config').get();
        if (doc.exists) {
          final adminUids = List<dynamic>.from(doc.data()?['adminUids'] as List? ?? []);
          result = adminUids.contains(uid);
        }
      } catch (_) {}
    }

    _cachedIsAdmin = result;
    _cachedAt = DateTime.now();

    return result;
  }

  void clearCache() {
    _cachedIsAdmin = null;
    _cachedAt = null;
  }

  Future<UserRole> getUserRole() async {
    if (await isAdmin()) return UserRole.admin;
    return UserRole.device;
  }
}

enum UserRole {
  admin,
  device,
}
