import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/location_service.dart';
import '../data/models/location_model.dart';
import '../data/repositories/event_repository.dart';
import 'auth_providers.dart';

final locationServiceProvider = Provider((ref) => LocationService());

final eventRepositoryProvider = Provider((ref) => EventRepository());

/// Cari istifadəçinin mövqeyi
final myLocationProvider = StreamProvider<LocationModel?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(locationServiceProvider).watchMyLocation(user.uid);
});

/// Seçilmiş cihazın mövqeyi (admin paneli üçün)
final partnerLocationProvider = StreamProvider.family<LocationModel?, String>(
  (ref, deviceUid) {
    if (deviceUid.isEmpty) return Stream.value(null);
    return ref.watch(locationServiceProvider).watchPartner(deviceUid);
  },
);

/// İki nöqtə arasındakı məsafə (km)
final distanceProvider = Provider.family<double?, String>((ref, deviceUid) {
  final myLoc = ref.watch(myLocationProvider).value;
  final partnerLoc = ref.watch(partnerLocationProvider(deviceUid)).value;

  if (myLoc == null || partnerLoc == null) return null;

  return LocationService.distanceKm(
    myLoc.lat,
    myLoc.lng,
    partnerLoc.lat,
    partnerLoc.lng,
  );
});

// Köhnə event bildiriş provider-i — SOS gizlədildiyi üçün passiv saxlanılır
final eventNotificationProvider = StreamProvider((ref) {
  return const Stream.empty();
});
