import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../data/models/reminder_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/reminder_providers.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('ƏMƏLIYYATLAR', style: AppTheme.heading(size: 18, spacing: 1.2)),
      ),
      body: remindersAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.purple)),
        error: (e, _) => Center(
            child: Text('Xəta: $e', style: AppTheme.body(color: AppTheme.alert))),
        data: (reminders) {
          if (reminders.isEmpty) {
            return const _EmptyState();
          }
          final sorted = [...reminders]
            ..sort((a, b) {
              final an = a.nextOccurrence() ?? a.dateTime;
              final bn = b.nextOccurrence() ?? b.dateTime;
              return an.compareTo(bn);
            });
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: sorted.length,
            itemBuilder: (context, i) => _ReminderTile(reminder: sorted[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.purple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: AppTheme.border),
        ),
        child: const Icon(Icons.add_alarm_rounded),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddReminderSheet(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('◆',
              style: TextStyle(fontSize: 48, color: AppTheme.purple)),
          const SizedBox(height: 12),
          Text(
            'ƏMƏLIYYAT SİYAHISI BOŞ',
            style: AppTheme.mono(
                size: 14,
                weight: FontWeight.w700,
                color: AppTheme.purple),
          ),
          const SizedBox(height: 6),
          Text(
            'Aşağıdakı düymə ilə xatırladıcı əlavə edin',
            style: AppTheme.body(size: 13, color: AppTheme.textDim),
          ),
        ],
      ),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  final ReminderModel reminder;
  const _ReminderTile({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fireAt = reminder.nextOccurrence();
    final isPast = fireAt == null;
    final user = ref.read(userDocProvider).value;

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.alert.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        if (user != null) {
          ref
              .read(reminderControllerProvider.notifier)
              .delete(user.uid, reminder.id);
        }
      },
      child: KartelCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.gradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                reminder.isRecurringYearly
                    ? Icons.cake_rounded
                    : Icons.alarm_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: AppTheme.body(
                        size: 15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isPast
                        ? 'Keçmiş'
                        : DateFormat('d MMM • HH:mm').format(fireAt),
                    style: AppTheme.body(size: 13, color: AppTheme.textDim),
                  ),
                ],
              ),
            ),
            if (reminder.isRecurringYearly)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('Hər il',
                    style: AppTheme.mono(
                        size: 11, color: AppTheme.purple)),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet();

  @override
  ConsumerState<_AddReminderSheet> createState() =>
      _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _titleCtrl = TextEditingController();
  DateTime? _dateTime;
  bool _recurringYearly = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _dateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty || _dateTime == null || _saving) return;
    final user = ref.read(userDocProvider).value;
    if (user == null) return;

    setState(() => _saving = true);

    final reminder = ReminderModel(
      id: '',
      uid: user.uid,
      title: _titleCtrl.text.trim(),
      dateTime: _dateTime!,
      isRecurringYearly: _recurringYearly,
      createdBy: user.uid,
      createdAt: DateTime.now(),
    );

    await ref.read(reminderControllerProvider.notifier).add(reminder);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(4)),
          border: const Border(
            top: BorderSide(color: AppTheme.border),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'YENİ ƏMƏLIYYAT',
              style: AppTheme.heading(size: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              style: AppTheme.body(size: 15),
              decoration: const InputDecoration(labelText: 'Əməliyyat adı'),
              autofocus: true,
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_outlined,
                        color: AppTheme.purple, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _dateTime != null
                          ? DateFormat('d MMM yyyy • HH:mm')
                              .format(_dateTime!)
                          : 'Tarix və saat seç',
                      style: AppTheme.body(
                          size: 14,
                          color: _dateTime != null
                              ? AppTheme.textMain
                              : AppTheme.textDim),
                    ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              title: Text('Hər il təkrarla (illik)',
                  style: AppTheme.body(size: 14)),
              subtitle: Text('Doğum günü, ildönümü və s. üçün',
                  style: AppTheme.body(size: 12, color: AppTheme.textDim)),
              value: _recurringYearly,
              onChanged: (v) => setState(() => _recurringYearly = v),
              contentPadding: EdgeInsets.zero,
              activeColor: AppTheme.purple,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'İŞLƏNİR...' : 'ƏMƏLIYYATI TƏSDİQLƏ',
                  style: AppTheme.mono(size: 13, weight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
