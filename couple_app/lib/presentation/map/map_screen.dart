import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/permission_explainer.dart';
import '../../providers/location_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapCtrl = MapController();
  bool _permissionGranted = false;
  bool _initiated = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final svc = ref.read(locationServiceProvider);
    final status = await svc.checkStatus();
    if (status == LocationPermission.denied && mounted) {
      await showPermissionExplainer(
        context: context,
        icon: Icons.location_on_rounded,
        title: 'Konum icazəsi lazımdır',
        description:
            'Partnerinizlə canlı konum paylaşa bilmək üçün açılan pəncərədə '
            '"İcazə ver" seçimini edin.',
      );
    }
    final granted = await svc.requestPermission();
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
    // QEYD: burada bilərəkdən `svc.startTracking()` ÇAĞIRILMIR. Yer izləmənin
    // başladılıb-dayandırılması TƏK bir yerdə (home_screen.dart) idarə
    // olunur — çünki native arxa-plan xidməti ilə Dart axını arasında
    // seçim orada edilir. Bu ekranın işi yalnız icazə istəmək/göstərməkdir;
    // əgər burada da startTracking() çağırılsaydı, iki paralel yazıcı
    // problemi (əvvəllər düzəldilmiş) sükutla geri qayıdardı.
  }

  void _fitBoth(LatLng a, LatLng b) {
    final centerLat = (a.latitude + b.latitude) / 2;
    final centerLng = (a.longitude + b.longitude) / 2;
    _mapCtrl.move(LatLng(centerLat, centerLng), 12);
  }

  @override
  Widget build(BuildContext context) {
    final myLoc = ref.watch(myLocationProvider).value;
    final partnerLoc = ref.watch(partnerLocationProvider).value;
    final distance = ref.watch(distanceProvider);

    final myLatLng =
        myLoc != null ? LatLng(myLoc.lat, myLoc.lng) : null;
    final partnerLatLng =
        partnerLoc != null ? LatLng(partnerLoc.lat, partnerLoc.lng) : null;

    // İlk konum gəldikdə xəritəni ora köçür
    if (!_initiated && myLatLng != null) {
      _initiated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(myLatLng, 14);
      });
    }

    return Stack(
      children: [
        // ── Xəritə ────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: myLatLng ?? const LatLng(40.4093, 49.8671),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.couple.app',
            ),

            // Məsafə xətti
            if (myLatLng != null && partnerLatLng != null)
              PolylineLayer<Object>(
                polylines: [
                  Polyline(
                    points: [myLatLng, partnerLatLng],
                    color: AppTheme.purple.withValues(alpha: 0.5),
                    strokeWidth: 2.5,
                  ),
                ],
              ),

            // Markerlər
            MarkerLayer(
              markers: [
                if (myLatLng != null)
                  Marker(
                    point: myLatLng,
                    width: 60,
                    height: 70,
                    child: const _UserMarker(
                      label: 'Sən',
                      color: AppTheme.purple,
                      icon: Icons.person_rounded,
                    ),
                  ),
                if (partnerLatLng != null)
                  Marker(
                    point: partnerLatLng,
                    width: 70,
                    height: 70,
                    child: const _UserMarker(
                      label: 'Partner',
                      color: AppTheme.pink,
                      icon: Icons.favorite_rounded,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // ── Konum icazəsi yoxdur ───────────────────────────────────────────
        if (!_permissionGranted)
          _PermissionBanner(onRetry: _initLocation),

        // ── Yuxarı məsafə kartı ────────────────────────────────────────────
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: _DistanceCard(
            distance: distance,
            partnerLastSeen: partnerLoc?.updatedAt,
            partnerOnline: partnerLoc != null &&
                DateTime.now()
                        .difference(partnerLoc.updatedAt)
                        .inMinutes <
                    2,
          ),
        ),

        // ── FAB düymələri ──────────────────────────────────────────────────
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (myLatLng != null && partnerLatLng != null)
                _MapFab(
                  icon: Icons.zoom_out_map,
                  tooltip: 'İkisini göstər',
                  color: AppTheme.purple,
                  onTap: () => _fitBoth(myLatLng, partnerLatLng),
                ),
              const SizedBox(height: 10),
              if (myLatLng != null)
                _MapFab(
                  icon: Icons.my_location,
                  tooltip: 'Konumum',
                  color: AppTheme.purple,
                  onTap: () => _mapCtrl.move(myLatLng, 15),
                ),
              const SizedBox(height: 10),
              if (partnerLatLng != null)
                _MapFab(
                  icon: Icons.favorite_rounded,
                  tooltip: 'Partner',
                  color: AppTheme.pink,
                  onTap: () => _mapCtrl.move(partnerLatLng, 15),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final double? distance;
  final DateTime? partnerLastSeen;
  final bool partnerOnline;

  const _DistanceCard({
    this.distance,
    this.partnerLastSeen,
    required this.partnerOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  distance != null
                      ? LocationService.formatDistance(distance!)
                      : 'Konum yüklənir...',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.purple,
                  ),
                ),
                Text(
                  'aranızdakı məsafə',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          partnerOnline ? AppTheme.pink : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    partnerOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: partnerOnline ? AppTheme.pink : Colors.grey,
                    ),
                  ),
                ],
              ),
              if (partnerLastSeen != null && !partnerOnline)
                Text(
                  LocationService.formatLastSeen(partnerLastSeen!),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserMarker extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _UserMarker(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 2),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

class _MapFab extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _MapFab(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.white),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Konum icazəsi lazımdır',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: onRetry,
              style:
                  TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('İcazə ver'),
            ),
          ],
        ),
      ),
    );
  }
}
