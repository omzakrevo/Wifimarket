import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../shops/shop_share.dart';
import 'zone_home.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  final _q = TextEditingController();

  @override
  void dispose() {
    _scroll.dispose();
    _q.dispose();
    super.dispose();
  }

  void _go(String q) =>
      context.go('/search?q=${Uri.encodeQueryComponent(q.trim())}');

  Future<void> _refresh() async {
    final c = ref.read(countryProvider);
    ref.invalidate(homeRecentProvider(c));
    ref.invalidate(homeUsedProvider(c));
    ref.invalidate(homeNewProvider(c));
    ref.invalidate(homeSponsoredProvider(c));
    ref.invalidate(shopsProvider);
    ref.invalidate(categoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final country = ref.watch(countryProvider);
    final wide = isWide(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (!wide) ZoneMobileHeader(onSearch: _go),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: wide ? 20 : 6),
                      const ZoneBannerCarousel(),
                      const ZoneCategoryCircles(),
                      _Rail(
                        title: context.t('zh.trending'),
                        provider: homeSponsoredProvider(country),
                        icon: Icons.bolt_rounded,
                      ),
                      _Rail(
                        title: context.t('zh.new_shops'),
                        provider: homeNewProvider(country),
                        more: '/search?condition=new',
                      ),
                      const ZoneOfferBanner(),
                      _Rail(
                        title: context.t('zh.used_near'),
                        provider: homeUsedProvider(country),
                        more: '/used',
                      ),
                      _Rail(
                        title: context.t('home.recent'),
                        provider: homeRecentProvider(country),
                        more: '/search',
                      ),
                      const SizedBox(height: 22),
                      const _WantedBanner(),
                      const _ShopsRail(),
                      const SizedBox(height: 24),
                      const _Footer(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({
    required this.title,
    required this.provider,
    this.more,
    this.icon,
  });
  final String title;
  final FutureProvider<List<Listing>> provider;
  final String? more;
  final IconData? icon;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(provider);
    return v.when(
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title,
                  onSeeAll: more == null ? null : () => context.go(more!),
                ),
                ListingRail(items),
              ],
            ),
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title),
          SizedBox(
            height: 300,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < 4; i++)
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: ShimmerBox(width: 200, height: 320, radius: 20),
                  ),
              ],
            ),
          ),
        ],
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }
}

class _WantedBanner extends StatelessWidget {
  const _WantedBanner();
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () => context.go('/wanted'),
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: WM.signalGradient,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('nav.wanted'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.t('wanted.sub'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    context.t('home.post_wanted'),
                    style: const TextStyle(
                      color: WM.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
                Icons.travel_explore_rounded,
                color: Colors.white54,
                size: 72,
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .rotate(
                begin: -.03,
                end: .03,
                duration: 2.seconds,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    ),
  ).reveal();
}

class _ShopsRail extends ConsumerWidget {
  const _ShopsRail();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(shopsProvider);
    return v.maybeWhen(
      data: (shops) => shops.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  context.t('home.shops'),
                  onSeeAll: () => context.go('/shops'),
                ),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: shops.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => ShopTile(shops[i], index: i),
                  ),
                ),
              ],
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class ShopTile extends StatelessWidget {
  const ShopTile(this.shop, {super.key, this.index = 0});
  final Shop shop;
  final int index;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () => context.push('/shop/${shop.slug}'),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Avatar(url: shop.logoUrl, name: shop.name, size: 44),
                const Spacer(),
                Pressable(
                  onTap: () => shareShop(context, shop),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.ios_share_rounded, size: 20, color: cs.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: Text(
                    shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (shop.verified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: VerifiedMark(),
                  ),
              ],
            ),
            Text(
              [shop.city, shop.country].whereType<String>().join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ).reveal(index: index);
  }
}

class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget l(String k, String doc) => TextButton(
      onPressed: () => context.push('/info/$doc'),
      child: Text(context.t(k)),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const LogoWordmark(size: 28),
          const SizedBox(height: 6),
          Text(
            context.t('footer.zone'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              l('footer.about', 'about'),
              l('footer.safety', 'safety'),
              l('footer.terms', 'terms'),
              l('footer.privacy', 'privacy'),
              l('footer.prohibited', 'prohibited'),
            ],
          ),
        ],
      ),
    );
  }
}
