import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/location_service.dart';
import '../data/repositories/event_repository.dart';

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());

final eventRepositoryProvider =
    Provider<EventRepository>((ref) => EventRepository());

/// Partner mövqeyi artıq cütləşmə sistemi olmadığı üçün bu provider
/// yalnız admin panelinin xəritəsindən (AdminDeviceDetail) istifadə
/// edilir — birbaşa Firestore stream-i ilə oxunur, ayrıca provider
/// lazım deyil.
/// Bu fayl yalnız LocationService-i expose etmək üçün saxlanılıb.

// Köhnə event bildiriş provider-i — SOS gizlədildiyi üçün passiv saxlanılır
final eventNotificationProvider = StreamProvider<void>((ref) {
  return const Stream.empty();
});
