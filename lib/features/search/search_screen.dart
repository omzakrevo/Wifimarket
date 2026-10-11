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

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.params, this.lockedCategory = false});
  final SearchParams params;
  final bool lockedCategory;
  @override
  ConsumerState<SearchScreen> createState() => _SearchState();
}

class _SearchState extends ConsumerState<SearchScreen> {
  late SearchParams p;
  final List<Listing> items = [];
  int total = 0;
  bool loading = true, more = false, done = false;
  Object? error;
  final _q = TextEditingController();
  final _scroll = ScrollController();
  static const _page = 24;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    p = widget.params;
    _q.text = p.q ?? '';
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) _loadMore();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = ref.read(countryProvider);
      if (p.country == null && c != null) p = p.copyWith(country: c);
      _run();
    });
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (old.params != widget.params) {
      p = widget.params.copyWith(country: widget.params.country ?? ref.read(countryProvider));
      _q.text = p.q ?? '';
      _run();
    }
  }

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final gen = ++_gen;
    setState(() {
      loading = true;
      error = null;
      done = false;
    });
    try {
      final r = await Future.wait([Repo.search(p, limit: _page), Repo.count(p)]);
      if (gen != _gen || !mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(r[0] as List<Listing>);
        total = r[1] as int;
        done = items.length >= total;
        loading = false;
      });
    } catch (e) {
      if (gen != _gen || !mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (loading || more || done) return;
    setState(() => more = true);
    try {
      final r = await Repo.search(p, limit: _page, offset: items.length);
      if (!mounted) return;
      setState(() {
        items.addAll(r);
        done = r.length < _page || items.length >= total;
        more = false;
      });
    } catch (_) {
      if (mounted) setState(() => more = false);
    }
  }

  void _apply(SearchParams np) {
    p = np;
    _run();
  }

  Future<void> _openFilters() async {
    final r = await showModalBottomSheet<SearchParams>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FiltersSheet(initial: p, lockedCategory: widget.lockedCategory),
    );
    if (r != null) _apply(r);
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).asData?.value ?? [];
    final cat = cats.where((c) => c.slug == p.category).firstOrNull;
    final lang = context.lang;
    final cs = Theme.of(context).colorScheme;
    final wide = isWide(context);
    final logged = ref.watch(uidProvider) != null;
    final title = cat != null ? cat.name(lang) : context.t('search.title');

    return WPage(
      title: wide ? title : null,
      scroll: false,
      padding: EdgeInsets.zero,
      child: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, wide ? 4 : MediaQuery.paddingOf(context).top + 12, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!wide) Text(title, style: Theme.of(context).textTheme.headlineSmall).reveal(),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _q,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) => _apply(p.copyWith(q: v.trim().isEmpty ? null : v.trim())),
                      decoration: InputDecoration(
                        hintText: context.t('home.search_placeholder'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _q.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _q.clear();
                                  _apply(p.copyWith(q: null));
                                },
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Pressable(
                    onTap: _openFilters,
                    child: Badge(
                      isLabelVisible: p.activeFilters > 0,
                      label: Text('${p.activeFilters}'),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: cs.surfaceContainer, shape: BoxShape.circle, boxShadow: WM.softShadow(.08)),
                        child: Icon(Icons.tune_rounded, color: cs.primary),
                      ),
                    ),
                  ),
                ]).reveal(index: 1),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    for (final s in const ['relevance', 'newest', 'price_asc', 'price_desc'])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text(context.t('search.sort_$s')), selected: p.sort == s, onSelected: (_) => _apply(p.copyWith(sort: s))),
                      ),
                    for (final c in conditions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(label: Text(context.t('cond.$c')), selected: p.condition == c, onSelected: (v) => _apply(p.copyWith(condition: v ? c : null))),
                      ),
                  ]),
                ).reveal(index: 2),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: AnimatedSwitcher(duration: Motion.quick, child: Text(loading ? '…' : context.t('search.count', {'n': total}), key: ValueKey(total), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)))),
                  if (logged && !loading && (p.q != null || p.activeFilters > 0))
                    TextButton.icon(
                      onPressed: () => guard(context, () => Repo.saveSearch(p, ref.read(categoriesProvider).asData?.value ?? []), ok: 'search.saved'),
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: Text(context.t('search.save')),
                    ),
                  if (p.activeFilters > 0) TextButton(onPressed: () => _apply(SearchParams(q: p.q, category: widget.lockedCategory ? p.category : null)), child: Text(context.t('common.reset'))),
                ]),
              ]),
            ),
          ),
          if (loading)
            const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 16), sliver: SliverToBoxAdapter(child: SkeletonGrid(count: 8)))
          else if (error != null)
            SliverFillRemaining(hasScrollBody: false, child: ErrorState(error: error!, onRetry: _run))
          else if (items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.search_off_rounded, title: context.t('common.no_results'), body: context.t('search.no_results_hint'), action: () => context.push('/wanted/new'), actionLabel: context.t('home.post_wanted')))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverLayoutBuilder(builder: (context, c) {
                final cols = gridColumns(c.crossAxisExtent);
                return SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .66),
                  itemCount: items.length,
                  itemBuilder: (_, i) => ListingCard(items[i], index: i % cols),
                );
              }),
            ),
          if (more) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.initial, required this.lockedCategory});
  final SearchParams initial;
  final bool lockedCategory;
  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersState();
}

