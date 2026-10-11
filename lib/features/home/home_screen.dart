import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

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
            _Hero(scroll: _scroll, ctl: _q, onSubmit: _go),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Categories(),
                      _Rail(
                        title: context.t('home.sponsored'),
                        provider: homeSponsoredProvider(country),
                        icon: Icons.bolt_rounded,
                      ),
                      _Rail(
                        title: context.t('home.recent'),
                        provider: homeRecentProvider(country),
                        more: '/search',
                      ),
                      const SizedBox(height: 22),
                      const _WantedBanner(),
                      _Rail(
                        title: context.t('home.used'),
                        provider: homeUsedProvider(country),
                        more: '/search?condition=used',
                      ),
                      _Rail(
                        title: context.t('home.new'),
                        provider: homeNewProvider(country),
                        more: '/search?condition=new',
                      ),
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

class _Hero extends ConsumerWidget {
  const _Hero({
    required this.scroll,
    required this.ctl,
    required this.onSubmit,
  });
  final ScrollController scroll;
  final TextEditingController ctl;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWide(context);
    final top = MediaQuery.paddingOf(context).top;
    return AnimatedBuilder(
      animation: scroll,
      builder: (context, _) {
        final off = scroll.hasClients ? scroll.offset.clamp(0, 400) : 0.0;
        return ClipRect(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: WM.nightGradient),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(0, off * .25),
                    child: const WifiRings(
                      rings: 5,
                      alignment: Alignment.topRight,
                    ),
                  ),
                ),
                Positioned(
                  left: -80,
                  bottom: -120 - off * .1,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          WM.signal.withValues(alpha: .35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 24 : 18,
                    (wide ? 56 : 14) + top,
                    wide ? 24 : 18,
                    wide ? 72 : 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: wide
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          if (!wide) const _MobileTop(),
                          SizedBox(height: wide ? 0 : 22),
                          Text(
                                context.t('home.hero_title'),
                                textAlign: wide
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      height: 1.08,
                                      fontSize: wide ? 52 : 32,
                                    ),
                              )
                              .animate()
                              .fadeIn(duration: Motion.slow)
                              .slideY(
                                begin: .2,
                                end: 0,
                                curve: Motion.emphasized,
                                duration: 700.ms,
                              ),
                          const SizedBox(height: 12),
                          Text(
                                context.t('home.hero_sub'),
                                textAlign: wide
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: Colors.white70),
                              )
                              .animate(delay: 150.ms)
                              .fadeIn(duration: Motion.slow)
                              .slideY(
                                begin: .25,
                                end: 0,
                                curve: Motion.emphasized,
                                duration: 700.ms,
                              ),
                          const SizedBox(height: 22),
                          Container(
                                padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: .25,
                                      ),
                                      blurRadius: 30,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.search_rounded,
                                      color: WM.slate,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: ctl,
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: onSubmit,
                                        style: const TextStyle(color: WM.ink),
                                        decoration: InputDecoration(
                                          hintText: context.t(
                                            'home.search_placeholder',
                                          ),
                                          hintStyle: const TextStyle(
                                            color: WM.slate,
                                          ),
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                        ),
                                      ),
                                    ),
                                    GradientButton(
                                      label: context.t('common.search'),
                                      expand: false,
                                      onPressed: () => onSubmit(ctl.text),
                                    ),
                                  ],
                                ),
                              )
                              .animate(delay: 300.ms)
                              .fadeIn(duration: Motion.slow)
                              .slideY(
                                begin: .3,
                                end: 0,
                                curve: Motion.emphasized,
                                duration: 700.ms,
                              ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: wide
                                ? WrapAlignment.center
                                : WrapAlignment.start,
                            children: [
                              for (final (i, t) in [
                                'MikroTik',
                                'Ubiquiti',
                                'TP-Link',
                                'Starlink',
                                'LiteBeam',
                              ].indexed)
                                Pressable(
                                  onTap: () => onSubmit(t),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(99),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Text(
                                      t,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ).reveal(index: i + 4),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileTop extends ConsumerWidget {
  const _MobileTop();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(countryProvider);
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    final logged = ref.watch(uidProvider) != null;
    final unread = ref.watch(countersProvider).notifications;
    return Row(
      children: [
        const LogoWordmark(light: true, size: 30),
        const Spacer(),
        PopupMenuButton<String>(
          tooltip: context.t('loc.title'),
          onSelected: (v) =>
              ref.read(countryProvider.notifier).set(v == '' ? null : v),
          itemBuilder: (_) => [
            PopupMenuItem(value: '', child: Text(context.t('loc.all'))),
            for (final c in countries)
              PopupMenuItem(value: c.code, child: Text(c.name(context.lang))),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  country ?? context.t('common.all'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => ref.read(langProvider.notifier).toggle(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              context.lang == 'fr' ? 'EN' : 'FR',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (logged)
          IconButton(
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final lang = context.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(context.t('home.popular_categories')),
        cats.when(
          data: (all) {
            final roots = all.where((c) => c.parentId == null).toList();
            return LayoutBuilder(
              builder: (context, b) {
                final cols = b.maxWidth > 900
                    ? 5
                    : b.maxWidth > 600
                    ? 5
                    : 3;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: roots.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: b.maxWidth > 600 ? 1.5 : 1.05,
                  ),
                  itemBuilder: (_, i) {
                    final c = roots[i];
                    final cs = Theme.of(context).colorScheme;
                    return Pressable(
                      onTap: () => context.push('/category/${c.slug}'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: .6),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: WM.signalGradient,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    categoryIcon(c.icon),
                                    color: Colors.white,
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .moveY(
                                  begin: 0,
                                  end: -3,
                                  duration: (1400 + i * 120).ms,
                                  curve: Curves.easeInOut,
                                ),
                            const SizedBox(height: 8),
                            Text(
                              c.name(lang),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ).reveal(index: i);
                  },
                );
              },
            );
          },
          loading: () => const SkeletonGrid(count: 5),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(categoriesProvider),
          ),
        ),
      ],
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
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: .6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Avatar(url: shop.logoUrl, name: shop.name, size: 44),
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
        color: cs.surfaceContainerLow,
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
