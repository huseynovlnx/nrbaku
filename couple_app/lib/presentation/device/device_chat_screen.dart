import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/terminal_fx.dart';
import '../../data/models/admin_message_model.dart';
import '../../providers/admin_chat_providers.dart';
import '../../providers/auth_providers.dart';

/// Admin ↔ Cihaz chat ekranı.
/// [isAdmin] = true olduqda admin tərəfindən açılır (AdminShell → detail → chat),
/// [isAdmin] = false olduqda cihaz tərəfindən açılır (DeviceShell içindəki tab).
class DeviceChatScreen extends ConsumerStatefulWidget {
  final String deviceUid;
  final bool isAdmin;

  const DeviceChatScreen({
    super.key,
    required this.deviceUid,
    required this.isAdmin,
  });

  @override
  ConsumerState<DeviceChatScreen> createState() => _DeviceChatScreenState();
}

class _DeviceChatScreenState extends ConsumerState<DeviceChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    // Ekran açılanda mesajları oxunmuş et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(adminChatControllerProvider.notifier).markRead(
            deviceUid: widget.deviceUid,
            readByAdmin: widget.isAdmin,
          );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(userDocProvider).value;
    if (user == null) return;
    _ctrl.clear();
    await ref.read(adminChatControllerProvider.notifier).send(
          deviceUid: widget.deviceUid,
          text: text,
          senderUid: user.uid,
          isFromAdmin: widget.isAdmin,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(adminMessagesProvider(widget.deviceUid));
    final myUid = ref.watch(userDocProvider).value?.uid ?? '';

    return Column(
      children: [
        // Başlıq zolağı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              const Text('◆',
                  style: TextStyle(color: AppTheme.purple, fontSize: 14)),
              const SizedBox(width: 8),
              Text(
                widget.isAdmin ? 'ŞİFRƏLİ KANAL' : 'ADMİN İLƏ ƏLAQƏ',
                style: AppTheme.mono(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppTheme.purple),
              ),
              const SizedBox(width: 8),
              PatronCursor(size: 7),
            ],
          ),
        ),

        // Mesaj siyahısı
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.purple)),
            error: (e, _) => Center(
              child: Text('Xəta: $e',
                  style: AppTheme.body(color: AppTheme.alert)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('◆',
                          style: TextStyle(
                              fontSize: 36, color: AppTheme.purple)),
                      const SizedBox(height: 10),
                      Text('Hələ mesaj yoxdur',
                          style: AppTheme.body(color: AppTheme.textDim)),
                    ],
                  ),
                );
              }

              // Yalnız yeni mesaj gələndə scroll et
              if (messages.length > _lastMessageCount) {
                _lastMessageCount = messages.length;
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  final isMe = msg.senderUid == myUid;
                  return _MessageBubble(msg: msg, isMe: isMe);
                },
              );
            },
          ),
        ),

        // Mesaj yazma sahəsi
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: AppTheme.body(size: 15),
                    decoration: const InputDecoration(
                      hintText: 'Mesaj yazın...',
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _send,
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.purple),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: AppTheme.purple, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AdminMessage msg;
  final bool isMe;
  const _MessageBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.purple : AppTheme.surface,
          border: isMe ? null : Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6),
            bottomLeft: Radius.circular(isMe ? 6 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.text,
              style: AppTheme.body(
                  size: 15,
                  color: isMe ? AppTheme.bg : AppTheme.textMain),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.timestamp),
              style: AppTheme.mono(
                  size: 10,
                  color: isMe
                      ? AppTheme.bg.withOpacity(0.6)
                      : AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
