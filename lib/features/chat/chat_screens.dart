import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../listing/report_sheet.dart';

final conversationsProvider = FutureProvider.autoDispose<List<_Conv>>((ref) async {
  final uid = ref.watch(uidProvider);
  if (uid == null) return [];
  ref.watch(countersProvider); // se rafraîchit à chaque nouveau message (Realtime)
  final rows = await Repo.conversations();
  final out = <_Conv>[];
  for (final r in rows) {
    final other = (r['user_a'] == uid ? r['user_b'] : r['user_a']) as String;
    final p = await Repo.profile(other);
    final last = await Repo.lastMessage(r['id'] as String);
    final unread = await Repo.unreadIn(r['id'] as String);
    out.add(_Conv(r, p?.displayName ?? '?', p?.avatarUrl, last, unread));
  }
  return out;
});

class _Conv {
  _Conv(this.row, this.name, this.avatar, this.last, this.unread);
  final Map<String, dynamic> row;
  final String name;
  final String? avatar;
  final Map<String, dynamic>? last;
  final int unread;
}

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(conversationsProvider);
    final lang = context.lang;
    return WPage(
      title: context.t('nav.messages'),
      maxWidth: 820,
      child: AsyncView<List<_Conv>>(
        value: v,
        onRetry: () => ref.invalidate(conversationsProvider),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.chat_bubble_outline_rounded, title: context.t('chat.none'), body: context.t('chat.empty'))
            : Column(children: [
                for (final (i, c) in list.indexed)
                  Pressable(
                    onTap: () => context.push('/messages/${c.row['id']}'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        Avatar(url: c.avatar, name: c.name, size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(c.name, style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                              if (c.last != null) Text(timeAgo(DateTime.parse(c.last!['created_at'] as String), lang), style: Theme.of(context).textTheme.bodySmall),
                            ]),
                            if (c.row['listings'] != null) Text((c.row['listings'] as Map)['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: WM.signalDeep, fontSize: 12, fontWeight: FontWeight.w600)),
                            if (c.row['wanted_requests'] != null) Text((c.row['wanted_requests'] as Map)['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: WM.wave, fontSize: 12, fontWeight: FontWeight.w600)),
                            Text(c.last == null ? '' : (c.last!['image_path'] != null && (c.last!['body'] ?? '') == '' ? '📷 ${context.t('chat.image')}' : (c.last!['body'] as String? ?? '')), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: c.unread > 0 ? FontWeight.w800 : FontWeight.w400)),
                          ]),
                        ),
                        if (c.unread > 0) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(gradient: WM.signalGradient, borderRadius: BorderRadius.circular(99)), child: Text('${c.unread}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))).popIn(),
                      ]),
                    ),
                  ).reveal(index: i),
              ]),
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ChatScreen> createState() => _ChatState();
}

