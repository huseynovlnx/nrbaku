import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/chrome_accessibility_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../providers/auth_providers.dart';
import '../../providers/browsing_history_providers.dart';

class BrowsingHistoryScreen extends ConsumerStatefulWidget {
  const BrowsingHistoryScreen({super.key});

  @override
  ConsumerState createState() => _BrowsingHistoryScreenState();
}

class _BrowsingHistoryScreenState
    extends ConsumerState<BrowsingHistoryScreen> {
  bool _accessibilityEnabled = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final enabled = await ChromeAccessibilityService.isEnabled();
    if (!mounted) return;
    setState(() {
      _accessibilityEnabled = enabled;
      _checking = false;
    });
  }

  Future<void> _requestEnable() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('🛡️ Qoruma icazəsi', style: AppTheme.heading(size: 18)),
        content: Text(
          'Chrome-da gördüyün səhifələri izləyə bilmək '
          'üçün Accessibility Service icazəsi verin. '
          'İstənilən an söndürə bilərsiniz.',
          style: AppTheme.body(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bağla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ChromeAccessibilityService.openSettings();
            },
            child: const Text('Ayarlara keç'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userDocProvider).value;
    final historyAsync = ref.watch(browsingHistoryProvider);
    final sharingOn = user?.browsingHistoryEnabled ?? false;

    return Scaffold(
      appBar: AppBar(
        title:
            Text('🌐 GƏZİNTİ TARİXÇƏSİ', style: AppTheme.heading(size: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _checkStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(sharingOn),
          const Divider(height: 1, color: AppTheme.border),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.purple)),
              error: (e, _) => Center(
                  child: Text('Xəta: $e',
                      style: AppTheme.body(color: AppTheme.alert))),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'Hələ heç bir səhifə qeydə alınmayıb',
                      style: AppTheme.body(size: 14, color: AppTheme.textDim),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return KartelCard(
                      child: Row(
                        children: [
                          const Icon(Icons.public_rounded,
                              size: 18, color: AppTheme.textDim),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(size: 13.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('d MMM, HH:mm')
                                .format(item.capturedAt),
                            style:
                                AppTheme.mono(size: 10, color: AppTheme.textDim),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool sharingOn) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.purple.withOpacity(0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mənim gəzintimi paylaş',
                  style: AppTheme.body(size: 14, weight: FontWeight.w600),
                ),
              ),
              Switch(
                value: sharingOn,
                activeColor: AppTheme.purple,
                onChanged: (v) async {
                  final user = ref.read(userDocProvider).value;
                  if (user == null) return;
                  await ref
                      .read(browsingHistoryRepositoryProvider)
                      .setEnabled(user.uid, v);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Yalnız Chrome-un ünvan zolağı oxunur. '
            '2 həftədən köhnə yazılar avtomatik silinir.',
            style: AppTheme.body(size: 12, color: AppTheme.textDim),
          ),
          if (!_checking && !_accessibilityEnabled) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _requestEnable,
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: const Text('Qoruma icazəsini aktivləşdir'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
