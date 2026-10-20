import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'shops_screen.dart';

/// Espace vendeur : gestion de la boutique, des produits et de l'abonnement.
class SellerScreen extends StatelessWidget {
  const SellerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final shop = app.user?.shopId == null
        ? null
        : app.shopById(app.user!.shopId!);

    if (shop == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Espace vendeur')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 10),
                const Text('Vous n\'avez pas encore de boutique dans ce pays.'),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OpenShopScreen()),
                  ),
                  child: const Text('OUVRIR MA BOUTIQUE'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final items = app.products.where((p) => p.shopId == shop.id).toList();
    final stockValue = items.fold(0, (a, p) => a + p.priceXof * p.stock);
    final pending = shop.status == ShopStatus.pending;

    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      floatingActionButton: pending
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: items.length >= shop.plan.productLimit
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Limite de votre abonnement atteinte — passez au plan supérieur.',
                        ),
                      ),
                    )
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(shop: shop),
                      ),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un produit'),
            ),
      body: MaxWidth(
        max: 900,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (pending)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '⏳ Boutique en attente de validation par l\'administrateur. Vous pourrez ajouter vos produits dès son activation.',
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Stat(
                  'Produits',
                  '${items.length}/${shop.plan.productLimit > 9999 ? '∞' : shop.plan.productLimit}',
                  Icons.inventory_2_outlined,
                ),
                _Stat(
                  'Valeur du stock',
                  app.country.format(stockValue),
                  Icons.payments_outlined,
                ),
                _Stat(
                  'Abonnement',
                  shop.plan.label,
                  Icons.workspace_premium_outlined,
                ),
                _Stat('Statut', switch (shop.status) {
                  ShopStatus.active => 'Active',
                  ShopStatus.pending => 'En attente',
                  ShopStatus.suspended => 'Suspendue',
                }, Icons.toggle_on_outlined),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mon abonnement',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<Plan>(
                      segments: [
                        for (final p in Plan.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {shop.plan},
                      onSelectionChanged: (s) => app.setShopPlan(shop, s.first),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${shop.plan.perks} — ${shop.plan.monthlyXof == 0 ? 'gratuit' : '${app.country.format(shop.plan.monthlyXof)}/mois'}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mes produits',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final p in items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: NetImage(p.imageUrl, width: 52, height: 52),
                  ),
                  title: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${app.country.format(p.priceXof)} • stock ${p.stock}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductFormScreen(shop: shop, product: p),
                          ),
                        );
                      } else {
                        app.removeProduct(p);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'del', child: Text('Supprimer')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 200,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProductFormScreen extends StatefulWidget {
  final Shop shop;
  final Product? product;
  const ProductFormScreen({super.key, required this.shop, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.product?.name);
  late final brand = TextEditingController(text: widget.product?.brand);
  late final price = TextEditingController(
    text: widget.product?.priceXof.toString(),
  );
  late final stock = TextEditingController(
    text: (widget.product?.stock ?? 1).toString(),
  );
  late final desc = TextEditingController(text: widget.product?.description);
  late final specs = TextEditingController(
    text: widget.product?.specs.join('\n'),
  );
  late String cat = widget.product?.categoryId ?? categories.first.id;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Obligatoire' : null;
    String? num(String? v) =>
        int.tryParse(v ?? '') == null ? 'Nombre attendu' : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Nouveau produit' : 'Modifier'),
      ),
      body: MaxWidth(
        max: 640,
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: name,
                validator: req,
                decoration: const InputDecoration(labelText: 'Nom du produit'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: brand,
                validator: req,
                decoration: const InputDecoration(
                  labelText: 'Marque (MikroTik, Ubiquiti, TP-Link…)',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: cat,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                items: [
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => cat = v!),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: price,
                      validator: num,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prix (FCFA)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: stock,
                      validator: num,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: specs,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Caractéristiques (une par ligne)',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  final specList = specs.text
                      .split('\n')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  final p = widget.product;
                  if (p != null) {
                    p
                      ..name = name.text.trim()
                      ..brand = brand.text.trim()
                      ..priceXof = int.parse(price.text)
                      ..stock = int.parse(stock.text)
                      ..description = desc.text.trim()
                      ..specs = specList;
                    app.setShopPlan(
                      widget.shop,
                      widget.shop.plan,
                    ); // rafraîchit l'UI
                  } else {
                    app.addProduct(
                      Product(
                        id: 'p${DateTime.now().millisecondsSinceEpoch}',
                        shopId: widget.shop.id,
                        categoryId: cat,
                        name: name.text.trim(),
                        brand: brand.text.trim(),
                        description: desc.text.trim().isEmpty
                            ? name.text.trim()
                            : desc.text.trim(),
                        specs: specList,
                        priceXof: int.parse(price.text),
                        stock: int.parse(stock.text),
                        rating: 0,
                        reviews: 0,
                        imageUrl: CategoryImages.of(cat),
                        badge: 'NOUVEAU',
                      ),
                    );
                  }
                  Navigator.pop(context);
                },
                child: const Text('ENREGISTRER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryImages {
  static String of(String cat) => switch (cat) {
    'routers' => Img.router,
    'ap' => Img.tower,
    'ptp' => Img.tower3,
    'switch' => Img.switchPoe,
    'cables' => Img.cableRoll,
    'power' => Img.space,
    'sat' => Img.dish,
    _ => Img.pos,
  };
}
