import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../home/home_screen.dart';

/// Lien public d'une boutique, partageable tel quel (ouvre directement la boutique).
String shopUrl(String slug) => '${AppConfig.siteUrl}/shop/$slug';

Future<void> shareShop(Shop s) => SharePlus.instance.share(ShareParams(text: '${s.name} — ${shopUrl(s.slug)}'));

/// Carte « lien de la boutique » : lien affiché, bouton copier et bouton partager.
class ShopLinkCard extends StatelessWidget {
  const ShopLinkCard(this.shop, {super.key});
  final Shop shop;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = shopUrl(shop.slug);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: softCard(cs),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.link_rounded, size: 20, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.t('shop.share_link'), style: Theme.of(context).textTheme.bodySmall),
            SelectableText(url.replaceFirst(RegExp(r'^https?://'), ''), maxLines: 1, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
        IconButton(
          tooltip: context.t('shop.copy_link'),
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) toast(context, context.t('shop.link_copied'));
          },
        ),
        IconButton(tooltip: context.t('shop.share'), icon: const Icon(Icons.ios_share_rounded), onPressed: () => shareShop(shop)),
      ]),
    );
  }
}

final _allShopsProvider = FutureProvider.autoDispose<List<Shop>>((ref) => Repo.shops(limit: 60));

class ShopsScreen extends ConsumerWidget {
  const ShopsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_allShopsProvider);
    return WPage(
      title: context.t('nav.shops'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t('shop.sub')),
        const SizedBox(height: 14),
        AsyncView<List<Shop>>(
          value: v,
          loading: const SkeletonGrid(),
          onRetry: () => ref.invalidate(_allShopsProvider),
          data: (shops) => shops.isEmpty
              ? EmptyState(icon: Icons.storefront_outlined, title: context.t('shop.none'))
              : LayoutBuilder(builder: (c, b) {
                  final cols = b.maxWidth > 900 ? 4 : b.maxWidth > 600 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: shops.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5),
                    itemBuilder: (_, i) => ShopTile(shops[i], index: i),
                  );
                }),
        ),
      ]),
    );
  }
}

final _shopProvider = FutureProvider.autoDispose.family<Shop?, String>((ref, slug) => Repo.shop(slug));
final _shopListingsProvider = FutureProvider.autoDispose.family<List<Listing>, SearchParams>((ref, p) => Repo.search(p, limit: 48));
final _sellerProvider = FutureProvider.autoDispose.family<Profile?, String>((ref, id) => Repo.profile(id));
final _reviewsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) => Repo.reviewsForSeller(id));

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_shopProvider(slug));
    return v.when(
      loading: () => const WPage(title: '', child: SkeletonList()),
      error: (e, _) => WPage(title: '', child: ErrorState(error: e, onRetry: () => ref.invalidate(_shopProvider(slug)))),
      data: (s) {
        if (s == null) return WPage(title: '', child: EmptyState(icon: Icons.storefront_outlined, title: context.t('error.not_found')));
        final listings = ref.watch(_shopListingsProvider(SearchParams(shop: s.id, sort: 'newest')));
        final cs = Theme.of(context).colorScheme;
        return WPage(
          title: s.name,
          actions: [IconButton(tooltip: context.t('shop.share'), icon: const Icon(Icons.ios_share_rounded), onPressed: () => shareShop(s))],
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 190,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: WM.nightGradient), clipBehavior: Clip.antiAlias, child: s.bannerUrl == null ? const WifiRings(rings: 5, alignment: Alignment.topRight) : Net(s.bannerUrl))),
                Positioned(left: 18, bottom: -30, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: cs.surface, shape: BoxShape.circle), child: Avatar(url: s.logoUrl, name: s.name, size: 76))),
              ]),
            ).reveal(),
            const SizedBox(height: 40),
            Row(children: [
              Flexible(child: Text(s.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              if (s.verified) const Padding(padding: EdgeInsets.only(left: 6), child: VerifiedMark(size: 22)),
              const SizedBox(width: 8),
              if (s.plan != 'free') Badge2(context.t('plan.${s.plan}'), color: WM.volt, fg: WM.ink),
            ]),
            Text([s.city, s.country].whereType<String>().join(' · '), style: Theme.of(context).textTheme.bodySmall),
            if ((s.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(s.description!)),
            const SizedBox(height: 12),
            ShopLinkCard(s),
            SectionHeader(context.t('shop.catalog')),
            AsyncView<List<Listing>>(value: listings, loading: const SkeletonGrid(), data: (l) => l.isEmpty ? EmptyState(icon: Icons.inventory_2_outlined, title: context.t('common.no_results')) : ListingGrid(l)),
          ]),
        );
      },
    );
  }
}

