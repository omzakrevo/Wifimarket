import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../listing/report_sheet.dart';

final _wantedProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, ({bool mine, String? country})>((ref, a) {
  ref.watch(uidProvider);
  return Repo.wanted(mine: a.mine, country: a.country);
});

class WantedScreen extends ConsumerWidget {
  const WantedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = GoRouterState.of(context).uri.queryParameters['mine'] == '1';
    final country = ref.watch(countryProvider);
    final v = ref.watch(_wantedProvider((mine: mine, country: country)));
    final lang = context.lang;
    return WPage(
      title: mine ? context.t('account.my_wanted') : context.t('nav.wanted'),
      maxWidth: 860,
      fab: FloatingActionButton.extended(onPressed: () => context.push('/wanted/new'), icon: const Icon(Icons.add_rounded), label: Text(context.t('home.post_wanted'))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!mine) Text(context.t('wanted.sub'), style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          ChoiceChip(label: Text(context.t('nav.wanted')), selected: !mine, onSelected: (_) => context.go('/wanted')),
          if (ref.watch(uidProvider) != null) ChoiceChip(label: Text(context.t('account.my_wanted')), selected: mine, onSelected: (_) => context.go('/wanted?mine=1')),
        ]),
        const SizedBox(height: 14),
        AsyncView<List<Map<String, dynamic>>>(
          value: v,
          onRetry: () => ref.invalidate(_wantedProvider),
          data: (rows) => rows.isEmpty
              ? EmptyState(icon: Icons.travel_explore_rounded, title: mine ? context.t('wanted.none_mine') : context.t('wanted.none'), action: () => context.push('/wanted/new'), actionLabel: context.t('home.post_wanted'))
              : Column(children: [
                  for (final (i, r) in rows.indexed)
                    Pressable(
                      onTap: () => context.push('/wanted/${r['id']}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(r['title'] as String, style: Theme.of(context).textTheme.titleMedium)),
                            StatusChip(context.t('wanted.s.${r['status']}'), tone: statusTone(r['status'] as String)),
                          ]),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, runSpacing: 4, children: [
                            if (r['categories'] != null) Badge2(((r['categories'] as Map)[lang == 'en' ? 'name_en' : 'name_fr']) as String, color: WM.signalDeep),
                            if (r['budget'] != null) Badge2('${context.t('wanted.budget')} ${formatPrice(r['budget'] as num, r['currency_code'] as String, lang)}', color: WM.wave),
                            Badge2([r['city'], r['country_code']].whereType<String>().join(' · '), color: Colors.blueGrey),
                          ]),
                          const SizedBox(height: 6),
                          Text(timeAgo(DateTime.parse(r['created_at'] as String), lang), style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                    ).reveal(index: i),
                ]),
        ),
      ]),
    );
  }
}

class WantedNewScreen extends ConsumerStatefulWidget {
  const WantedNewScreen({super.key});
  @override
  ConsumerState<WantedNewScreen> createState() => _NewState();
}

