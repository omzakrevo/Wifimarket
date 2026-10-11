import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

final _ordersProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, bool>((ref, sales) {
  ref.watch(uidProvider);
  return Repo.orders(sales: sales);
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key, this.sales = false});
  final bool sales;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_ordersProvider(sales));
    final lang = context.lang;
    return WPage(
      title: context.t('account.orders'),
      maxWidth: 820,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SegmentedButton<bool>(
          segments: [ButtonSegment(value: false, label: Text(context.t('order.purchases'))), ButtonSegment(value: true, label: Text(context.t('order.sales')))],
          selected: {sales},
          onSelectionChanged: (s) => context.go('/orders?tab=${s.first ? 'sales' : 'purchases'}'),
        ),
        const SizedBox(height: 14),
        AsyncView<List<Map<String, dynamic>>>(
          value: v,
          onRetry: () => ref.invalidate(_ordersProvider(sales)),
          data: (rows) => rows.isEmpty
              ? EmptyState(icon: Icons.receipt_long_outlined, title: context.t('order.none'))
              : Column(children: [
                  for (final (i, o) in rows.indexed)
                    Pressable(
                      onTap: () => context.push('/orders/${o['id']}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('#${o['order_number']}', style: Theme.of(context).textTheme.titleSmall),
                              Text(((o['order_items'] as List).map((e) => e['title']).join(', ')), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 4),
                              Text(formatPrice(o['total'] as num, o['currency_code'] as String, lang), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
                            ]),
                          ),
                          StatusChip(context.t('order.s.${o['status']}'), tone: statusTone(o['status'] as String)),
                        ]),
                      ),
                    ).reveal(index: i),
                ]),
        ),
      ]),
    );
  }
}

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderState();
}

class _OrderState extends ConsumerState<OrderDetailScreen> {
  late Future<Map<String, dynamic>?> f = Repo.order(widget.id);
  void _reload() {
    setState(() => f = Repo.order(widget.id));
    ref.invalidate(_ordersProvider);
  }

