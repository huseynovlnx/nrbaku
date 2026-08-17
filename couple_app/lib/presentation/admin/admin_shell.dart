import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/fcm_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../providers/admin_chat_providers.dart';
import '../../providers/auth_providers.dart';
import '../settings/settings_screen.dart';
import 'admin_device_detail.dart';

/// Cihazlar siyahısı stream-i — bir dəfə yaradılır, bütün widget-lər paylaşır.
/// Hər rebuild-də yeni Stream yaratmaq əvəzinə, tək stream-i dinləyirik.
final devicesStreamProvider = StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('devices')
      .orderBy('updatedAt', descending: true)
      .snapshots();
});

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  @override
  void initState() {
    super.initState();
    _initFcm();
  }

  Future<void> _initFcm() async {
    final user = ref.read(userDocProvider).value;
    if (user == null) return;
    await FcmService.init(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NrBaku', style: AppTheme.heading(size: 18, spacing: 1.2)),
            const SizedBox(width: 6),
            const KartelBadge('PATRON'),
            const SizedBox(width: 8),
            PatronCursor(size: 8),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: const _DeviceListBody(),
    );
  }
}

class _DeviceListBody extends ConsumerWidget {
  const _DeviceListBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(devicesStreamProvider);

    return devicesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.purple),
      ),
      error: (e, _) => Center(
        child: Text('Xəta: $e', style: AppTheme.body(color: AppTheme.alert)),
      ),
      data: (snap) {
        final docs = snap.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('◆',
                    style: TextStyle(fontSize: 48, color: AppTheme.purple)),
                const SizedBox(height: 12),
                Text('HEÇ BİR CİHAZ TAPILMADI',
                    style: AppTheme.mono(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppTheme.purple)),
                const SizedBox(height: 6),
                Text('Cihazlar giriş edib bağlandıqda burada görünür',
                    style: AppTheme.body(size: 13, color: AppTheme.textDim)),
              ],
            ),
          );
        }

        final now = DateTime.now();
        final onlineCount = docs.where((d) {
          final updatedAt = (d.data()['updatedAt'] as Timestamp?)?.toDate();
          return updatedAt != null && now.difference(updatedAt).inMinutes < 10;
        }).length;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  _StatChip(
                    label: 'ONLAYN',
                    value: '$onlineCount',
                    color: AppTheme.purple,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'OFLAYN',
                    value: '${docs.length - onlineCount}',
                    color: AppTheme.alert,
                  ),
                  const SizedBox(width: 12),
                  _StatChip(
                    label: 'ÜMUMİ',
                    value: '${docs.length}',
                    color: AppTheme.textDim,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final data = docs[i].data();
                  final uid = docs[i].id;
                  return _DeviceCard(uid: uid, data: data);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.mono(size: 10, color: AppTheme.textDim)),
          const SizedBox(width: 4),
          Text(value,
              style: AppTheme.mono(
                  size: 11, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _DeviceCard extends ConsumerWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _DeviceCard({required this.uid, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = data['label'] as String? ?? uid.substring(0, 8);
    final battery = data['batteryLevel'] as int? ?? -1;
    final isCharging = data['isCharging'] as bool? ?? false;
    final isWifi = data['isWifi'] as bool? ?? false;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    final isOnline = updatedAt != null &&
        DateTime.now().difference(updatedAt).inMinutes < 10;

    final unreadAsync = ref.watch(adminUnreadCountProvider(uid));
    final unread = unreadAsync.value ?? 0;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDeviceDetail(uid: uid, label: label),
        ),
      ),
      borderRadius: BorderRadius.circular(4),
      child: KartelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? AppTheme.purple : AppTheme.alert,
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
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: AppTheme.mono(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppTheme.textMain),
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.alert,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unread',
                      style: AppTheme.mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right,
                    color: AppTheme.textDim, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusChip(
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
                _StatusChip(
                  icon: isWifi
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  label: isWifi ? 'WiFi' : 'Mobil',
                  color: isWifi ? AppTheme.purple : AppTheme.textDim,
                ),
                const Spacer(),
                if (updatedAt != null)
                  Text(
                    _formatTime(updatedAt),
                    style: AppTheme.mono(size: 11, color: AppTheme.textDim),
                  ),
              ],
            ),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 12, color: AppTheme.textDim.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: AppTheme.mono(
                        size: 10, color: AppTheme.textDim.withOpacity(0.6)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'indi';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dəq';
    if (diff.inHours < 24) return '${diff.inHours} saat';
    return DateFormat('d MMM').format(dt);
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip(
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
