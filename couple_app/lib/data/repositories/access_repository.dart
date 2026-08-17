import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin yoxlaması: iki mənbə —
/// 1) users/{uid}.role == 'admin' (birbaşa sənəd)
/// 2) adminAccess/config → adminUids siyahısı (fallback)
///
/// ƏSAS DƏYİŞİKLİK: Nəticəni 5 dəqiqə cache-ləyirik ki,
/// hər çağrıda Firestore-a getməyək.
class AccessRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  // Cache
  bool? _cachedIsAdmin;
  DateTime? _cachedAt;
  static const _cacheDuration = Duration(minutes: 5);

  AccessRepository({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    // Cache-dən qaytar (əgər vaxtı keçməyibsə)
    if (_cachedIsAdmin != null && _cachedAt != null) {
      if (DateTime.now().difference(_cachedAt!) < _cacheDuration) {
        return _cachedIsAdmin!;
      }
    }

    bool result = false;

    // 1) Birbaşa users sənədində role yoxla
    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final role = userDoc.data()?['role'] as String?;
        if (role == 'admin') result = true;
      }
    } catch (_) {}

    // 2) Fallback: adminAccess/config siyahısı
    if (!result) {
      try {
        final doc = await _db.collection('adminAccess').doc('config').get();
        if (doc.exists) {
          final adminUids = List<String>.from(doc.data()?['adminUids'] as List? ?? []);
          result = adminUids.contains(uid);
        }
      } catch (_) {}
    }

    // Cache-lə
    _cachedIsAdmin = result;
    _cachedAt = DateTime.now();

    return result;
  }

  /// Cache-i təmizlə (məs. çıxış edəndə)
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
