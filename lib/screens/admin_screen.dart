import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Back-office de la plateforme SaaS : validation des boutiques,
/// abonnements, modération des annonces d'occasion, vue par pays.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final pendingShops = app.shops
        .where((s) => s.status == ShopStatus.pending)
        .length;
    final pendingListings = app.listings
        .where((l) => l.status == ListingStatus.pending)
        .length;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              const Tab(text: 'Tableau de bord'),
              Tab(
                child: Badge(
                  isLabelVisible: pendingShops > 0,
                  label: Text('$pendingShops'),
                  child: const Text('Boutiques'),
                ),
              ),
              Tab(
                child: Badge(
                  isLabelVisible: pendingListings > 0,
                  label: Text('$pendingListings'),
                  child: const Text('Annonces'),
                ),
              ),
              const Tab(text: 'Pays'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_Dashboard(), _Shops(), _Listings(), _Countries()],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(
    this.label,
    this.value,
    this.icon, [
    this.color = AppColors.primary,
  ]);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    ),
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final fcfa = countries.first;
    final byPlan = {
      for (final p in Plan.values)
        p: app.shops
            .where((s) => s.plan == p && s.status == ShopStatus.active)
            .length,
    };
    final maxPlan = byPlan.values.fold(1, (a, b) => b > a ? b : a);
    return MaxWidth(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Kpi(
                'Revenu mensuel (MRR)',
                fcfa.format(app.monthlyRevenueXof),
                Icons.trending_up,
                AppColors.green,
              ),
              _Kpi(
                'Boutiques actives',
                '${app.shops.where((s) => s.status == ShopStatus.active).length}',
                Icons.storefront,
              ),
              _Kpi(
                'Produits en ligne',
                '${app.products.length}',
                Icons.inventory_2_outlined,
                AppColors.purple,
              ),
              _Kpi(
                'Annonces publiées',
                '${app.listings.where((l) => l.status == ListingStatus.published).length}',
                Icons.sell_outlined,
                const Color(0xFFEA580C),
              ),
              _Kpi(
                'Comptes visiteurs',
                '${app.visitorAccounts.length}',
                Icons.people_outline,
                AppColors.navy2,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Boutiques actives par abonnement',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  for (final e in byPlan.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(e.key.label)),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: e.value / maxPlan,
                                minHeight: 14,
                                backgroundColor: const Color(0xFFE8EEFF),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '  ${e.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shops extends StatelessWidget {
  const _Shops();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final shops = [...app.shops]
      ..sort((a, b) => a.status.index.compareTo(b.status.index));
    return MaxWidth(
      max: 900,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in shops)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: NetImage(s.logoUrl, width: 48, height: 48),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      s.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (s.verified)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.verified,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                '${countryByCode(s.countryCode).flag} ${s.city} • ${s.owner} • ${s.phone}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(s.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (s.status != ShopStatus.active)
                          FilledButton.tonalIcon(
                            onPressed: () =>
                                app.setShopStatus(s, ShopStatus.active),
                            icon: const Icon(Icons.check),
                            label: Text(
                              s.status == ShopStatus.pending
                                  ? 'Valider'
                                  : 'Réactiver',
                            ),
                          ),
                        if (s.status == ShopStatus.active)
                          OutlinedButton.icon(
                            onPressed: () =>
                                app.setShopStatus(s, ShopStatus.suspended),
                            icon: const Icon(Icons.block, color: Colors.red),
                            label: const Text('Suspendre'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => app.toggleVerified(s),
                          icon: Icon(
                            s.verified
                                ? Icons.verified
                                : Icons.verified_outlined,
                          ),
                          label: Text(
                            s.verified ? 'Retirer badge' : 'Vérifier',
                          ),
                        ),
                        DropdownButton<Plan>(
                          value: s.plan,
                          underline: const SizedBox(),
                          items: [
                            for (final p in Plan.values)
                              DropdownMenuItem(
                                value: p,
                                child: Text('Plan ${p.label}'),
                              ),
                          ],
                          onChanged: (p) => app.setShopPlan(s, p!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ShopStatus status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) => switch (status) {
    ShopStatus.active => const Badge2('ACTIVE', color: AppColors.green),
    ShopStatus.pending => const Badge2('EN ATTENTE', color: Color(0xFFD97706)),
    ShopStatus.suspended => const Badge2('SUSPENDUE', color: Colors.red),
  };
}

class _Listings extends StatelessWidget {
  const _Listings();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ls = [...app.listings]
      ..sort((a, b) => a.status.index.compareTo(b.status.index));
    return MaxWidth(
      max: 900,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final l in ls)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: NetImage(l.imageUrl, width: 52, height: 52),
                ),
                title: Text(
                  l.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${countryByCode(l.countryCode).flag} ${l.city} • ${l.sellerName} • ${countryByCode(l.countryCode).format(l.priceXof)}\n'
                  '${switch (l.status) {
                    ListingStatus.pending => 'En attente de modération',
                    ListingStatus.published => 'Publiée',
                    ListingStatus.rejected => 'Refusée',
                    ListingStatus.sold => 'Vendue',
                  }}',
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (l.status != ListingStatus.published)
                      IconButton(
                        tooltip: 'Publier',
                        onPressed: () =>
                            app.setListingStatus(l, ListingStatus.published),
                        icon: const Icon(
                          Icons.check_circle,
                          color: AppColors.green,
                        ),
                      ),
                    if (l.status != ListingStatus.rejected)
                      IconButton(
                        tooltip: 'Refuser',
                        onPressed: () =>
                            app.setListingStatus(l, ListingStatus.rejected),
                        icon: const Icon(Icons.cancel, color: Colors.red),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Countries extends StatelessWidget {
  const _Countries();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return MaxWidth(
      max: 900,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final c in countries)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Text(c.flag, style: const TextStyle(fontSize: 28)),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${app.shops.where((s) => s.countryCode == c.code && s.status == ShopStatus.active).length} boutiques • '
                  '${app.listings.where((l) => l.countryCode == c.code && l.status == ListingStatus.published).length} annonces • '
                  '${c.currency}',
                ),
                trailing: app.visitorAccounts.containsKey(c.code)
                    ? Chip(label: Text(app.visitorAccounts[c.code]!.id))
                    : const Text('—'),
              ),
            ),
        ],
      ),
    );
  }
}
