import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

enum SortBy { relevance, priceAsc, priceDesc, rating }

class SearchScreen extends StatefulWidget {
  final String? categoryId;
  final String? title;
  final bool showFilters;
  const SearchScreen({
    super.key,
    this.categoryId,
    this.title,
    this.showFilters = false,
  });
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';
  String? cat;
  SortBy sort = SortBy.relevance;
  String? brand;

  @override
  void initState() {
    super.initState();
    cat = widget.categoryId;
    if (widget.showFilters) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _filters());
    }
  }

  void _filters() {
    final app = AppScope.read(context);
    final brands = app.visibleProducts.map((p) => p.brand).toSet().toList()
      ..sort();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trier par',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in SortBy.values)
                    ChoiceChip(
                      label: Text(switch (s) {
                        SortBy.relevance => 'Pertinence',
                        SortBy.priceAsc => 'Prix ↑',
                        SortBy.priceDesc => 'Prix ↓',
                        SortBy.rating => 'Mieux notés',
                      }),
                      selected: sort == s,
                      onSelected: (_) {
                        set(() => sort = s);
                        setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Marque',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Toutes'),
                    selected: brand == null,
                    onSelected: (_) {
                      set(() => brand = null);
                      setState(() {});
                    },
                  ),
                  for (final b in brands)
                    ChoiceChip(
                      label: Text(b),
                      selected: brand == b,
                      onSelected: (_) {
                        set(() => brand = b);
                        setState(() {});
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    var results = app.search(q, categoryId: cat);
    if (brand != null) {
      results = results.where((p) => p.brand == brand).toList();
    }
    switch (sort) {
      case SortBy.priceAsc:
        results.sort((a, b) => a.priceXof.compareTo(b.priceXof));
      case SortBy.priceDesc:
        results.sort((a, b) => b.priceXof.compareTo(a.priceXof));
      case SortBy.rating:
        results.sort((a, b) => b.rating.compareTo(a.rating));
      case SortBy.relevance:
        break;
    }
    final w = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Rechercher'),
        actions: [
          IconButton(onPressed: _filters, icon: const Icon(Icons.tune)),
        ],
      ),
      body: MaxWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                autofocus: widget.categoryId == null && !widget.showFilters,
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'MikroTik, Ubiquiti, câble Cat6…',
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Tout'),
                      selected: cat == null,
                      onSelected: (_) => setState(() => cat = null),
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(c.icon, size: 16),
                        label: Text(c.name),
                        selected: cat == c.id,
                        onSelected: (_) => setState(() => cat = c.id),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun produit trouvé',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns(w),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: .66,
                      ),
                      itemCount: results.length,
                      itemBuilder: (c, i) => ProductCard(
                        product: results[i],
                        onTap: () => openProduct(context, results[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