class SellerScreen extends ConsumerWidget {
  const SellerScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(_sellerProvider(id));
    final reviews = ref.watch(_reviewsProvider(id));
    final listings = ref.watch(_shopListingsProvider(SearchParams(seller: id, sort: 'newest')));
    return v.when(
      loading: () => const WPage(title: '', child: SkeletonList()),
      error: (e, _) => WPage(title: '', child: ErrorState(error: e)),
      data: (p) {
        if (p == null) return WPage(title: '', child: EmptyState(icon: Icons.person_off_outlined, title: context.t('error.not_found')));
        final rs = reviews.asData?.value ?? [];
        final avg = rs.isEmpty ? 0.0 : rs.fold<num>(0, (a, r) => a + (r['rating'] as num)) / rs.length;
        return WPage(
          title: p.displayName,
          maxWidth: 980,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar(url: p.avatarUrl, name: p.displayName, size: 80).popIn(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Flexible(child: Text(p.displayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))), if (p.verified) const Padding(padding: EdgeInsets.only(left: 6), child: VerifiedMark(size: 22))]),
                  if (p.createdAt != null) Text(context.t('profile.member_since', {'date': shortDate(p.createdAt!, context.lang)}), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Row(children: [
                    for (var i = 1; i <= 5; i++) Icon(i <= avg.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: WM.volt, size: 20),
                    const SizedBox(width: 6),
                    Text(rs.isEmpty ? context.t('profile.no_reviews') : '${avg.toStringAsFixed(1)} (${rs.length})', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ]),
              ),
            ]).reveal(),
            if ((p.bio ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(p.bio!)),
            SectionHeader(context.t('account.my_listings')),
            AsyncView<List<Listing>>(value: listings, loading: const SkeletonGrid(), data: (l) => l.isEmpty ? EmptyState(icon: Icons.inventory_2_outlined, title: context.t('common.no_results')) : ListingGrid(l)),
            if (rs.isNotEmpty) ...[
              SectionHeader(context.t('listing.reviews')),
              for (final (i, r) in rs.indexed)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: softCard(Theme.of(context).colorScheme),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(((r['profiles'] as Map?)?['display_name'] as String?) ?? '', style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      for (var s = 1; s <= 5; s++) Icon(s <= (r['rating'] as int) ? Icons.star_rounded : Icons.star_outline_rounded, color: WM.volt, size: 16),
                    ]),
                    if ((r['comment'] as String?)?.isNotEmpty ?? false) Text(r['comment'] as String),
                  ]),
                ).reveal(index: i),
            ],
          ]),
        );
      },
    );
  }
}

final _myShopsProvider = FutureProvider.autoDispose<List<Shop>>((ref) {
  ref.watch(uidProvider);
  return Repo.myShops();
});

class MyShopScreen extends ConsumerStatefulWidget {
  const MyShopScreen({super.key});
  @override
  ConsumerState<MyShopScreen> createState() => _MyShopState();
}

class _MyShopState extends ConsumerState<MyShopScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _city = TextEditingController();
  String country = 'BF';
  bool busy = false;
  String? loadedFor;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _upload(Shop s, bool banner) async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: banner ? 1800 : 600, imageQuality: 85);
    if (f == null) return;
    await guard(context, () async {
      final path = await Repo.uploadShopAsset(s.id, await f.readAsBytes(), f.name.contains('.') ? f.name.split('.').last : 'jpg');
      await Repo.updateShop(s.id, {banner ? 'banner_url' : 'logo_url': path});
      ref.invalidate(_myShopsProvider);
    }, ok: 'profile.saved');
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(_myShopsProvider);
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    return WPage(
      title: context.t('account.shop'),
      maxWidth: 800,
      child: AsyncView<List<Shop>>(
        value: v,
        onRetry: () => ref.invalidate(_myShopsProvider),
        data: (shops) {
          if (shops.isEmpty) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t('shop.create'), style: Theme.of(context).textTheme.titleLarge),
              Text(context.t('shop.create_sub')),
              const SizedBox(height: 16),
              field(_name, context.t('shop.name')),
              field(_desc, context.t('listing.description'), lines: 3),
              DropdownButtonFormField<String>(
                initialValue: countries.any((c) => c.code == country) ? country : null,
                decoration: InputDecoration(labelText: context.t('common.country')),
                items: [for (final c in countries) DropdownMenuItem(value: c.code, child: Text(c.name(context.lang)))],
                onChanged: (x) => setState(() => country = x ?? country),
              ),
              const SizedBox(height: 14),
              field(_city, context.t('common.city')),
              GradientButton(
                label: context.t('shop.create'),
                loading: busy,
                onPressed: () async {
                  if (_name.text.trim().length < 2) return;
                  setState(() => busy = true);
                  await guard(context, () async {
                    await Repo.createShop({
                      'name': _name.text.trim(),
                      'slug': '${_name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch % 100000}',
                      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                      'country_code': country,
                      'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
                    });
                    ref.invalidate(_myShopsProvider);
                  });
                  if (mounted) setState(() => busy = false);
                },
              ),
            ]);
          }
          final s = shops.first;
          if (loadedFor != s.id) {
            loadedFor = s.id;
            _name.text = s.name;
            _desc.text = s.description ?? '';
            _city.text = s.city ?? '';
          }
          return _ManageShop(shop: s, name: _name, desc: _desc, city: _city, onUpload: _upload);
        },
      ),
    );
  }
}

