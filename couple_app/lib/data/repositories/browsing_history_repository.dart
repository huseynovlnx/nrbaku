import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/browsed_url_model.dart';

/// Brauzer tarixçəsi repository — uid əsasında (pairId silinib).
/// Kolleksiya: browsingHistory/{uid}/urls/{urlId}
class BrowsingHistoryRepository {
  final FirebaseFirestore _db;
  BrowsingHistoryRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _urls(String uid) =>
      _db.collection('browsingHistory').doc(uid).collection('urls');

  Stream<List<BrowsedUrlModel>> watchAll(String uid, {int limit = 200}) {
    return _urls(uid)
        .orderBy('capturedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BrowsedUrlModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> setEnabled(String uid, bool enabled) async {
    await _db.collection('users').doc(uid).set(
      {'browsingHistoryEnabled': enabled},
      SetOptions(merge: true),
    );
  }
}
