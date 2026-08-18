import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/admin_message_model.dart';

class AdminChatRepository {
  final FirebaseFirestore _db;

  AdminChatRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _msgs(String deviceUid) =>
      _db.collection('adminChats').doc(deviceUid).collection('messages');

  Stream<List<AdminMessage>> watchMessages(String deviceUid) {
    return _msgs(deviceUid)
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AdminMessage.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> sendMessage({
    required String deviceUid,
    required String text,
    required String senderUid,
    required bool isFromAdmin,
  }) async {
    await _msgs(deviceUid).add(AdminMessage(
      id: '',
      text: text.trim(),
      senderUid: senderUid,
      isFromAdmin: isFromAdmin,
      timestamp: DateTime.now(),
    ).toMap());
  }

  Future<void> markRead({
    required String deviceUid,
    required bool readByAdmin,
  }) async {
    final snap = await _msgs(deviceUid)
        .where('isRead', isEqualTo: false)
        .where('isFromAdmin', isEqualTo: !readByAdmin)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Stream<int> watchUnreadCount({
    required String deviceUid,
    required bool forAdmin,
  }) {
    return _msgs(deviceUid)
        .where('isRead', isEqualTo: false)
        .where('isFromAdmin', isEqualTo: !forAdmin)
        .snapshots()
        .map((s) => s.docs.length);
  }
}
