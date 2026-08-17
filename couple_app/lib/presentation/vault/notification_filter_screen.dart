import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/notification_vault_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';
import '../../providers/notification_sharing_providers.dart';

/// Hansı tətbiqlərin bildirişlərinin paylaşılacağını seçmək üçün ekran.
/// Bank/OTP kimi həssas tətbiqlər default olaraq istisna edilir.
class NotificationFilterScreen extends ConsumerStatefulWidget {
  const NotificationFilterScreen({super.key});

  @override
  ConsumerState createState() => _NotificationFilterScreenState();
}

class _NotificationFilterScreenState
    extends ConsumerState<NotificationFilterScreen> {
  bool _loading = true;
  List<AppSummary> _apps = [];
  late Set<String> _excluded;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userDocProvider).value;
    _excluded = user?.notificationExcludedPackages.toSet() ?? {};
    _load();
  }

  Future<void> _load() async {
    final apps = await NotificationVaultService.getDistinctApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = ref.read(userDocProvider).value;
    if (user == null) return;
    await ref
        .read(sharedNotificationRepositoryProvider)
        .setExcludedPackages(user.uid, _excluded.toList());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FİLTRƏ', style: AppTheme.heading(size: 18)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Yadda saxla',
                style: AppTheme.mono(
                    size: 13, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.purple))
          : _apps.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._apps.map((app) => _buildAppTile(app)),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _buildAppTile(AppSummary app) {
    final isExcluded = _excluded.contains(app.packageName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: AppTheme.purple,
        title: Text(app.appLabel,
            style: AppTheme.body(size: 14, weight: FontWeight.w600)),
        subtitle: Text(app.packageName,
            style: AppTheme.mono(size: 10, color: AppTheme.textDim)),
        value: !isExcluded,
        onChanged: (shared) {
          setState(() {
            if (shared) {
              _excluded.remove(app.packageName);
            } else {
              _excluded.add(app.packageName);
            }
          });
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.apps_rounded,
                size: 56, color: AppTheme.textDim.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'Hələ heç bir tətbiqdən bildiriş toplanmayıb, '
              'ona görə filtrləmək üçün siyahı boşdur.',
              textAlign: TextAlign.center,
              style: AppTheme.body(size: 14, color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
