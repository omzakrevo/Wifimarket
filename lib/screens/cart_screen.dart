import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = app.country;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon panier')),
      body: app.cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: AppColors.muted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Votre panier est vide',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            )
          : MaxWidth(
              max: 760,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final line in app.cart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: NetImage(
                                  line.product.imageUrl,
                                  width: 72,
                                  height: 72,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      app.shopById(line.product.shopId)?.name ??
                                          '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    Text(
                                      c.format(line.product.priceXof),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => app.setQty(line, line.qty - 1),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text(
                                '${line.qty}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              IconButton(
                                onPressed: () => app.setQty(line, line.qty + 1),
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _row('Sous-total', c.format(app.cartTotal)),
                          _row('Livraison', 'Calculée par la boutique'),
                          const Divider(),
                          _row('Total', c.format(app.cartTotal), bold: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _checkout(context, app),
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('COMMANDER'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: TextStyle(fontWeight: bold ? FontWeight.w900 : null),
          ),
        ),
        Text(
          b,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  void _checkout(BuildContext context, AppState app) {
    String method = 'Orange Money';
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mode de paiement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              RadioGroup<String>(
                groupValue: method,
                onChanged: (v) => set(() => method = v!),
                child: Column(
                  children: [
                    for (final m in [
                      'Orange Money',
                      'Moov Money',
                      'Wave',
                      'Paiement à la livraison',
                    ])
                      RadioListTile<String>(value: m, title: Text(m)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    app.clearCart();
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Commande envoyée aux boutiques ($method) ✅',
                        ),
                      ),
                    );
                  },
                  child: const Text('CONFIRMER LA COMMANDE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
