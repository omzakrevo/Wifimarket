import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class ShopsScreen extends StatelessWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final shops = app.activeShops.toList()
      ..sort(
        (a, b) => b.plan.index.compareTo(a.plan.index),
      ); // Business mis en avant
    return Scaffold(
      appBar: AppBar(
        title: Text('Boutiques ${app.country.flag}'),
        automaticallyImplyLeading: false,
      ),
      body: MaxWidth(
        max: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            _OpenShopCard(),
            const SizedBox(height: 16),
            if (shops.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Aucune boutique active en ${app.country.name} pour le moment.\n'
                  'Les produits affichés viennent des boutiques de la sous-région.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            for (final s in shops)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ShopTile(shop: s),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final Shop shop;
  const _ShopTile({required this.shop});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final count = app.products.where((p) => p.shopId == shop.id).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: NetImage(shop.logoUrl, width: 64, height: 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (shop.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${shop.city} • $count produits',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      shop.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (shop.plan == Plan.business)
                const Badge2('TOP', color: AppColors.purple),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenShopCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navy2],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOUS VENDEZ DU MATÉRIEL WIFI ?',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ouvrez votre boutique en ligne',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Gratuit pour démarrer • Mobile Money • Visible dans tout votre pays',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OpenShopScreen()),
            ),
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }
}

class ShopDetailScreen extends StatelessWidget {
  final Shop shop;
  const ShopDetailScreen({super.key, required this.shop});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.products.where((p) => p.shopId == shop.id).toList();
    final w = MediaQuery.sizeOf(context).width;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                shop.name,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(shop.logoUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x330A1230), Color(0xEE0A1230)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: MaxWidth(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.place, size: 16),
                          label: Text(shop.city),
                        ),
                        Chip(
                          avatar: const Icon(Icons.phone, size: 16),
                          label: Text(shop.phone),
                        ),
                        if (shop.verified)
                          const Chip(
                            avatar: Icon(
                              Icons.verified,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            label: Text('Boutique vérifiée'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(shop.description),
                    const SizedBox(height: 8),
                    Text(
                      '${items.length} produits',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColumns(w),
                childAspectRatio: .66,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (c, i) => ProductCard(
                  product: items[i],
                  onTap: () => openProduct(context, items[i]),
                ),
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Demande d'ouverture de boutique (SaaS) : la boutique est créée en
/// statut « en attente » puis validée par l'administrateur.
class OpenShopScreen extends StatefulWidget {
  const OpenShopScreen({super.key});
  @override
  State<OpenShopScreen> createState() => _OpenShopScreenState();
}

class _OpenShopScreenState extends State<OpenShopScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final owner = TextEditingController();
  final phone = TextEditingController();
  final city = TextEditingController();
  final desc = TextEditingController();
  Plan plan = Plan.starter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Ouvrir ma boutique')),
      body: MaxWidth(
        max: 640,
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Pays : ${app.country.flag} ${app.country.name}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: name,
                validator: req,
                decoration: const InputDecoration(
                  labelText: 'Nom de la boutique',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: owner,
                validator: req,
                decoration: const InputDecoration(
                  labelText: 'Nom du responsable',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: phone,
                validator: req,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Téléphone / WhatsApp',
                  prefixText: '${app.country.phonePrefix} ',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: city,
                validator: req,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: desc,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (spécialités, services…)',
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choisissez votre abonnement',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              for (final pl in Plan.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: plan == pl
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => setState(() => plan = pl),
                      leading: Icon(
                        plan == pl
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        pl.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(pl.perks),
                      trailing: Text(
                        pl.monthlyXof == 0
                            ? 'Gratuit'
                            : '${app.country.format(pl.monthlyXof)}/mois',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  app.applyForShop(
                    Shop(
                      id: 's${DateTime.now().millisecondsSinceEpoch}',
                      name: name.text.trim(),
                      owner: owner.text.trim(),
                      phone: '${app.country.phonePrefix} ${phone.text.trim()}',
                      city: city.text.trim(),
                      countryCode: app.country.code,
                      description: desc.text.trim(),
                      logoUrl: Img.router,
                      plan: plan,
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Demande envoyée ! Un administrateur va valider votre boutique.',
                      ),
                    ),
                  );
                },
                child: const Text('ENVOYER MA DEMANDE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
