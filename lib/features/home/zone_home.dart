import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../orders/cart_screens.dart';
import '../search/search_screen.dart';

/// Éléments du design ZoneHub : en-tête mobile, bannières, catégories en cercles,
/// sélecteur de pays au premier lancement et compte visiteur par pays.

/// Photos libres de droits (Licence Unsplash).
class ZImg {
  ZImg._();
  static const _q = '?auto=format&fit=crop&w=900&q=70';
  static const tower = 'https://images.unsplash.com/photo-1742534620800-fc7caae0dd45$_q';
  static const dish = 'https://images.unsplash.com/photo-1590433333434-09df2b2a35a5$_q';
  static const cableNet = 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31$_q';
}

String flagOf(String? code) {
  if (code == null || code.length != 2) return '🌍';
  return String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => c + 127397));
}

// ---------------------------------------------------------------------------
// Pays au premier lancement + compte visiteur par pays (stockés sur l'appareil)
// ---------------------------------------------------------------------------

class CountryChosenNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    SharedPreferences.getInstance().then((p) => state = p.getBool('zh_country_chosen') ?? false).catchError((_) => state = true);
    return null; // inconnu tant que les préférences ne sont pas lues
  }

  Future<void> choose(WidgetRef ref, String? code) async {
    await ref.read(countryProvider.notifier).set(code);
    if (code != null) await visitorIdFor(code);
    final p = await SharedPreferences.getInstance();
    await p.setBool('zh_country_chosen', true);
    state = true;
    ref.invalidate(visitorAccountsProvider);
  }
}

final countryChosenProvider = NotifierProvider<CountryChosenNotifier, bool?>(CountryChosenNotifier.new);

/// Retourne (et crée si besoin) l'identifiant visiteur de ce pays, ex. « BF-48213 ».
Future<String> visitorIdFor(String code) async {
  final p = await SharedPreferences.getInstance();
  final key = 'zh_visitor_$code';
  final existing = p.getString(key);
  if (existing != null) return existing;
  final id = '$code-${Random().nextInt(90000) + 10000}';
  await p.setString(key, id);
  return id;
}

/// Comptes visiteurs déjà créés sur cet appareil : code pays → identifiant.
final visitorAccountsProvider = FutureProvider<Map<String, String>>((ref) async {
  final p = await SharedPreferences.getInstance();
  return {
    for (final k in p.getKeys().where((k) => k.startsWith('zh_visitor_'))) k.substring(11): p.getString(k) ?? '',
  };
});

class CountryPickerScreen extends ConsumerWidget {
  const CountryPickerScreen({super.key, this.firstRun = false});
  final bool firstRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = ref.watch(countriesProvider);
    final current = ref.watch(countryProvider);
    final accounts = ref.watch(visitorAccountsProvider).asData?.value ?? const {};
    final lang = context.lang;
    final bg = firstRun ? WM.ink : Theme.of(context).colorScheme.surface;
    final fg = firstRun ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final tile = firstRun ? WM.midnight : Theme.of(context).colorScheme.surfaceContainer;
    final muted = firstRun ? Colors.white60 : Theme.of(context).colorScheme.onSurfaceVariant;

    Future<void> pick(String? code) async {
      await ref.read(countryChosenProvider.notifier).choose(ref, code);
      if (!firstRun && context.mounted) Navigator.of(context).maybePop();
    }