class _NewState extends ConsumerState<WantedNewScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _model = TextEditingController();
  final _budget = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  int? categoryId, brandId;
  String condition = 'any', currency = 'XOF', country = 'BF';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final c = ref.read(countryProvider);
    if (c != null) country = c;
  }

  @override
  void dispose() {
    for (final c in [_title, _model, _budget, _desc, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final cats = ref.watch(categoriesProvider).asData?.value ?? [];
    final brands = ref.watch(brandsProvider).asData?.value ?? [];
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    final roots = cats.where((c) => c.parentId == null).toList();
    return WPage(
      title: context.t('home.post_wanted'),
      maxWidth: 680,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.t('wanted.new_sub')),
          const SizedBox(height: 16),
          field(_title, context.t('wanted.what'), hint: context.t('wanted.what_ph'), validator: (v) => (v ?? '').trim().length < 5 ? context.t('form.err_invalid') : null),
          DropdownButtonFormField<int?>(
            initialValue: categoryId,
            isExpanded: true,
            decoration: InputDecoration(labelText: context.t('common.category')),
            items: [DropdownMenuItem<int?>(value: null, child: const Text('—')), for (final c in roots) DropdownMenuItem(value: c.id, child: Text(c.name(lang)))],
            onChanged: (v) => setState(() => categoryId = v),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                initialValue: brandId,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.t('common.brand')),
                items: [const DropdownMenuItem<int?>(value: null, child: Text('—')), for (final b in brands) DropdownMenuItem(value: b.id, child: Text(b.name))],
                onChanged: (v) => setState(() => brandId = v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: field(_model, context.t('listing.model'))),
          ]),
          Text(context.t('wanted.condition'), style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(label: Text(context.t('wanted.any')), selected: condition == 'any', onSelected: (_) => setState(() => condition = 'any')),
            for (final c in conditions) ChoiceChip(label: Text(context.t('cond.$c')), selected: condition == c, onSelected: (_) => setState(() => condition = c)),
          ]),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: field(_budget, context.t('wanted.budget'), type: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: InputDecoration(labelText: context.t('common.currency')),
                items: [for (final c in const ['XOF', 'GNF', 'EUR', 'USD', 'NGN', 'GHS']) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (v) => setState(() => currency = v ?? currency),
              ),
            ),
          ]),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: countries.any((c) => c.code == country) ? country : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: context.t('common.country')),
                items: [for (final c in countries) DropdownMenuItem(value: c.code, child: Text(c.name(lang)))],
                onChanged: (v) => setState(() {
                  country = v ?? country;
                  final c = countries.where((x) => x.code == country).firstOrNull;
                  if (c != null) currency = c.currency;
                }),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: field(_city, context.t('common.city'))),
          ]),
          const SizedBox(height: 14),
          field(_desc, context.t('listing.description'), lines: 4),
          GradientButton(
            label: context.t('wanted.publish'),
            loading: busy,
            onPressed: () async {
              if (!(_form.currentState?.validate() ?? false)) return;
              setState(() => busy = true);
              await guard(context, () async {
                await Repo.createWanted({
                  'title': _title.text.trim(),
                  'category_id': categoryId,
                  'brand_id': brandId,
                  'model_text': _model.text.trim().isEmpty ? null : _model.text.trim(),
                  'condition_wanted': condition,
                  'budget': parseNum(_budget.text),
                  'currency_code': currency,
                  'country_code': country,
                  'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
                  'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                });
                ref.invalidate(_wantedProvider);
                if (context.mounted) context.go('/wanted?mine=1');
              });
              if (mounted) setState(() => busy = false);
            },
          ),
        ]),
      ),
    );
  }
}

