import 'package:flutter/material.dart';

import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Image réseau avec placeholder et repli si la photo ne charge pas.
class NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? height;
  final double? width;
  const NetImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      height: height,
      width: width,
      loadingBuilder: (c, child, p) => p == null
          ? child
          : Container(
              color: const Color(0xFFE8EDF7),
              height: height,
              width: width,
            ),
      errorBuilder: (c, e, s) => Container(
        color: const Color(0xFFE8EDF7),
        height: height,
        width: width,
        alignment: Alignment.center,
        child: const Icon(
          Icons.router_outlined,
          color: AppColors.primary,
          size: 36,
        ),
      ),
    );
  }
}

class BrandLogo extends StatelessWidget {
  final bool light;
  const BrandLogo({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : AppColors.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_tethering,
              color: AppColors.primary,
              size: 26,
            ),
            const SizedBox(width: 4),
            Text(
              'ZONEHUB',
              style: TextStyle(
                color: c,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const Text(
          'WIFI ZONE. CONNECTÉE.',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class Badge2 extends StatelessWidget {
  final String text;
  final Color color;
  const Badge2(this.text, {super.key, this.color = AppColors.primary});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

Color badgeColor(String b) => switch (b) {
  'TENDANCE' => AppColors.green,
  'POPULAIRE' => AppColors.purple,
  'NOUVEAU' => const Color(0xFFEA580C),
  'SaaS' => AppColors.navy2,
  _ => AppColors.primary,
};

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onAll;
  const SectionHeader(this.title, {super.key, this.onAll});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        if (onAll != null)
          TextButton.icon(
            onPressed: onAll,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text(
              'Voir tout',
              style: TextStyle(color: AppColors.text),
            ),
          ),
      ],
    ),
  );
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = product;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: NetImage(p.imageUrl),
                    ),
                  ),
                  if (p.badge != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Badge2(p.badge!, color: badgeColor(p.badge!)),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: InkWell(
                      onTap: () => app.toggleFavorite(p.id),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Icon(
                          app.favorites.contains(p.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.star,
                        size: 15,
                      ),
                      Text(
                        ' ${p.rating} (${p.reviews})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          app.country.format(p.priceXof),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          app.addToCart(p);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text('${p.name} ajouté au panier'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                        },
                        child: const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary,
                          child: Icon(
                            Icons.add_shopping_cart,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nombre de colonnes adapté : mobile 2, tablette 3-4, web 5-6.
int gridColumns(double width) {
  if (width >= 1200) return 6;
  if (width >= 900) return 5;
  if (width >= 650) return 4;
  if (width >= 480) return 3;
  return 2;
}

/// Contraint la largeur du contenu sur grand écran (web).
class MaxWidth extends StatelessWidget {
  final Widget child;
  final double max;
  const MaxWidth({super.key, required this.child, this.max = 1200});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: max),
      child: child,
    ),
  );
}

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes.clamp(1, 59)} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return 'il y a ${diff.inDays} j';
}