    Widget item(String flag, String name, String sub, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: tile,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Text(flag, style: const TextStyle(fontSize: 28)),
              title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
              subtitle: Text(sub, style: TextStyle(color: muted)),
              trailing: Icon(selected ? Icons.check_circle : Icons.chevron_right, color: selected ? WM.signal : muted),
              onTap: onTap,
            ),
          ),
        );

    return Scaffold(
      backgroundColor: bg,
      appBar: firstRun ? null : AppBar(title: Text(context.t('zh.change_country'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              if (firstRun) ...[
                const SizedBox(height: 16),
                const Center(child: ZoneLogo(light: true)),
                const SizedBox(height: 26),
                Text('${context.t('zh.welcome')} 👋',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(context.t('zh.pick_country'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
                const SizedBox(height: 24),
              ],
              countries.when(
                data: (list) => Column(children: [
                  for (final c in list)
                    item(
                      flagOf(c.code),
                      c.name(lang),
                      [c.currency, if (accounts.containsKey(c.code)) '${context.t('zh.existing_account')} ${accounts[c.code]}'].join(' • '),
                      current == c.code,
                      () => pick(c.code),
                    ),
                  item('🌍', context.t('zh.all_countries'), '', current == null && !firstRun, () => pick(null)),
                ]),
                loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(countriesProvider)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo, en-tête, recherche
// ---------------------------------------------------------------------------

class ZoneLogo extends StatelessWidget {
  const ZoneLogo({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_tethering, color: WM.signalDeep, size: 26),
        const SizedBox(width: 4),
        Text('WIFIMARKET', style: TextStyle(color: c, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ]),
      Text(context.t('zh.tagline'),
          style: const TextStyle(color: WM.signalDeep, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2)),
    ]);
  }
}

/// En-tête mobile : menu, logo centré, notifications, panier, puis pays + recherche.
class ZoneMobileHeader extends ConsumerWidget {
  const ZoneMobileHeader({super.key, required this.onSearch});
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final counters = ref.watch(countersProvider);
    final logged = ref.watch(uidProvider) != null;
    final cartCount = logged ? (ref.watch(cartProvider).asData?.value ?? const []).fold<int>(0, (a, l) => a + l.qty) : 0;
    final country = ref.watch(countryProvider);
    final countries = ref.watch(countriesProvider).asData?.value ?? const <Country>[];
    final cName = countries.where((c) => c.code == country).map((c) => c.name(context.lang)).firstOrNull;
    final visitor = country == null ? null : ref.watch(visitorAccountsProvider).asData?.value[country];

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
        child: Column(children: [
          Row(children: [
            IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => context.go('/account')),
            const Expanded(child: Center(child: ZoneLogo())),
            IconButton(
              icon: Badge(isLabelVisible: counters.notifications > 0, label: Text('${counters.notifications}'), child: const Icon(Icons.notifications_none_rounded)),
              onPressed: () => context.push('/notifications'),
            ),
            IconButton(
              icon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: const Icon(Icons.shopping_cart_outlined)),
              onPressed: () => context.push('/cart'),
            ),
          ]),
          ActionChip(
            avatar: Text(flagOf(country)),
            label: Text(
              [cName ?? context.t('zh.all_countries'), if (!logged && visitor != null) context.t('zh.visitor', {'id': visitor})].join(' • '),
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CountryPickerScreen())),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearch,
                  decoration: InputDecoration(
                    hintText: context.t('home.search_placeholder'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: cs.surfaceContainer,
                shape: const CircleBorder(),
                elevation: 0,
                child: IconButton(icon: const Icon(Icons.tune_rounded), onPressed: () => context.go('/search')),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bannières
// ---------------------------------------------------------------------------

class ZoneDarkCard extends StatelessWidget {
  const ZoneDarkCard({super.key, required this.image, required this.child});
  final String image;
  final Widget child;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(fit: StackFit.expand, children: [
          const ColoredBox(color: WM.ink),
          Positioned.fill(left: 120, child: Net(image)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [WM.ink, Color(0xEE0A1220), Color(0x330A1220)], stops: [0.35, 0.55, 1]),
            ),
          ),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ]),
      );
}

class ZonePill extends StatelessWidget {
  const ZonePill({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: BoxDecoration(color: WM.signalDeep, borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(width: 8),
            const CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.arrow_forward, size: 14, color: WM.signalDeep)),
          ]),
        ),
      );
}

class ZoneBannerCarousel extends StatefulWidget {
  const ZoneBannerCarousel({super.key});
  @override
  State<ZoneBannerCarousel> createState() => _ZoneBannerCarouselState();
}

class _ZoneBannerCarouselState extends State<ZoneBannerCarousel> {
  final _ctrl = PageController();
  int _page = 0;
  Timer? _timer;

  static const _banners = [
    ('zh.b1', ZImg.tower, '/search?condition=new'),
    ('zh.b2', ZImg.dish, '/search?q=starlink'),
    ('zh.b3', ZImg.cableNet, '/sell'),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_ctrl.hasClients) return;
      _ctrl.animateToPage((_page + 1) % _banners.length, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return Column(children: [
      SizedBox(
        height: wide ? 280 : 210,
        child: PageView.builder(
          controller: _ctrl,
          itemCount: _banners.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (c, i) {
            final (k, img, to) = _banners[i];
            return ZoneDarkCard(
              image: img,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(context.t('${k}_tag'), style: const TextStyle(color: WM.signal, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(context.t('${k}_title'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                  Text(context.t('${k}_high'), style: const TextStyle(color: WM.signal, fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 220,
                    child: Text(context.t('${k}_text'), maxLines: 3, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3)),
                  ),
                  const SizedBox(height: 10),
                  ZonePill(label: context.t('${k}_cta'), onTap: () => context.push(to)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < _banners.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == _page ? WM.signalDeep : Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ]),
    ]);
  }
}

class ZoneOfferBanner extends StatelessWidget {
  const ZoneOfferBanner({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22),
        child: SizedBox(
          height: 160,
          child: ZoneDarkCard(
            image: ZImg.cableNet,
            child: Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(context.t('zh.offer_tag'), style: const TextStyle(color: WM.signal, fontWeight: FontWeight.w800, fontSize: 12)),
                    SizedBox(
                      width: 220,
                      child: Text(context.t('zh.offer_title'),
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.05)),
                    ),
                    const SizedBox(height: 10),
                    ZonePill(label: context.t('zh.offer_cta'), onTap: () => context.go('/used')),
                  ]),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: WM.signalDeep, shape: BoxShape.circle),
                child: Text(context.t('zh.offer_badge'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Catégories en cercles (rangée de l'accueil) et page Catégories
// ---------------------------------------------------------------------------

class ZoneCategoryCircles extends ConsumerWidget {
  const ZoneCategoryCircles({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final cats = ref.watch(categoriesProvider).asData?.value ?? const <Category>[];
    final roots = cats.where((c) => c.parentId == null).toList();
    if (roots.isEmpty) return const SizedBox(height: 16);
    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 16),
        scrollDirection: Axis.horizontal,
        itemCount: roots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (c, i) {
          final cat = roots[i];
          return Pressable(
            onTap: () => context.push('/category/${cat.slug}'),
            child: SizedBox(
              width: 72,
              child: Column(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: cs.surfaceContainer, shape: BoxShape.circle, border: Border.all(color: cs.outline)),
                  child: Icon(categoryIcon(cat.icon), size: 26, color: cs.onSurface),
                ),
                const SizedBox(height: 6),
                Text(cat.name(context.lang),
                    maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, height: 1.1)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});
  static const _images = [ZImg.tower, ZImg.dish, ZImg.cableNet];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final w = MediaQuery.sizeOf(context).width;
    return WPage(
      title: context.t('zh.categories'),
      child: cats.when(
        data: (all) {
          final roots = all.where((c) => c.parentId == null).toList();
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: w >= 900 ? 4 : w >= 600 ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: roots.length,
            itemBuilder: (c, i) {
              final cat = roots[i];
              return Pressable(
                onTap: () => context.push('/category/${cat.slug}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(fit: StackFit.expand, children: [
                    Net(_images[i % _images.length]),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x110A1220), Color(0xEE0A1220)]),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        CircleAvatar(backgroundColor: Colors.white, child: Icon(categoryIcon(cat.icon), color: WM.signalDeep)),
                        Text(cat.name(context.lang),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                    ),
                  ]),
                ),
              ).reveal(index: i);
            },
          );
        },
        loading: () => const SkeletonGrid(count: 6),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
      ),
    );
  }
}

/// Onglet « Occasion » : annonces d'occasion du pays + bouton de publication.
class UsedScreen extends StatelessWidget {
  const UsedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: isWide(context) ? 0 : 8),
          child: FloatingActionButton.extended(
            heroTag: 'zh-post',
            backgroundColor: WM.signalDeep,
            foregroundColor: Colors.white,
            onPressed: () => context.push('/sell'),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.t('zh.post_listing')),
          ),
        ),
        body: SearchScreen(key: const ValueKey('used'), params: SearchParams(condition: 'used')),
      );
}