  Future<void> _do(Future<void> Function() job) => guard(context, () async {
        await job();
        _reload();
      });

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(uidProvider);
    final lang = context.lang;
    final cs = Theme.of(context).colorScheme;
    return WPage(
      title: context.t('account.orders'),
      maxWidth: 760,
      child: FutureBuilder(
        future: f,
        builder: (context, s) {
          if (s.hasError) return ErrorState(error: s.error!, onRetry: _reload);
          if (!s.hasData && s.connectionState != ConnectionState.done) return const SkeletonList(count: 3);
          final o = s.data;
          if (o == null) return EmptyState(icon: Icons.search_off_rounded, title: context.t('error.not_found'));
          final isSeller = o['seller_id'] == me;
          final status = o['status'] as String;
          final cur = o['currency_code'] as String;
          final ship = ((o['shipments'] as List?) ?? []).cast<Map<String, dynamic>>().firstOrNull;
          final addr = o['shipping_address'] as Map<String, dynamic>?;
          const steps = ['pending', 'processing', 'shipped', 'delivered', 'completed'];
          final cancelled = status == 'cancelled' || status == 'refunded';
          final idx = steps.indexOf(status == 'paid' ? 'processing' : status);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text('#${o['order_number']}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))), StatusChip(context.t('order.s.$status'), tone: statusTone(status))]).reveal(),
            const SizedBox(height: 16),
            if (!cancelled)
              Row(children: [
                for (final (i, st) in steps.indexed) ...[
                  Expanded(
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: i <= idx ? WM.signalGradient : null, color: i <= idx ? null : cs.surfaceContainerHighest),
                        child: Icon(i <= idx ? Icons.check_rounded : Icons.circle, size: i <= idx ? 16 : 6, color: i <= idx ? Colors.white : cs.outline),
                      ),
                      const SizedBox(height: 4),
                      Text(context.t('order.s.$st'), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: i == idx ? FontWeight.w800 : FontWeight.w500)),
                    ]),
                  ),
                ],
              ]).reveal(index: 1),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                for (final it in (o['order_items'] as List).cast<Map<String, dynamic>>())
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text('${it['quantity']} × ${it['title']}')), Text(formatPrice((it['unit_price'] as num) * (it['quantity'] as num), cur, lang))])),
                const Divider(),
                Row(children: [Text(context.t('cart.subtotal')), const Spacer(), Text(formatPrice(o['subtotal'] as num, cur, lang))]),
                Row(children: [Text(context.t('order.shipping')), const Spacer(), Text(formatPrice(o['shipping_fee'] as num, cur, lang))]),
                Row(children: [Text('Total', style: Theme.of(context).textTheme.titleSmall), const Spacer(), Text(formatPrice(o['total'] as num, cur, lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800))]),
              ]),
            ).reveal(index: 2),
            const SizedBox(height: 14),
            Text('${context.t('order.shipping')} : ${context.t('ship.${o['delivery_method']}')}'),
            if (addr != null) Text('${addr['recipient'] ?? ''} — ${addr['line1']}, ${addr['city']} (${addr['country']})', style: Theme.of(context).textTheme.bodySmall),
            if (ship != null && ship['tracking_number'] != null) Text('${context.t('order.tracking')} : ${ship['tracking_number']}${ship['carrier'] != null ? ' (${ship['carrier']})' : ''}'),
            Text('${context.t('order.payment')} : ${context.t('checkout.pay_offline')}', style: Theme.of(context).textTheme.bodySmall),
            if ((o['buyer_note'] as String?)?.isNotEmpty ?? false) Text('“${o['buyer_note']}”', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (isSeller && (status == 'pending' || status == 'paid')) GradientButton(label: context.t('order.confirm'), expand: false, onPressed: () => _do(() => Repo.advanceOrder(widget.id, 'processing'))),
              if (isSeller && status == 'processing' && o['delivery_method'] != 'pickup')
                GradientButton(
                  label: context.t('order.mark_shipped'),
                  expand: false,
                  onPressed: () async {
                    final t = await promptDialog(context, context.t('order.tracking'), multiline: false);
                    if (!context.mounted) return;
                    await _do(() => Repo.advanceOrder(widget.id, 'shipped', tracking: t));
                  },
                ),
              if (isSeller && (status == 'processing' || status == 'shipped')) OutlinedButton(onPressed: () => _do(() => Repo.advanceOrder(widget.id, 'delivered')), child: Text(context.t('order.mark_delivered'))),
              if (!isSeller && status == 'delivered') GradientButton(label: context.t('order.confirm_receipt'), expand: false, onPressed: () => _do(() => Repo.advanceOrder(widget.id, 'completed'))),
              if (['pending', 'awaiting_payment', 'processing', 'paid'].contains(status) && (isSeller || status == 'pending' || status == 'awaiting_payment'))
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: WM.coral),
                  onPressed: () async {
                    if (!await confirmDialog(context, context.t('order.confirm_cancel'))) return;
                    await _do(() => Repo.cancelOrder(widget.id, null));
                  },
                  child: Text(context.t('order.cancel')),
                ),
              if (['paid', 'processing', 'shipped', 'delivered'].contains(status))
                TextButton(
                  onPressed: () async {
                    final r = await promptDialog(context, context.t('order.dispute'), hint: context.t('order.dispute_reason'));
                    if (r == null || !context.mounted) return;
                    await _do(() => Repo.openDispute(widget.id, r));
                  },
                  child: Text(context.t('order.dispute')),
                ),
              if (!isSeller && ['delivered', 'completed'].contains(status) && ((o['reviews'] as List?)?.isEmpty ?? true))
                OutlinedButton.icon(onPressed: () => _review(context, o), icon: const Icon(Icons.star_outline_rounded), label: Text(context.t('review.leave'))),
            ]),
          ]);
        },
      ),
    );
  }

  Future<void> _review(BuildContext context, Map<String, dynamic> o) async {
    int rating = 5;
    final comment = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.t('review.leave'), style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            Row(children: [for (var i = 1; i <= 5; i++) IconButton(onPressed: () => set(() => rating = i), icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, key: ValueKey(i <= rating), color: WM.volt, size: 36)))]),
            field(comment, ctx.t('review.comment'), lines: 3),
            GradientButton(
              label: ctx.t('review.send'),
              onPressed: () async {
                try {
                  final items = (o['order_items'] as List).cast<Map<String, dynamic>>();
                  await Repo.addReview(sellerId: o['seller_id'] as String, orderId: o['id'] as String, listingId: items.isEmpty ? null : items.first['listing_id'] as String?, shopId: o['shop_id'] as String?, rating: rating, comment: comment.text.trim().isEmpty ? null : comment.text.trim());
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    toast(context, context.t('review.thanks'));
                  }
                  _reload();
                } catch (e) {
                  if (ctx.mounted) toast(ctx, errMsg(ctx, e), error: true);
                }
              },
            ),
          ]),
        ),
      ),
    );
    comment.dispose();
  }
}