class _FiltersState extends ConsumerState<_FiltersSheet> {
  late SearchParams p = widget.initial;
  late final _min = TextEditingController(text: p.min?.toString() ?? '');
  late final _max = TextEditingController(text: p.max?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final cats = ref.watch(categoriesProvider).asData?.value ?? [];
    final brands = ref.watch(brandsProvider).asData?.value ?? [];
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    final cities = (ref.watch(citiesProvider).asData?.value ?? []).where((c) => c.country == p.country).toList();
    final roots = cats.where((c) => c.parentId == null).toList();

    Widget dd<T>(String label, T? value, List<DropdownMenuItem<T?>> items, ValueChanged<T?> on) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<T?>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [DropdownMenuItem<T?>(value: null, child: Text(context.t('common.all'))), ...items],
            onChanged: on,
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('search.filters'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (!widget.lockedCategory)
              dd<String>(context.t('common.category'), p.category, [
                for (final r in roots) ...[
                  DropdownMenuItem(value: r.slug, child: Text(r.name(lang), style: const TextStyle(fontWeight: FontWeight.w800))),
                  for (final c in cats.where((c) => c.parentId == r.id)) DropdownMenuItem(value: c.slug, child: Text('   ${c.name(lang)}')),
                ]
              ], (v) => setState(() => p = p.copyWith(category: v))),
            dd<String>(context.t('common.brand'), p.brand, [for (final b in brands) DropdownMenuItem(value: b.slug, child: Text(b.name))], (v) => setState(() => p = p.copyWith(brand: v))),
            dd<String>(context.t('common.country'), p.country, [for (final c in countries) DropdownMenuItem(value: c.code, child: Text(c.name(lang)))], (v) => setState(() => p = p.copyWith(country: v, city: null))),
            if (p.country != null) dd<String>(context.t('common.city'), p.city, [for (final c in cities) DropdownMenuItem(value: c.name, child: Text(c.name))], (v) => setState(() => p = p.copyWith(city: v))),
            dd<String>(context.t('common.currency'), p.currency, [for (final c in const ['XOF', 'GNF', 'EUR', 'USD', 'NGN', 'GHS']) DropdownMenuItem(value: c, child: Text(c))], (v) => setState(() => p = p.copyWith(currency: v))),
            Row(children: [
              Expanded(child: field(_min, context.t('search.min'), type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: field(_max, context.t('search.max'), type: TextInputType.number)),
            ]),
            if ((_min.text.isNotEmpty || _max.text.isNotEmpty) && p.currency == null)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.t('search.currency_warning'), style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))),
            dd<int>(context.t('search.published'), p.sinceDays, [
              DropdownMenuItem(value: 1, child: Text(context.t('search.last_24h'))),
              DropdownMenuItem(value: 7, child: Text(context.t('search.last_7d'))),
              DropdownMenuItem(value: 30, child: Text(context.t('search.last_30d'))),
            ], (v) => setState(() => p = p.copyWith(sinceDays: v))),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.t('search.in_stock')), value: p.inStock, onChanged: (v) => setState(() => p = p.copyWith(inStock: v))),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.t('search.delivery_only')), value: p.delivery, onChanged: (v) => setState(() => p = p.copyWith(delivery: v))),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.t('search.exchange_only')), value: p.exchange, onChanged: (v) => setState(() => p = p.copyWith(exchange: v))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, SearchParams(q: p.q, category: widget.lockedCategory ? p.category : null, sort: p.sort)), child: Text(context.t('common.reset')))),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: context.t('common.apply'),
                  onPressed: () => Navigator.pop(context, p.copyWith(min: parseNum(_min.text), max: parseNum(_max.text))),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
