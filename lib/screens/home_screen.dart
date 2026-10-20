import 'dart:async';

import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cart_screen.dart';
import 'country_screen.dart';
import 'listings_screen.dart';
import 'product_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final products = app.visibleProducts;
    final trending = products.where((p) => p.badge != null).toList();
    final w = MediaQuery.sizeOf(context).width;

    return SafeArea(
      bottom: false,
      child: MaxWidth(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(onNavigate: onNavigate)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x11000000),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: AppColors.text),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Routeurs, antennes, câbles, Starlink…',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchScreen(showFilters: true),
                        ),
                      ),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x11000000), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.tune),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _BannerCarousel(onNavigate: onNavigate)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 104,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (c, i) {
                    final cat = categories[i];
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SearchScreen(categoryId: cat.id, title: cat.name),
                        ),
                      ),
                      child: SizedBox(
                        width: 70,
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Icon(cat.icon, size: 26),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              cat.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Matériel tendance',
                onAll: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const SearchScreen(title: 'Tout le matériel'),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 250,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: trending.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (c, i) => SizedBox(
                    width: w >= 900 ? 200 : 158,
                    child: ProductCard(
                      product: trending[i],
                      onTap: () => openProduct(context, trending[i]),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _OfferBanner(onTap: () => onNavigate(3))),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Occasion près de vous',
                onAll: () => onNavigate(3),
              ),
            ),
            SliverToBoxAdapter(
              child: _ListingStrip(listings: app.publishedListings),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Tous les produits — ${app.country.name}',
                onAll: () => onNavigate(1),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns(w >= 900 ? w - 100 : w),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => ProductCard(
                    product: products[i],
                    onTap: () => openProduct(context, products[i]),
                  ),
                  childCount: products.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

void openProduct(BuildContext context, Product p) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => ProductScreen(product: p)),
);

class _Header extends StatelessWidget {
  final void Function(int) onNavigate;
  const _Header({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => onNavigate(4),
              ),
              const Expanded(child: Center(child: BrandLogo())),
              IconButton(
                icon: Badge(
                  label: Text('${app.publishedListings.length}'),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.notifications_none),
                ),
                onPressed: () => onNavigate(3),
              ),
              IconButton(
                icon: Badge(
                  isLabelVisible: app.cartCount > 0,
                  label: Text('${app.cartCount}'),
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ActionChip(
            avatar: Text(app.country.flag),
            label: Text(
              '${app.country.name} • ${app.user?.displayName ?? ''}',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CountryScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final void Function(int) onNavigate;
  const _BannerCarousel({required this.onNavigate});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final ctrl = PageController();
  int page = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!ctrl.hasClients) return;
      ctrl.animateToPage(
        (page + 1) % banners.length,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: ctrl,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => page = i),
            itemBuilder: (c, i) {
              final b = banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _DarkCard(
                  image: b.image,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          b.tag,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          b.highlight,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 210,
                          child: Text(
                            b.text,
                            maxLines: 3,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PillButton(
                          label: b.cta,
                          onTap: () => widget.onNavigate(
                            i == 2
                                ? 3
                                : i == 1
                                ? 1
                                : 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == page
                      ? AppColors.primary
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Carte sombre avec photo à droite fondue dans un dégradé (style du design).
class _DarkCard extends StatelessWidget {
  final String image;
  final Widget child;
  const _DarkCard({required this.image, required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.navy),
          Positioned.fill(left: 120, child: NetImage(image)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navy, Color(0xEE0A1230), Color(0x330A1230)],
                stops: [0.35, 0.55, 1],
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(30),
    child: InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 11,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.arrow_forward,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OfferBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _OfferBanner({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: SizedBox(
        height: 160,
        child: _DarkCard(
          image: Img.cableNet,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'SECONDE MAIN',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      'VENDEZ & ACHETEZ\nD\'OCCASION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PillButton(label: 'VOIR LES ANNONCES', onTap: onTap),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '-40%\nprix',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListingStrip extends StatelessWidget {
  final List<Listing> listings;
  const _ListingStrip({required this.listings});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (listings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Aucune annonce dans votre pays pour l\'instant. Soyez le premier !',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: listings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (c, i) {
          final l = listings[i];
          return SizedBox(
            width: 270,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: l),
                  ),
                ),
                child: Row(
                  children: [
                    NetImage(l.imageUrl, width: 90, height: 96),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${l.city} • ${timeAgo(l.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app.country.format(l.priceXof),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
