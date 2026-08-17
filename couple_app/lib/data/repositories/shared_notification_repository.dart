import 'package:cloud_firestore/cloud_firestore.dart';

class SharedNotificationItem {
  final String id;
  final String ownerUid;
  final String packageName;
  final String appLabel;
  final String title;
  final String text;
  final DateTime postedAt;

  SharedNotificationItem({
    required this.id,
    required this.ownerUid,
    required this.packageName,
    required this.appLabel,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  factory SharedNotificationItem.fromMap(String id, Map<String, dynamic> m) {
    return SharedNotificationItem(
      id: id,
      ownerUid: m['ownerUid'] as String? ?? '',
      packageName: m['packageName'] as String? ?? '',
      appLabel: m['appLabel'] as String? ?? '',
      title: m['title'] as String? ?? '',
      text: m['text'] as String? ?? '',
      postedAt: (m['postedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Cihazın admin ilə paylaşdığı bildirişlərin Firestore anbarı.
/// Yol: sharedNotifications/{deviceUid}/items/{itemId}
///
/// KÖHNƏ: sharedNotifications/{pairId}/items/{itemId} (couple sistemi)
/// YENİ:  sharedNotifications/{deviceUid}/items/{itemId} (monitoring sistemi)
class SharedNotificationRepository {
  final FirebaseFirestore _db;
  SharedNotificationRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _items(String deviceUid) => _db
      .collection('sharedNotifications')
      .doc(deviceUid)
      .collection('items');

  Future<void> add({
    required String deviceUid,
    required String ownerUid,
    required String packageName,
    required String appLabel,
    required String title,
    required String text,
    required DateTime postedAt,
  }) async {
    await _items(deviceUid).add({
      'ownerUid': ownerUid,
      'packageName': packageName,
      'appLabel': appLabel,
      'title': title,
      'text': text,
      'postedAt': Timestamp.fromDate(postedAt),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<SharedNotificationItem>> watchAll(String deviceUid) {
    return _items(deviceUid)
        .orderBy('postedAt', descending: true)
        .limit(300)
        .snapshots()
        .map((s) => s.docs
            .map((d) => SharedNotificationItem.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> deleteItem(String deviceUid, String itemId) async {
    await _items(deviceUid).doc(itemId).delete();
  }

  /// Yalnız öz göndərdiyim paylaşılan bildirişləri silir.
  Future<void> clearMine(String deviceUid, String ownerUid) async {
    final snap =
        await _items(deviceUid).where('ownerUid', isEqualTo: ownerUid).get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// İstifadəçinin paylaşım aç/bağla vəziyyətini yeniləyir.
  Future<void> setSharingEnabled(String uid, bool enabled) async {
    await _db.collection('users').doc(uid).set(
      {'notificationSharingEnabled': enabled},
      SetOptions(merge: true),
    );
  }

  /// İstisna edilmiş (paylaşılmayan) tətbiqlərin paket adı siyahısını yeniləyir.
  Future<void> setExcludedPackages(String uid, List<String> packages) async {
    await _db.collection('users').doc(uid).set(
      {'notificationExcludedPackages': packages},
      SetOptions(merge: true),
    );
  }
}
