import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/urgent_call_providers.dart';

/// Partnerə təcili çağırış göndərmək üçün mətn yazma ekranı.
/// Göndərilən mesaj partnerin telefonunda tam ekran + səs + vibrasiya
/// ilə göstərilir (fullScreenIntent bildirişi).
class SendUrgentCallScreen extends ConsumerStatefulWidget {
  const SendUrgentCallScreen({super.key});

  @override
  ConsumerState<SendUrgentCallScreen> createState() =>
      _SendUrgentCallScreenState();
}

class _SendUrgentCallScreenState extends ConsumerState<SendUrgentCallScreen> {
  final _controller = TextEditingController();
  static const _quickOptions = [
    'Zəng et',
    'Cavab ver',
    'Evə gəl',
    'Narahatam, yaz',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final ok =
        await ref.read(urgentCallControllerProvider.notifier).send(text);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚨 Göndərildi — partnerinin ekranında görünəcək'),
          backgroundColor: Color(0xFF4CD2A0),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Göndərilmədi, yenidən cəhd et'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sending = ref.watch(urgentCallControllerProvider);
    final myCallsAsync = ref.watch(myUrgentCallsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 Təcili Çağır'),
        flexibleSpace: const DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.gradient)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yazdığın mesaj partnerinin telefonunda tam ekran, '
                'səslə və vibrasiya ilə göstəriləcək.',
                style: TextStyle(color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickOptions
                    .map((q) => ActionChip(
                          label: Text(q),
                          onPressed: () => setState(() {
                            _controller.text = q;
                            _controller.selection = TextSelection.collapsed(
                                offset: q.length);
                          }),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                maxLines: 3,
                maxLength: 120,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Məs: Hüseyn müəllimə cavab verin',
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: sending ? null : _send,
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.campaign_rounded),
                  label: Text(sending ? 'Göndərilir...' : 'Göndər'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade200,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Son göndərdiklərim',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: myCallsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Xəta: $e')),
                  data: (calls) {
                    if (calls.isEmpty) {
                      return Center(
                        child: Text('Hələ heç nə göndərməmisən',
                            style: TextStyle(color: Colors.grey.shade500)),
                      );
                    }
                    return ListView.separated(
                      itemCount: calls.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = calls[i];
                        final responded = c.respondedAt != null;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                responded
                                    ? Icons.check_circle_rounded
                                    : Icons.hourglass_top_rounded,
                                color: responded
                                    ? const Color(0xFF4CD2A0)
                                    : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(c.message,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                      responded
                                          ? '✓ Cavab verdi: ${DateFormat('HH:mm').format(c.respondedAt!)}'
                                          : 'Gözlənilir...',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
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
        ),
      ),
    );
  }
}
