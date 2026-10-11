import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

/// Offre de prix ou proposition d'échange sur une annonce.
Future<void> showNegotiateSheet(BuildContext context, WidgetRef ref, Listing l) async {
  if (!requireLogin(context, ref)) return;
  final price = TextEditingController();
  final topUp = TextEditingController();
  final note = TextEditingController();
  String kind = l.negotiable ? 'offer' : 'exchange';
  String? myItem;
  bool busy = false;
  final mine = (await Repo.myListings().catchError((_) => <Listing>[])).where((x) => x.status == 'active' && x.id != l.id).toList();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.t('listing.negotiate'), style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${l.title} · ${formatPrice(l.price, l.currency, ctx.lang)}', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 14),
            if (l.negotiable && l.exchange)
              SegmentedButton<String>(
                segments: [ButtonSegment(value: 'offer', label: Text(ctx.t('nego.offer'))), ButtonSegment(value: 'exchange', label: Text(ctx.t('nego.exchange')))],
                selected: {kind},
                onSelectionChanged: (s) => set(() => kind = s.first),
              ),
            const SizedBox(height: 14),
            if (kind == 'offer') field(price, '${ctx.t('nego.your_price')} (${l.currency})', type: TextInputType.number),
            if (kind == 'exchange') ...[
              DropdownButtonFormField<String>(
                initialValue: myItem,
                isExpanded: true,
                decoration: InputDecoration(labelText: ctx.t('nego.my_item')),
                items: [for (final m in mine) DropdownMenuItem(value: m.id, child: Text(m.title, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => set(() => myItem = v),
              ),
              if (mine.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(ctx.t('nego.no_listing'), style: Theme.of(ctx).textTheme.bodySmall)),
              const SizedBox(height: 14),
              field(topUp, '${ctx.t('nego.top_up')} (${l.currency})', type: TextInputType.number),
            ],
            field(note, ctx.t('nego.note'), lines: 2),
            GradientButton(
              label: ctx.t('nego.send'),
              loading: busy,
              onPressed: () async {
                final p = parseNum(price.text);
                if (kind == 'offer' && (p == null || p <= 0)) return toast(ctx, ctx.t('err.price_required'), error: true);
                if (kind == 'exchange' && myItem == null) return toast(ctx, ctx.t('nego.my_item'), error: true);
                set(() => busy = true);
                try {
                  await Repo.createNegotiation({
                    'listing_id': l.id,
                    'seller_id': l.sellerId,
                    'kind': kind,
                    'offered_price': kind == 'offer' ? p : null,
                    'currency_code': l.currency,
                    'exchange_listing_id': kind == 'exchange' ? myItem : null,
                    'cash_top_up': kind == 'exchange' ? parseNum(topUp.text) : null,
                    'note': note.text.trim().isEmpty ? null : note.text.trim(),
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    toast(context, context.t('nego.sent'));
                    context.push('/negotiations');
                  }
                } catch (e) {
                  set(() => busy = false);
                  if (ctx.mounted) toast(ctx, errMsg(ctx, e), error: true);
                }
              },
            ),
          ]),
        ),
      ),
    ),
  );
  price.dispose();
  topUp.dispose();
  note.dispose();
}

final negotiationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  ref.watch(uidProvider);
  return Repo.negotiations();
});

class NegotiationsScreen extends ConsumerWidget {
  const NegotiationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(negotiationsProvider);
    final me = ref.watch(uidProvider);
    return WPage(
      title: context.t('account.negotiations'),
      maxWidth: 860,
      child: AsyncView<List<Map<String, dynamic>>>(
        value: v,
        onRetry: () => ref.invalidate(negotiationsProvider),
        data: (rows) => rows.isEmpty
            ? EmptyState(icon: Icons.handshake_outlined, title: context.t('nego.none'))
            : Column(children: [for (final (i, n) in rows.indexed) _NegoCard(n: n, me: me ?? '').reveal(index: i)]),
      ),
    );
  }
}

class _NegoCard extends ConsumerWidget {
  const _NegoCard({required this.n, required this.me});
  final Map<String, dynamic> n;
  final String me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l = n['listings'] as Map<String, dynamic>?;
    final amBuyer = n['buyer_id'] == me;
    final status = n['status'] as String;
    final cur = n['currency_code'] as String;
    final media = ((l?['listing_media'] as List?) ?? []).cast<Map<String, dynamic>>();
    final cover = media.isEmpty ? null : publicUrl('listing-media', media.first['storage_path'] as String);
    final kind = n['kind'] as String;
    final myTurn = (status == 'pending' && !amBuyer) || (status == 'countered' && amBuyer);
    final confirmed = amBuyer ? n['buyer_confirmed'] == true : n['seller_confirmed'] == true;

    Future<void> act(String a, {num? price}) => guard(context, () async {
          await Repo.negotiationRespond(n['id'] as String, a, price: price);
          ref.invalidate(negotiationsProvider);
        });

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.outlineVariant.withValues(alpha: .6))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(width: 56, height: 56, child: Net(cover, radius: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l?['title'] as String? ?? context.t('nego.no_listing'), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              Text(amBuyer ? context.t('nego.with_seller') : context.t('nego.from_buyer'), style: Theme.of(context).textTheme.bodySmall),
              if (l != null) Text('${context.t('nego.asking')} ${formatPrice(l['price'] as num, l['currency_code'] as String, context.lang)}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          StatusChip(context.t('nego.s.$status'), tone: statusTone(status)),
        ]),
        const SizedBox(height: 10),
        Text(
          kind == 'offer'
              ? '${context.t('nego.offer')} : ${formatPrice(n['offered_price'] as num, cur, context.lang)}'
              : '${context.t('nego.exchange')}${n['cash_top_up'] != null ? ' + ${formatPrice(n['cash_top_up'] as num, cur, context.lang)}' : ''}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
        ),
        if ((n['note'] as String?)?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 4), child: Text(n['note'] as String)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (myTurn) ...[
            FilledButton(onPressed: () => act('accept'), child: Text(context.t('nego.accept'))),
            OutlinedButton(onPressed: () => act('decline'), child: Text(context.t('nego.decline'))),
            if (!amBuyer)
              OutlinedButton(
                onPressed: () async {
                  final v = await promptDialog(context, context.t('nego.counter'), hint: cur, multiline: false);
                  final p = parseNum(v);
                  if (p != null && context.mounted) await act('counter', price: p);
                },
                child: Text(context.t('nego.counter')),
              ),
          ],
          if (status == 'accepted' && !confirmed)
            GradientButton(
              label: context.t('nego.confirm'),
              expand: false,
              onPressed: () => guard(context, () async {
                await Repo.negotiationConfirm(n['id'] as String);
                ref.invalidate(negotiationsProvider);
              }),
            ),
          if (status == 'accepted' && confirmed) Text(context.t('nego.waiting_other'), style: Theme.of(context).textTheme.bodySmall),
          if (['pending', 'countered'].contains(status) && amBuyer && !myTurn) OutlinedButton(onPressed: () => act('cancel'), child: Text(context.t('common.cancel'))),
          if (l != null) TextButton(onPressed: () => context.push('/listing/${l['id']}'), child: Text(context.t('common.view'))),
        ]),
      ]),
    );
  }
}