class WantedDetailScreen extends ConsumerStatefulWidget {
  const WantedDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<WantedDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<WantedDetailScreen> {
  late Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> f = _load();

  Future<(Map<String, dynamic>?, List<Map<String, dynamic>>)> _load() async {
    final r = await Repo.wantedOne(widget.id);
    final offers = r == null ? <Map<String, dynamic>>[] : await Repo.offersFor(widget.id).catchError((_) => <Map<String, dynamic>>[]);
    return (r, offers);
  }

  void _reload() => setState(() => f = _load());

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(uidProvider);
    final lang = context.lang;
    return WPage(
      title: context.t('nav.wanted'),
      maxWidth: 780,
      child: FutureBuilder(
        future: f,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _reload);
          if (!snap.hasData) return const SkeletonList(count: 3);
          final (r, offers) = snap.data!;
          if (r == null) return EmptyState(icon: Icons.search_off_rounded, title: context.t('error.not_found'));
          final mine = r['requester_id'] == me;
          final open = r['status'] == 'open';
          final prof = r['profiles'] as Map<String, dynamic>?;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r['title'] as String, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)).reveal(),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              StatusChip(context.t('wanted.s.${r['status']}'), tone: statusTone(r['status'] as String)),
              if (r['categories'] != null) Badge2(((r['categories'] as Map)[lang == 'en' ? 'name_en' : 'name_fr']) as String, color: WM.signalDeep),
              if (r['brands'] != null) Badge2((r['brands'] as Map)['name'] as String, color: WM.wave),
              if (r['condition_wanted'] != null) Badge2(r['condition_wanted'] == 'any' ? context.t('wanted.any') : context.t('cond.${r['condition_wanted']}'), color: Colors.blueGrey),
              if (r['budget'] != null) Badge2('${context.t('wanted.budget')} ${formatPrice(r['budget'] as num, r['currency_code'] as String, lang)}', color: WM.volt, fg: WM.ink),
            ]).reveal(index: 1),
            if ((r['description'] as String?)?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 12), child: Text(r['description'] as String, style: Theme.of(context).textTheme.bodyLarge)),
            const SizedBox(height: 12),
            if (prof != null)
              Pressable(
                onTap: () => context.push('/seller/${prof['id']}'),
                child: Row(children: [Avatar(url: prof['avatar_url'] as String?, name: prof['display_name'] as String, size: 36), const SizedBox(width: 10), Text(prof['display_name'] as String, style: Theme.of(context).textTheme.titleSmall), const Spacer(), Text(timeAgo(DateTime.parse(r['created_at'] as String), lang), style: Theme.of(context).textTheme.bodySmall)]),
              ),
            const SizedBox(height: 16),
            if (mine) Wrap(spacing: 8, runSpacing: 8, children: [
              if (open) OutlinedButton(onPressed: () => guard(context, () async { await Repo.setWantedStatus(widget.id, 'fulfilled'); _reload(); }), child: Text(context.t('wanted.mark_fulfilled'))),
              if (open) OutlinedButton(onPressed: () => guard(context, () async { await Repo.setWantedStatus(widget.id, 'closed'); _reload(); }), child: Text(context.t('wanted.close'))),
              if (!open) OutlinedButton(onPressed: () => guard(context, () async { await Repo.setWantedStatus(widget.id, 'open'); _reload(); }), child: Text(context.t('wanted.reopen'))),
            ]) else if (open) ...[
              GradientButton(
                label: context.t('wanted.make_offer'),
                icon: Icons.local_offer_rounded,
                onPressed: () async {
                  if (!requireLogin(context, ref)) return;
                  await _offerSheet(context, r);
                  _reload();
                },
              ),
              TextButton.icon(onPressed: () => showReportSheet(context, ref, 'wanted_request', widget.id), icon: const Icon(Icons.flag_outlined, size: 18), label: Text(context.t('listing.report'))),
            ],
            if (mine) ...[
              SectionHeader(context.t('wanted.offers_count', {'n': offers.length})),
              if (offers.isEmpty) Text(context.t('wanted.no_offers')),
              for (final (i, o) in offers.indexed) _OfferCard(o: o, onChange: _reload, requestId: widget.id).reveal(index: i),
            ],
          ]);
        },
      ),
    );
  }

  Future<void> _offerSheet(BuildContext context, Map<String, dynamic> r) async {
    final price = TextEditingController();
    final msg = TextEditingController();
    final mineList = (await Repo.myListings().catchError((_) => <Listing>[])).where((l) => l.status == 'active').toList();
    String? listingId;
    bool busy = false;
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
              Text(ctx.t('wanted.make_offer'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: listingId,
                isExpanded: true,
                decoration: InputDecoration(labelText: ctx.t('wanted.from_listing')),
                items: [const DropdownMenuItem<String?>(value: null, child: Text('—')), for (final l in mineList) DropdownMenuItem(value: l.id, child: Text(l.title, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => set(() {
                  listingId = v;
                  final l = mineList.where((x) => x.id == v).firstOrNull;
                  if (l != null) price.text = l.price.toString();
                }),
              ),
              const SizedBox(height: 14),
              field(price, '${ctx.t('common.price')} (${r['currency_code']})', type: TextInputType.number),
              field(msg, ctx.t('nego.note'), lines: 3),
              GradientButton(
                label: ctx.t('wanted.send_offer'),
                loading: busy,
                onPressed: () async {
                  final p = parseNum(price.text);
                  if (p == null) return;
                  set(() => busy = true);
                  try {
                    await Repo.sendOffer({'request_id': widget.id, 'listing_id': listingId, 'price': p, 'currency_code': r['currency_code'], 'message': msg.text.trim().isEmpty ? null : msg.text.trim()});
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      toast(context, context.t('wanted.offer_sent'));
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
    msg.dispose();
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.o, required this.onChange, required this.requestId});
  final Map<String, dynamic> o;
  final VoidCallback onChange;
  final String requestId;
  @override
  Widget build(BuildContext context) {
    final p = o['profiles'] as Map<String, dynamic>?;
    final l = o['listings'] as Map<String, dynamic>?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(url: p?['avatar_url'] as String?, name: (p?['display_name'] as String?) ?? '?', size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text((p?['display_name'] as String?) ?? '', style: Theme.of(context).textTheme.titleSmall)),
          StatusChip(context.t('wanted.os.${o['status']}'), tone: statusTone(o['status'] as String)),
        ]),
        const SizedBox(height: 6),
        Text(formatPrice(o['price'] as num, o['currency_code'] as String, context.lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
        if ((o['message'] as String?)?.isNotEmpty ?? false) Text(o['message'] as String),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          if (l != null) OutlinedButton(onPressed: () => context.push('/listing/${l['id']}'), child: Text(context.t('common.view'))),
          OutlinedButton(
            onPressed: () => guard(context, () async {
              final id = await Repo.startConversation(p!['id'] as String, request: requestId);
              if (context.mounted) context.push('/messages/$id');
            }),
            child: Text(context.t('listing.contact')),
          ),
          if (o['status'] == 'sent') ...[
            FilledButton(onPressed: () => guard(context, () async { await Repo.setOfferStatus(o['id'] as String, 'accepted'); onChange(); }), child: Text(context.t('nego.accept'))),
            TextButton(onPressed: () => guard(context, () async { await Repo.setOfferStatus(o['id'] as String, 'declined'); onChange(); }), child: Text(context.t('nego.decline'))),
          ],
        ]),
      ]),
    );
  }
}