class _ManageShop extends ConsumerWidget {
  const _ManageShop({required this.shop, required this.name, required this.desc, required this.city, required this.onUpload});
  final Shop shop;
  final TextEditingController name, desc, city;
  final Future<void> Function(Shop, bool) onUpload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(_statsProvider(shop.id)).asData?.value;
    final cs = Theme.of(context).colorScheme;
    Widget stat(String label, Object? v) => Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: softCard(cs),
            child: Column(children: [
              v is num ? AnimatedCount(value: v, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)) : Text('${v ?? '—'}', style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Pressable(onTap: () => onUpload(shop, false), child: Stack(children: [Avatar(url: shop.logoUrl, name: shop.name, size: 72), Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(gradient: WM.signalGradient, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white)))])),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(shop.name, style: Theme.of(context).textTheme.titleLarge),
          Wrap(spacing: 6, children: [StatusChip(context.t('plan.${shop.plan}')), StatusChip(context.t('verif.${shop.verification}'), tone: statusTone(shop.verification))]),
        ])),
        OutlinedButton(onPressed: () => context.push('/shop/${shop.slug}'), child: Text(context.t('shop.view_public'))),
      ]).reveal(),
      const SizedBox(height: 12),
      ShopLinkCard(shop).reveal(index: 1),
      const SizedBox(height: 16),
      Row(children: [
        stat(context.t('shop.stat_listings'), stats?['listings_active']),
        stat(context.t('shop.stat_views'), stats?['views_total']),
        stat(context.t('shop.stat_favorites'), stats?['favorites_total']),
      ]),
      Row(children: [
        stat(context.t('shop.stat_orders'), stats?['orders_total']),
        stat(context.t('shop.stat_rating'), stats?['rating_avg'] == null ? null : (stats!['rating_avg'] as num).toStringAsFixed(1)),
        const Spacer(),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: () => onUpload(shop, true), icon: const Icon(Icons.image_outlined), label: Text(context.t('shop.banner'))),
        OutlinedButton.icon(onPressed: () => context.push('/account/listings'), icon: const Icon(Icons.inventory_2_outlined), label: Text(context.t('shop.manage_listings'))),
        if (shop.verification == 'unverified' || shop.verification == 'rejected')
          OutlinedButton.icon(onPressed: () => guard(context, () async { await Repo.requestVerification(shop.id); ref.invalidate(_myShopsProvider); }, ok: 'profile.saved'), icon: const Icon(Icons.verified_outlined), label: Text(context.t('shop.request_verification'))),
      ]),
      const Divider(height: 32),
      field(name, context.t('shop.name')),
      field(desc, context.t('listing.description'), lines: 3),
      field(city, context.t('common.city')),
      GradientButton(
        label: context.t('common.save'),
        onPressed: () => guard(context, () async {
          await Repo.updateShop(shop.id, {'name': name.text.trim(), 'description': desc.text.trim().isEmpty ? null : desc.text.trim(), 'city': city.text.trim().isEmpty ? null : city.text.trim()});
          ref.invalidate(_myShopsProvider);
        }, ok: 'profile.saved'),
      ),
      SectionHeader(context.t('shop.subscriptions')),
      Text(context.t('shop.subscription_note'), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      ref.watch(_plansProvider).maybeWhen(
            data: (plans) => Column(children: [
              for (final p in plans)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: softCard(cs),
                  child: ListTile(
                    title: Text(p['name'] as String),
                    subtitle: Text('${formatPrice(p['price'] as num, p['currency_code'] as String, context.lang)} / ${p['duration_days']} ${context.t('common.days')}'),
                    trailing: FilledButton.tonal(onPressed: () => guard(context, () => Repo.requestSubscription(shop.id, p['code'] as String), ok: 'shop.subscription_requested'), child: Text(context.t('shop.subscribe'))),
                  ),
                ),
            ]),
            orElse: () => const SizedBox.shrink(),
          ),
    ]);
  }
}

final _statsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) => Repo.shopStats(id));
final _plansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => Repo.plans('shop_subscription'));