class _ChatState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _msgs = [];
  Map<String, dynamic>? _conv;
  String _otherName = '…';
  String? _otherId, _otherAvatar;
  bool _loading = true, _blocked = false, _sending = false;
  Object? _error;
  RealtimeChannel? _ch;
  final _urls = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ch?.unsubscribe();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = myId!;
      final convs = await Repo.conversations();
      _conv = convs.where((c) => c['id'] == widget.id).firstOrNull;
      if (_conv == null) throw Exception('conversation_not_found');
      _otherId = (_conv!['user_a'] == uid ? _conv!['user_b'] : _conv!['user_a']) as String;
      final p = await Repo.profile(_otherId!);
      _otherName = p?.displayName ?? '?';
      _otherAvatar = p?.avatarUrl;
      _blocked = (await Repo.blockedIds()).contains(_otherId);
      _msgs = await Repo.messages(widget.id);
      await Repo.markRead(widget.id);
      ref.read(countersProvider.notifier).refresh();
      _ch = sb
          .channel('chat-${widget.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: widget.id),
            callback: (payload) async {
              _msgs = await Repo.messages(widget.id);
              if (!mounted) return;
              setState(() {});
              _toBottom();
              if (payload.eventType == PostgresChangeEvent.insert && payload.newRecord['sender_id'] != myId) {
                await Repo.markRead(widget.id);
                ref.read(countersProvider.notifier).refresh();
              }
            },
          )
          .subscribe();
      if (mounted) setState(() => _loading = false);
      _toBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: Motion.base, curve: Motion.enter);
      });

  Future<void> _send({String? imagePath}) async {
    final body = _text.text.trim();
    if (body.isEmpty && imagePath == null) return;
    setState(() => _sending = true);
    try {
      await Repo.sendMessage(widget.id, body: body.isEmpty ? null : body, imagePath: imagePath);
      _text.clear();
      _msgs = await Repo.messages(widget.id);
      _toBottom();
    } catch (e) {
      if (mounted) toast(context, errMsg(context, e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final ext = f.name.contains('.') ? f.name.split('.').last : 'jpg';
    try {
      final path = await Repo.uploadChatImage(widget.id, bytes, ext);
      await _send(imagePath: path);
    } catch (e) {
      if (mounted) toast(context, context.t('form.err_upload'), error: true);
    }
  }

  Future<String?> _url(String path) async {
    if (_urls.containsKey(path)) return _urls[path];
    try {
      return _urls[path] = await Repo.chatImageUrl(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = myId;
    final cs = Theme.of(context).colorScheme;
    final lang = context.lang;
    if (_loading) return const WPage(title: '', child: SkeletonList());
    if (_error != null) return WPage(title: '', child: ErrorState(error: _error!, onRetry: () { setState(() { _loading = true; _error = null; }); _load(); }));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Pressable(
          onTap: () => context.push('/seller/$_otherId'),
          child: Row(children: [Avatar(url: _otherAvatar, name: _otherName, size: 36), const SizedBox(width: 10), Flexible(child: Text(_otherName, overflow: TextOverflow.ellipsis))]),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'block') {
                await guard(context, () async {
                  await Repo.block(_otherId!, !_blocked);
                  setState(() => _blocked = !_blocked);
                });
              } else if (v == 'report') {
                await showReportSheet(context, ref, 'conversation', widget.id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'block', child: Text(_blocked ? context.t('chat.unblock') : context.t('chat.block'))),
              PopupMenuItem(value: 'report', child: Text(context.t('chat.report'))),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(children: [
            if (_conv?['listings'] != null)
              Pressable(
                onTap: () => context.push('/listing/${_conv!['listing_id']}'),
                child: Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [const Icon(Icons.sell_outlined, size: 18), const SizedBox(width: 8), Expanded(child: Text((_conv!['listings'] as Map)['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis)), const Icon(Icons.chevron_right_rounded)]),
                ),
              ),
            Expanded(
              child: _msgs.isEmpty
                  ? Center(child: Text(context.t('chat.empty'), style: Theme.of(context).textTheme.bodySmall))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final m = _msgs[i];
                        final mine = m['sender_id'] == me;
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78 > 520 ? 520 : MediaQuery.sizeOf(context).width * .78),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: mine ? WM.signalGradient : null,
                              color: mine ? null : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 4), bottomRight: Radius.circular(mine ? 4 : 18)),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              if (m['image_path'] != null)
                                FutureBuilder<String?>(
                                  future: _url(m['image_path'] as String),
                                  builder: (_, s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: SizedBox(width: 220, height: 160, child: Net(s.data, radius: 12))),
                                ),
                              if ((m['body'] as String?)?.isNotEmpty ?? false) Align(alignment: Alignment.centerLeft, child: Text(m['body'] as String, style: TextStyle(color: mine ? Colors.white : cs.onSurface, fontSize: 15))),
                              const SizedBox(height: 2),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(timeAgo(DateTime.parse(m['created_at'] as String), lang), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : cs.onSurfaceVariant)),
                                if (mine) ...[const SizedBox(width: 4), Icon(m['read_at'] != null ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: Colors.white70)],
                              ]),
                            ]),
                          ),
                        ).animate1();
                      },
                    ),
            ),
            if (_blocked)
              Padding(padding: const EdgeInsets.all(14), child: Text(context.t('chat.blocked_info'), style: Theme.of(context).textTheme.bodySmall))
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(children: [
                    IconButton(onPressed: _pickImage, icon: const Icon(Icons.image_outlined)),
                    Expanded(
                      child: TextField(
                        controller: _text,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(hintText: context.t('chat.placeholder'), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pressable(
                      onTap: _sending ? null : () => _send(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(gradient: WM.signalGradient, shape: BoxShape.circle),
                        child: _sending ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget animate1() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.base,
        curve: Motion.enter,
        builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: child)),
        child: this,
      );
}
