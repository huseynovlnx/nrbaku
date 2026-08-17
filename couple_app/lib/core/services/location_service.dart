import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../data/models/location_model.dart';
import '../utils/date_time_utils.dart';

class LocationService {
  final FirebaseFirestore _db;
  StreamSubscription<Position>? _sub;
  Position? _last;

  LocationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  Future<LocationPermission> checkStatus() async {
    return Geolocator.checkPermission();
  }

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return false;
    }
    if (perm == LocationPermission.deniedForever) return false;
    return true;
  }

  void startTracking(String uid) {
    _sub?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 15,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) => _write(uid, pos));
  }

  Future<void> _write(String uid, Position pos) async {
    if (_last != null) {
      final d = Geolocator.distanceBetween(
        _last!.latitude, _last!.longitude,
        pos.latitude, pos.longitude,
      );
      if (d < 15) return;
    }
    _last = pos;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    // Bütün 3 yazma əməliyyatını bir batch-də et — atomik, ya hamısı ya heç biri
    final batch = _db.batch();

    // 1) locations/{uid}
    final locRef = _db.collection('locations').doc(uid);
    batch.set(locRef, {
      'uid': uid,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2) devices/{uid}
    final devRef = _db.collection('devices').doc(uid);
    batch.set(devRef, {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3) devices/{uid}/route/{today}
    final routeRef = _db.collection('devices').doc(uid).collection('route').doc(today);
    batch.set(routeRef, {
      'points': FieldValue.arrayUnion([
        {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        }
      ]),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  void stopTracking() {
    _sub?.cancel();
    _sub = null;
    _last = null;
  }

  Future<Position?> getCurrent() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Stream<LocationModel?> watchPartner(String partnerUid) {
    return _db.collection('locations').doc(partnerUid).snapshots().map(
      (doc) => doc.exists
          ? LocationModel.fromMap(doc.id, doc.data()!)
          : null,
    );
  }

  Stream<LocationModel?> watchMyLocation(String uid) {
    return _db.collection('locations').doc(uid).snapshots().map(
      (doc) => doc.exists
          ? LocationModel.fromMap(doc.id, doc.data()!)
          : null,
    );
  }

  static double distanceKm(
      double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  static String formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  static String formatLastSeen(DateTime dt) {
    return DateTimeUtils.formatLastSeen(dt);
  }

  static String formatLastSeenLocation(DateTime dt) {
    return DateTimeUtils.formatLastSeen(dt);
  }
}
