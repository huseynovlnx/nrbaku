import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/access_providers.dart';
import '../../providers/auth_providers.dart';
import '../vault/secret_pin_gate_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDoc = ref.watch(userDocProvider).value;
    final roleLabel = userDoc?.isAdmin == true ? 'PATRON (Admin)' : 'CİHAZ';
    final roleColor = userDoc?.isAdmin == true ? AppTheme.purple : AppTheme.textDim;

    return Scaffold(
      appBar: AppBar(
        title: const _SecretTapTitle(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: roleColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                roleLabel,
                style: AppTheme.mono(
                  size: 12,
                  weight: FontWeight.w700,
                  color: roleColor,
                  spacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          const _SectionHeader(title: 'HESAB'),
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'E-poçt',
            value: userDoc?.email ?? '—',
          ),
          _InfoTile(
            icon: Icons.fingerprint,
            label: 'Cihaz ID',
            value: userDoc?.uid ?? '—',
          ),
          _InfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Qeydiyyat tarixi',
            value: userDoc != null
                ? '${userDoc.createdAt.day}.${userDoc.createdAt.month}.${userDoc.createdAt.year}'
                : '—',
          ),
          const SizedBox(height: 24),

          const _SectionHeader(title: 'TƏHLÜKƏLİ BÖLGƏ'),
          _DangerTile(
            icon: Icons.logout,
            label: 'Çıxış et',
            color: AppTheme.alert,
            onTap: () async {
              ref.read(accessRepositoryProvider).clearCache();
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _SecretTapTitle extends StatefulWidget {
  const _SecretTapTitle();

  @override
  State<_SecretTapTitle> createState() => _SecretTapTitleState();
}

class _SecretTapTitleState extends State<_SecretTapTitle> {
  int _tapCount = 0;
  DateTime? _firstTapAt;

  void _onTap() {
    final now = DateTime.now();
    if (_firstTapAt == null ||
        now.difference(_firstTapAt!) > const Duration(seconds: 3)) {
      _firstTapAt = now;
      _tapCount = 1;
      return;
    }
    _tapCount++;
    if (_tapCount >= 5) {
      _tapCount = 0;
      _firstTapAt = null;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SecretPinGateScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: const Text('Ayarlar'),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTheme.mono(
          size: 12,
          weight: FontWeight.w700,
          color: AppTheme.textDim,
          spacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textDim, size: 22),
      title: Text(
        label,
        style: AppTheme.body(size: 13, color: AppTheme.textDim),
      ),
      subtitle: Text(
        value,
        style: AppTheme.mono(size: 14, color: AppTheme.textMain),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _DangerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _DangerTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: AppTheme.body(size: 15, color: color),
      ),
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
