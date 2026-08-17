import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../providers/admin_chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../device/device_chat_screen.dart';

class AdminDeviceDetail extends ConsumerStatefulWidget {
  final String uid;
  final String label;
  const AdminDeviceDetail({super.key, required this.uid, required this.label});

  @override
  ConsumerState<AdminDeviceDetail> createState() => _AdminDeviceDetailState();
}

class _AdminDeviceDetailState extends ConsumerState<AdminDeviceDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabCtrl.index == 1) {
      ref.read(adminChatControllerProvider.notifier).markRead(
        deviceUid: widget.uid,
        readByAdmin: true,
      );
    }
  }

  Future<void> _editLabel(BuildContext context) async {
    final ctrl = TextEditingController(text: widget.label);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Cihaz adını dəyiş', style: AppTheme.heading(size: 18)),
        content: TextField(
          controller: ctrl,
          style: AppTheme.body(size: 15),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Yeni ad'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Ləğv et'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 42)),
            child: const Text('Saxla'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(widget.uid)
          .set({'label': result}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadAsync = ref.watch(adminUnreadCountProvider(widget.uid));
    final unread = unreadAsync.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.label.toUpperCase(),
                style: AppTheme.heading(size: 17)),
            const SizedBox(width: 8),
            const KartelBadge('İZLƏMƏ'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Ad dəyiş',
            onPressed: () => _editLabel(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.purple,
          labelColor: AppTheme.purple,
          unselectedLabelColor: AppTheme.textDim,
          tabs: [
            const Tab(text: 'MƏKAN'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ƏLAQƏ'),
                  if (unread > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.alert,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$unread',
                          style: AppTheme.mono(
                              size: 10,
                              weight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Məkan tab ──
          _LocationTab(uid: widget.uid, mapController: _mapController),

          // ── Chat tab ──
          DeviceChatScreen(deviceUid: widget.uid, isAdmin: true),
        ],
      ),
    );
  }
}

class _LocationTab extends StatelessWidget {
  final String uid;
  final MapController mapController;
  const _LocationTab({required this.uid, required this.mapController});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('devices')
          .doc(uid)
          .snapshots(),
      builder: (context, deviceSnap) {
        final deviceData = deviceSnap.data?.data() ?? {};
        final lat = (deviceData['lat'] as num?)?.toDouble();
        final lng = (deviceData['lng'] as num?)?.toDouble();
        final battery = deviceData['batteryLevel'] as int? ?? -1;
        final isCharging = deviceData['isCharging'] as bool? ?? false;
        final isWifi = deviceData['isWifi'] as bool? ?? false;
        final updatedAt = (deviceData['updatedAt'] as Timestamp?)?.toDate();
        final isOnline = updatedAt != null &&
            DateTime.now().difference(updatedAt).inMinutes < 10;

        return Column(
          children: [
            // Status zolağı
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                    bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  // Onlayn/oflayn indikator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? AppTheme.purple : AppTheme.textDim,
                      boxShadow: isOnline
                          ? [
                              BoxShadow(
                                color: AppTheme.purple.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    icon: isCharging
                        ? Icons.bolt
                        : Icons.battery_full_rounded,
                    label: battery >= 0 ? '$battery%' : '—',
                    color: battery < 20
                        ? AppTheme.alert
                        : battery < 50
                            ? AppTheme.warning
                            : AppTheme.purple,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    icon: isWifi
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded,
                    label: isWifi ? 'WiFi' : 'Mobil',
                    color: isWifi ? AppTheme.purple : AppTheme.textDim,
                  ),
                  const Spacer(),
                  if (updatedAt != null)
                    Text(
                      _fmtLastSeen(updatedAt),
                      style: AppTheme.mono(size: 11, color: AppTheme.textDim),
                    ),
                ],
              ),
            ),

            // Xəritə + marşrut
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('devices')
                    .doc(uid)
                    .collection('route')
                    .doc(DateFormat('yyyy-MM-dd').format(DateTime.now()))
                    .snapshots(),
                builder: (context, routeSnap) {
                  final routeData = routeSnap.data?.data() ?? {};
                  final rawPoints = routeData['points'] as List? ?? [];
                  final routePoints = rawPoints
                      .map((p) {
                        final m = p as Map<String, dynamic>;
                        final la = (m['lat'] as num?)?.toDouble();
                        final lo = (m['lng'] as num?)?.toDouble();
                        if (la == null || lo == null) return null;
                        return LatLng(la, lo);
                      })
                      .whereType<LatLng>()
                      .toList();

                  final center = lat != null && lng != null
                      ? LatLng(lat, lng)
                      : const LatLng(40.4093, 49.8671); // Bakı default

                  return FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.nrbaku.monitor',
                      ),
                      if (routePoints.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              color: AppTheme.purple.withOpacity(0.8),
                              strokeWidth: 3,
                            ),
                          ],
                        ),
                      if (lat != null && lng != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.purple,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.bg, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.purple
                                          .withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on,
                                    color: AppTheme.bg, size: 22),
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Son görünmə vaxtını insana oxunaqlı formada formatlayır.
  String _fmtLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'indi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dəq əvvəl';
    if (diff.inHours < 24) return '${diff.inHours} saat əvvəl';
    if (diff.inDays < 7) return '${diff.inDays} gün əvvəl';
    return DateFormat('d MMM yyyy, HH:mm').format(dt);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTheme.mono(size: 11, color: color)),
        ],
      ),
    );
  }
}
