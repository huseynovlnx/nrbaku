import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/urgent_call_model.dart';

class UrgentCallRepository {
  final Map<String, StreamSubscription> _subscriptions = {};
  final FirebaseFirestore _db;

  UrgentCallRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _items(String deviceUid) =>
      _db.collection('urgentCalls').doc(deviceUid).collection('items');

  Future<String> send({
    required String deviceUid,
    required String fromUid,
    required String fromName,
    required String toUid,
    required String message,
  }) async {
    final doc = await _items(deviceUid).add({
      'deviceUid': deviceUid,
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'message': message,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    });
    return doc.id;
  }

  Stream<UrgentCallModel?> watchIncoming({
    required String deviceUid,
    required String myUid,
  }) {
    _subscriptions['incoming_\$deviceUid']?.cancel();
    bool isFirst = true;
    final seenIds = <String>{};

    final stream = _items(deviceUid)
        .where('toUid', isEqualTo: myUid)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .asyncExpand<UrgentCallModel?>((snap) async* {
      if (isFirst) {
        isFirst = false;
        for (final d in snap.docs) {
          seenIds.add(d.id);
        }
        return;
      }
      for (final d in snap.docs) {
        if (seenIds.contains(d.id)) continue;
        seenIds.add(d.id);
        final data = d.data();
        if ((data['status'] as String? ?? 'pending') == 'pending') {
          yield UrgentCallModel.fromMap(d.id, data);
        }
      }
    });

    _subscriptions['incoming_\$deviceUid'] = stream.listen((_) {});
    return stream;
  }

  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  Stream<List<UrgentCallModel>> watchMine({
    required String deviceUid,
    required String myUid,
    int limit = 10,
  }) {
    return _items(deviceUid)
        .where('fromUid', isEqualTo: myUid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => UrgentCallModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> markResponded({
    required String deviceUid,
    required String callId,
  }) async {
    try {
      await _items(deviceUid).doc(callId).update({
        'status': 'responded',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Stream<UrgentCallModel?> watchNewlyResponded({
    required String deviceUid,
    required String myUid,
  }) {
    bool isFirst = true;
    final lastStatus = <String, String>{};

    return _items(deviceUid)
        .where('fromUid', isEqualTo: myUid)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .asyncExpand<UrgentCallModel?>((snap) async* {
      if (isFirst) {
        isFirst = false;
        for (final d in snap.docs) {
          lastStatus[d.id] = (d.data()['status'] as String? ?? 'pending');
        }
        return;
      }
      for (final d in snap.docs) {
        final data = d.data();
        final status = data['status'] as String? ?? 'pending';
        final prevStatus = lastStatus[d.id];
        lastStatus[d.id] = status;
        if (prevStatus != null &&
            prevStatus != 'responded' &&
            status == 'responded') {
          yield UrgentCallModel.fromMap(d.id, data);
        }
      }
    });
  }
}
