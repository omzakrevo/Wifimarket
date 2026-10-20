import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';
import 'shops_screen.dart';

class ProductScreen extends StatelessWidget {
  final Product product;
  const ProductScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = product;
    final shop = app.shopById(p.shopId);
    final wide = MediaQuery.sizeOf(context).width >= 800;

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(aspectRatio: 1.2, child: NetImage(p.imageUrl)),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (p.badge != null) Badge2(p.badge!, color: badgeColor(p.badge!)),
            const SizedBox(width: 8),
            Text(
              categoryById(p.categoryId).name,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          p.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.star),
            Text(' ${p.rating}  •  ${p.reviews} avis  •  ${p.brand}'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              app.country.format(p.priceXof),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            if (p.oldPriceXof != null)
              Text(
                app.country.format(p.oldPriceXof!),
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        Text(
          p.stock > 0 ? 'En stock (${p.stock})' : 'Rupture de stock',
          style: TextStyle(
            color: p.stock > 0 ? AppColors.green : Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(p.description, style: const TextStyle(height: 1.5)),
        if (p.specs.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Caractéristiques',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          for (final s in p.specs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s)),
                ],
              ),
            ),
        ],
        if (shop != null) ...[
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(shop.logoUrl),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(shop.name, overflow: TextOverflow.ellipsis),
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
              subtitle: Text('${shop.city} • Vendu et expédié par la boutique'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
              ),
            ),
          ),
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => app.toggleFavorite(p.id),
            icon: Icon(
              app.favorites.contains(p.id)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Colors.redAccent,
            ),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: app.cartCount > 0,
              label: Text('${app.cartCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            ),
          ),
        ],
      ),
      body: MaxWidth(
        max: 1000,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: image),
                  const SizedBox(width: 24),
                  Expanded(child: info),
                ],
              )
            else ...[
              image,
              const SizedBox(height: 16),
              info,
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (shop != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Appeler / WhatsApp : ${shop.phone}'),
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Vendeur'),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: p.stock > 0
                      ? () {
                          app.addToCart(p);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ajouté au panier'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('AJOUTER AU PANIER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
