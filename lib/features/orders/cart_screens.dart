import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class CartLine {
  CartLine(this.listing, this.qty);
  final Listing listing;
  final int qty;
}

final cartProvider = FutureProvider.autoDispose<List<CartLine>>((ref) async {
  ref.watch(uidProvider);
  final rows = await Repo.cart();
  return rows.map((r) => CartLine(Listing.fromJson(r['listings'] as Map<String, dynamic>), r['quantity'] as int)).toList();
});

/// Regroupe par vendeur + devise (une commande par groupe, comme côté base).
Map<String, List<CartLine>> groupLines(List<CartLine> lines) {
  final m = <String, List<CartLine>>{};
  for (final l in lines) {
    m.putIfAbsent('${l.listing.sellerId}|${l.listing.currency}', () => []).add(l);
  }
  return m;
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(cartProvider);
    final lang = context.lang;
    final cs = Theme.of(context).colorScheme;
    Future<void> setQty(Listing l, int q) => guard(context, () async {
          await Repo.cartSet(l.id, q);
          ref.invalidate(cartProvider);
        });
    return WPage(
      title: context.t('cart.title'),
      maxWidth: 860,
      child: AsyncView<List<CartLine>>(
        value: v,
        onRetry: () => ref.invalidate(cartProvider),
        data: (lines) {
          if (lines.isEmpty) return EmptyState(icon: Icons.shopping_bag_outlined, title: context.t('cart.empty'), action: () => context.go('/'), actionLabel: context.t('cart.browse'));
          final groups = groupLines(lines);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (groups.length > 1)
              Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: WM.volt.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)), child: Text(context.t('cart.multi_currency'), style: Theme.of(context).textTheme.bodySmall)),
            for (final (gi, e) in groups.entries.indexed) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: softCard(cs),
                child: Column(children: [
                  for (final c in e.value)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        SizedBox(width: 68, height: 68, child: Net(c.listing.cover, radius: 14)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.listing.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                            Text(formatPrice(c.listing.price, c.listing.currency, lang), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
                            Row(children: [
                              IconButton.filledTonal(visualDensity: VisualDensity.compact, onPressed: () => setQty(c.listing, c.qty - 1), icon: const Icon(Icons.remove_rounded, size: 18)),
                              AnimatedSwitcher(duration: Motion.quick, child: SizedBox(key: ValueKey(c.qty), width: 34, child: Text('${c.qty}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium))),
                              IconButton.filledTonal(visualDensity: VisualDensity.compact, onPressed: c.qty >= c.listing.quantity ? null : () => setQty(c.listing, c.qty + 1), icon: const Icon(Icons.add_rounded, size: 18)),
                              const Spacer(),
                              IconButton(onPressed: () => setQty(c.listing, 0), icon: const Icon(Icons.delete_outline_rounded, color: WM.coral)),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  const Divider(),
                  Row(children: [
                    Text(context.t('cart.subtotal')),
                    const Spacer(),
                    Text(formatPrice(e.value.fold<num>(0, (a, c) => a + c.listing.price * c.qty), e.value.first.listing.currency, lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                ]),
              ).reveal(index: gi),
            ],
            Text(context.t('cart.shipping_note'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            GradientButton(label: context.t('cart.checkout'), icon: Icons.lock_outline_rounded, onPressed: () => context.push('/checkout')),
          ]);
        },
      ),
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutState();
}

class _CheckoutState extends ConsumerState<CheckoutScreen> {
  String method = 'pickup';
  final _recipient = TextEditingController();
  final _line = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();
  String country = 'BF';
  bool busy = false;
  List<Map<String, dynamic>> rules = [];

  @override
  void initState() {
    super.initState();
    Repo.shippingRules().then((r) => mounted ? setState(() => rules = r) : null).catchError((_) {});
    Repo.profile(myId!).then((p) {
      if (p == null || !mounted) return;
      setState(() {
        _recipient.text = p.displayName;
        if (p.countryCode != null) country = p.countryCode!;
        _city.text = p.city ?? '';
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_recipient, _line, _city, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Frais issus UNIQUEMENT des règles configurées ; null = aucune règle applicable.
  num? _fee(String m, Listing l) {
    if (m == 'pickup') return 0;
    final sameCity = (l.city ?? '').toLowerCase() == _city.text.trim().toLowerCase();
    final matches = rules.where((r) =>
        r['method'] == m && r['from_country'] == l.country && r['to_country'] == country && r['currency_code'] == l.currency && (r['same_city'] == null || r['same_city'] == sameCity));
    if (matches.isEmpty) return null;
    final sorted = matches.toList()..sort((a, b) => (a['fee'] as num).compareTo(b['fee'] as num));
    return sorted.first['fee'] as num;
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(cartProvider);
    final lang = context.lang;
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    final cs = Theme.of(context).colorScheme;
    return WPage(
      title: context.t('checkout.title'),
      maxWidth: 760,
      child: AsyncView<List<CartLine>>(
        value: v,
        data: (lines) {
          if (lines.isEmpty) return EmptyState(icon: Icons.shopping_bag_outlined, title: context.t('cart.empty'));
          final groups = groupLines(lines);
          final allDelivery = lines.every((l) => l.listing.delivery);
          if (!allDelivery && method != 'pickup') method = 'pickup';
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('checkout.delivery_mode'), style: Theme.of(context).textTheme.titleMedium),
            if (!allDelivery) Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.t('checkout.some_pickup_only'), style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: method,
              onChanged: (x) => setState(() => method = x ?? method),
              child: Column(children: [
                for (final m in const ['pickup', 'local', 'intercity', 'international'])
                  Opacity(
                    opacity: m != 'pickup' && !allDelivery ? .4 : 1,
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: m,
                      enabled: m == 'pickup' || allDelivery,
                      title: Text(context.t('ship.$m')),
                      subtitle: Text(context.t('ship.${m}_hint')),
                    ),
                  ),
              ]),
            ),
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.emphasized,
              child: method == 'pickup'
                  ? const SizedBox(width: double.infinity)
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 8),
                      Text(context.t('checkout.address'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      field(_recipient, context.t('checkout.recipient')),
                      DropdownButtonFormField<String>(
                        initialValue: countries.any((c) => c.code == country) ? country : null,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: context.t('common.country')),
                        items: [for (final c in countries) DropdownMenuItem(value: c.code, child: Text(c.name(lang)))],
                        onChanged: (x) => setState(() => country = x ?? country),
                      ),
                      const SizedBox(height: 14),
                      field(_city, context.t('common.city'), onChanged: (_) => setState(() {})),
                      field(_line, context.t('checkout.address_line')),
                    ]),
            ),
            const Divider(height: 28),
            Text(context.t('checkout.summary'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in groups.entries) ...[
              Builder(builder: (_) {
                final cur = e.value.first.listing.currency;
                final sub = e.value.fold<num>(0, (a, c) => a + c.listing.price * c.qty);
                final fee = _fee(method, e.value.first.listing);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: softCard(cs),
                  child: Column(children: [
                    for (final c in e.value) Row(children: [Expanded(child: Text('${c.qty} × ${c.listing.title}', maxLines: 1, overflow: TextOverflow.ellipsis)), Text(formatPrice(c.listing.price * c.qty, cur, lang))]),
                    const Divider(),
                    Row(children: [Text(context.t('cart.subtotal')), const Spacer(), Text(formatPrice(sub, cur, lang))]),
                    Row(children: [Text(context.t('order.shipping')), const Spacer(), Text(fee == null ? context.t('err.no_shipping_rule') : formatPrice(fee, cur, lang), style: TextStyle(color: fee == null ? WM.coral : null))]),
                    Row(children: [Text('Total', style: Theme.of(context).textTheme.titleSmall), const Spacer(), Text(fee == null ? '—' : formatPrice(sub + fee, cur, lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800))]),
                  ]),
                );
              }),
            ],
            const SizedBox(height: 6),
            Text(context.t('checkout.payment'), style: Theme.of(context).textTheme.titleMedium),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: WM.signal.withValues(alpha: .1), borderRadius: BorderRadius.circular(16), border: Border.all(color: WM.signal.withValues(alpha: .5))),
              child: Row(children: [const Icon(Icons.handshake_outlined, color: WM.signalDeep), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.t('checkout.pay_offline'), style: Theme.of(context).textTheme.titleSmall), Text(context.t('checkout.pay_offline_hint'), style: Theme.of(context).textTheme.bodySmall)]))]),
            ),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.t('checkout.online_unavailable'), style: Theme.of(context).textTheme.bodySmall)),
            const SizedBox(height: 14),
            field(_note, context.t('checkout.note'), lines: 2),
            GradientButton(
              label: context.t('checkout.confirm'),
              icon: Icons.check_circle_outline_rounded,
              loading: busy,
              onPressed: () async {
                if (method != 'pickup' && (_line.text.trim().isEmpty || _city.text.trim().isEmpty)) return toast(context, context.t('err.address_required'), error: true);
                setState(() => busy = true);
                await guard(context, () async {
                  final ids = await Repo.placeOrder(
                    method,
                    method == 'pickup' ? null : {'recipient': _recipient.text.trim(), 'country': country, 'city': _city.text.trim(), 'line1': _line.text.trim()},
                    'offline',
                    _note.text.trim().isEmpty ? null : _note.text.trim(),
                  );
                  ref.invalidate(cartProvider);
                  if (context.mounted) {
                    toast(context, context.t('order.placed'));
                    context.go(ids.length == 1 ? '/orders/${ids.first}' : '/orders');
                  }
                });
                if (mounted) setState(() => busy = false);
              },
            ),
          ]);
        },
      ),
    );
  }
}
