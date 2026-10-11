import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import '../nego/nego_screens.dart';
import 'report_sheet.dart';

class ListingScreen extends ConsumerStatefulWidget {
  const ListingScreen({super.key, required this.id, this.initial});
  final String id;
  final Listing? initial;
  @override
  ConsumerState<ListingScreen> createState() => _State();
}

class _State extends ConsumerState<ListingScreen> {
  int _page = 0;
  final _pc = PageController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Repo.view(widget.id);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(listingProvider(widget.id));
    final l = v.asData?.value ?? widget.initial;
    if (l == null) {
      return v.when(
        data: (_) => const WPage(title: '', child: EmptyState(icon: Icons.search_off_rounded, title: 'Introuvable')),
        error: (e, _) => WPage(title: '', child: ErrorState(error: e, onRetry: () => ref.invalidate(listingProvider(widget.id)))),
        loading: () => const WPage(title: '', child: SkeletonList(count: 3)),
      );
    }
    final wide = isWide(context);
    final gallery = _Gallery(l: l, ctl: _pc, onPage: (i) => setState(() => _page = i), page: _page);
    final info = _Info(l: l, busy: _busy, setBusy: (b) => setState(() => _busy = b));
    return Scaffold(
      body: SafeArea(
        top: wide,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: wide
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 6, child: gallery),
                        const SizedBox(width: 28),
                        Expanded(flex: 5, child: info),
                      ]),
                    )
                  : Column(children: [gallery, info]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Gallery extends ConsumerWidget {
  const _Gallery({required this.l, required this.ctl, required this.onPage, required this.page});
  final Listing l;
  final PageController ctl;
  final ValueChanged<int> onPage;
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = ([...l.media]..sort((a, b) => a.position.compareTo(b.position)));
    final fav = ref.watch(favoritesProvider.select((s) => s.contains(l.id)));
    final wide = isWide(context);
    final top = MediaQuery.paddingOf(context).top;
    Widget circle(IconData i, VoidCallback f) => Pressable(
          onTap: f,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .38), shape: BoxShape.circle),
            child: Icon(i, color: Colors.white, size: 22),
          ),
        );
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(wide ? 24 : 0),
        child: AspectRatio(
          aspectRatio: wide ? 1.1 : 1.0,
          child: Stack(fit: StackFit.expand, children: [
            media.isEmpty
                ? Hero(tag: 'img-${l.id}', child: const Net(null))
                : PageView.builder(
                    controller: ctl,
                    onPageChanged: onPage,
                    itemCount: media.length,
                    itemBuilder: (_, i) {
                      final m = media[i];
                      if (!m.isImage) {
                        return GestureDetector(
                          onTap: () => launchUrl(Uri.parse(m.url), mode: LaunchMode.externalApplication),
                          child: Container(color: WM.ink, child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 72))),
                        );
                      }
                      final img = GestureDetector(onTap: () => _zoom(context, media.where((x) => x.isImage).toList(), i), child: Net(m.url));
                      return i == 0 ? Hero(tag: 'img-${l.id}', child: img) : img;
                    },
                  ),
            Positioned(
              left: 12,
              top: 12 + (wide ? 0 : top),
              child: circle(Icons.arrow_back_rounded, () => context.canPop() ? context.pop() : context.go('/')),
            ),
            Positioned(
              right: 12,
              top: 12 + (wide ? 0 : top),
              child: Row(children: [
                circle(Icons.ios_share_rounded, () => SharePlus.instance.share(ShareParams(text: '${l.title} — ${AppConfig.siteUrl}/listing/${l.id}'))),
                const SizedBox(width: 8),
                HeartButton(
                  active: fav,
                  size: 24,
                  onTap: () {
                    if (!requireLogin(context, ref)) return;
                    guard(context, () async {
                      await ref.read(favoritesProvider.notifier).toggle(l.id);
                    });
                  },
                ),
              ]),
            ),
            if (media.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < media.length; i++)
                    AnimatedContainer(
                      duration: Motion.base,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: page == i ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(color: page == i ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(9)),
                    ),
                ]),
              ),
          ]),
        ),
      ),
      if (media.length > 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: media.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Pressable(
                onTap: () => ctl.animateToPage(i, duration: Motion.base, curve: Motion.emphasized),
                child: AnimatedContainer(
                  duration: Motion.quick,
                  width: 64,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: page == i ? WM.signal : Colors.transparent, width: 2)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(10), child: media[i].isImage ? Net(media[i].url) : Container(color: WM.ink, child: const Icon(Icons.videocam_rounded, color: Colors.white))),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  void _zoom(BuildContext context, List<Media> imgs, int start) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          PageView.builder(
            controller: PageController(initialPage: start.clamp(0, imgs.length - 1)),
            itemCount: imgs.length,
            itemBuilder: (_, i) => InteractiveViewer(minScale: 1, maxScale: 5, child: Center(child: Net(imgs[i].url, fit: BoxFit.contain))),
          ),
          Positioned(top: 16, right: 16, child: SafeArea(child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: Colors.white)))),
        ]),
      ),
    );
  }
}

class _Info extends ConsumerWidget {
  const _Info({required this.l, required this.busy, required this.setBusy});
  final Listing l;
  final bool busy;
  final ValueChanged<bool> setBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final cs = Theme.of(context).colorScheme;
    final me = ref.watch(uidProvider);
    final mine = me == l.sellerId;
    final cats = ref.watch(categoriesProvider).asData?.value ?? [];
    final attrs = ref.watch(_attrsProvider(l.id)).asData?.value ?? {};
    final similar = ref.watch(_similarProvider(l));
    final canBuy = l.status == 'active' && l.quantity > 0 && !mine;

    Future<void> contact() async {
      if (!requireLogin(context, ref)) return;
      setBusy(true);
      try {
        final id = await Repo.startConversation(l.sellerId, listing: l.id);
        if (context.mounted) context.push('/messages/$id');
      } catch (e) {
        if (context.mounted) toast(context, errMsg(context, e), error: true);
      } finally {
        setBusy(false);
      }
    }

    Future<void> whatsapp() async {
      if (!requireLogin(context, ref)) return;
      await guard(context, () async {
        final n = await Repo.whatsapp(l.sellerId);
        if (n == null || n.isEmpty) throw Exception('not_allowed');
        await launchUrl(Uri.parse('https://wa.me/${n.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(l.title)}'), mode: LaunchMode.externalApplication);
      });
    }

    Future<void> addToCart() async {
      if (!requireLogin(context, ref)) return;
      await guard(context, () async {
        await Repo.cartSet(l.id, 1);
        if (context.mounted) context.push('/cart');
      });
    }

    final catName = cats.where((c) => c.id == l.categoryId).firstOrNull?.name(lang) ?? l.categoryName(lang);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (l.isSponsoredNow) Badge2(context.t('listing.sponsored'), color: WM.volt, fg: WM.ink, icon: Icons.bolt_rounded),
          Badge2(context.t('cond.${l.condition}'), color: WM.signalDeep),
          if (l.status != 'active') StatusChip(context.t('status.${l.status}'), tone: statusTone(l.status)),
          if (catName != null) Badge2(catName, color: cs.secondaryContainer, fg: cs.onSecondaryContainer),
        ]).reveal(),
        const SizedBox(height: 12),
        Text(l.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)).reveal(index: 1),
        const SizedBox(height: 8),
        AnimatedCount(value: l.price, format: (v) => formatPrice(v, l.currency, lang), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)).reveal(index: 2),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _Meta(Icons.place_outlined, [l.city, l.country].whereType<String>().join(', ')),
          _Meta(Icons.schedule_rounded, timeAgo(l.publishedAt ?? l.createdAt, lang)),
          _Meta(Icons.visibility_outlined, '${l.views} ${context.t('listing.views')}'),
          _Meta(Icons.inventory_2_outlined, '${context.t('listing.quantity')} : ${l.quantity}'),
        ]).reveal(index: 3),
        if (l.status == 'rejected' && l.rejectionReason != null && mine)
          Padding(padding: const EdgeInsets.only(top: 12), child: Material(color: WM.coral.withValues(alpha: .12), borderRadius: BorderRadius.circular(14), child: Padding(padding: const EdgeInsets.all(12), child: Text(l.rejectionReason!)))),
        const SizedBox(height: 18),
        if (mine) _OwnerActions(l: l) else ...[
          if (canBuy) GradientButton(label: context.t('listing.buy'), icon: Icons.shopping_bag_rounded, onPressed: busy ? null : addToCart).reveal(index: 4),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: busy ? null : contact, icon: const Icon(Icons.chat_bubble_outline_rounded), label: Text(context.t('listing.contact')))),
            if (l.negotiable || l.exchange) ...[
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => showNegotiateSheet(context, ref, l), icon: const Icon(Icons.handshake_outlined), label: Text(context.t('listing.negotiate')))),
            ],
          ]).reveal(index: 5),
          if (l.seller?.showWhatsapp ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton.icon(
                onPressed: whatsapp,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1FA855), side: const BorderSide(color: Color(0xFF1FA855)), minimumSize: const Size.fromHeight(50)),
                icon: const Icon(Icons.chat_rounded),
                label: Text(context.t('listing.whatsapp')),
              ),
            ).reveal(index: 6),
        ],
        const SizedBox(height: 22),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (l.negotiable) _Tag(Icons.handshake_outlined, context.t('listing.negotiable')),
          if (l.exchange) _Tag(Icons.swap_horiz_rounded, context.t('listing.exchange_ok')),
          _Tag(l.delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined, l.delivery ? context.t('listing.delivery') : context.t('listing.pickup_only')),
          if (l.warranty != null && l.warranty!.isNotEmpty) _Tag(Icons.shield_outlined, l.warranty!),
        ]).reveal(),
        if (l.exchange && (l.exchangeWanted ?? '').isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 10), child: Text('${context.t('form.exchange_wanted')} : ${l.exchangeWanted}', style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 22),
        Text(context.t('listing.description'), style: Theme.of(context).textTheme.titleMedium).reveal(),
        const SizedBox(height: 6),
        Text(l.description.isEmpty ? context.t('listing.no_description') : l.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)).reveal(),
        if ((l.defects ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(context.t('listing.defects'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l.defects!),
        ],
        if (attrs.isNotEmpty || l.brandName != null || l.modelText != null) ...[
          const SizedBox(height: 22),
          Text(context.t('listing.specs'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _SpecTable({
            if (l.brandName != null) context.t('common.brand'): l.brandName!,
            if ((l.modelText ?? '').isNotEmpty) context.t('listing.model'): l.modelText!,
            for (final e in attrs.entries) e.key: '${e.value}',
          }),
        ],
        const SizedBox(height: 22),
        _SellerCard(l: l),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: WM.volt.withValues(alpha: .13), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [const Icon(Icons.shield_moon_outlined, color: Color(0xFFB77900)), const SizedBox(width: 10), Expanded(child: Text(context.t('listing.safety_tip'), style: Theme.of(context).textTheme.bodySmall))]),
        ),
        if (!mine)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: () => showReportSheet(context, ref, 'listing', l.id), icon: const Icon(Icons.flag_outlined, size: 18), label: Text(context.t('listing.report'))),
          ),
        similar.maybeWhen(
          data: (items) => items.isEmpty ? const SizedBox.shrink() : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SectionHeader(context.t('listing.similar')), ListingRail(items)]),
          orElse: () => const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

final _attrsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) => Repo.attributes(id));
final _similarProvider = FutureProvider.family<List<Listing>, Listing>((ref, l) => Repo.similar(l));

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: cs.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: cs.primary), const SizedBox(width: 6), Text(text, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13))]),
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable(this.rows);
  final Map<String, String> rows;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: cs.outlineVariant), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        for (final (i, e) in rows.entries.indexed)
          Container(
            color: i.isEven ? cs.surfaceContainerLow : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [Expanded(flex: 2, child: Text(e.key, style: Theme.of(context).textTheme.bodySmall)), Expanded(flex: 3, child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)))]),
          ),
      ]),
    );
  }
}

class _SellerCard extends ConsumerWidget {
  const _SellerCard({required this.l});
  final Listing l;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = l.seller;
    final cs = Theme.of(context).colorScheme;
    final shop = l.shopId == null ? null : ref.watch(_shopProvider(l.shopId!)).asData?.value;
    return Pressable(
      onTap: () => shop != null ? context.push('/shop/${shop.slug}') : context.push('/seller/${l.sellerId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.outlineVariant.withValues(alpha: .6))),
        child: Row(children: [
          Avatar(url: shop?.logoUrl ?? s?.avatarUrl, name: shop?.name ?? s?.displayName ?? '?', size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.t('listing.seller'), style: Theme.of(context).textTheme.bodySmall),
              Row(children: [
                Flexible(child: Text(shop?.name ?? s?.displayName ?? '—', style: Theme.of(context).textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
                if ((shop?.verified ?? false) || (s?.verified ?? false)) const Padding(padding: EdgeInsets.only(left: 4), child: VerifiedMark()),
              ]),
              if (s?.createdAt != null) Text(context.t('profile.member_since', {'date': shortDate(s!.createdAt!, context.lang)}), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

final _shopProvider = FutureProvider.family<Shop?, String>((ref, id) => Repo.shop(id));

class _OwnerActions extends ConsumerWidget {
  const _OwnerActions({required this.l});
  final Listing l;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> act(Future<void> Function() f, {String? ok}) async {
      await guard(context, () async {
        await f();
        ref.invalidate(listingProvider(l.id));
        ref.invalidate(myListingsProvider);
      }, ok: ok);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(18)),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: () => context.push('/sell/${l.id}'), icon: const Icon(Icons.edit_rounded), label: Text(context.t('common.edit'))),
        if (l.status == 'active') OutlinedButton.icon(onPressed: () => act(() => Repo.setListingStatus(l.id, 'paused')), icon: const Icon(Icons.pause_rounded), label: Text(context.t('listing.pause'))),
        if (l.status == 'paused' || l.status == 'draft') OutlinedButton.icon(onPressed: () => act(() => Repo.setListingStatus(l.id, 'active')), icon: const Icon(Icons.play_arrow_rounded), label: Text(context.t('listing.resume'))),
        if (l.status == 'active' || l.status == 'paused') OutlinedButton.icon(onPressed: () => act(() => Repo.setListingStatus(l.id, 'sold')), icon: const Icon(Icons.check_circle_outline_rounded), label: Text(context.t('listing.mark_sold'))),
        if (l.status == 'expired' || l.status == 'active') OutlinedButton.icon(onPressed: () => act(() => Repo.renew(l.id)), icon: const Icon(Icons.refresh_rounded), label: Text(context.t('listing.renew'))),
        OutlinedButton.icon(onPressed: () => showPromoSheet(context, l), icon: const Icon(Icons.bolt_rounded), label: Text(context.t('promo.sponsor'))),
        TextButton.icon(
          onPressed: () async {
            if (!await confirmDialog(context, context.t('listing.confirm_delete'))) return;
            if (!context.mounted) return;
            await guard(context, () async {
              await Repo.deleteListing(l.id);
              ref.invalidate(myListingsProvider);
              if (context.mounted) context.go('/account/listings');
            });
          },
          style: TextButton.styleFrom(foregroundColor: WM.coral),
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(context.t('common.delete')),
        ),
      ]),
    );
  }
}

Future<void> showPromoSheet(BuildContext context, Listing l) async {
  final plans = await Repo.plans('sponsorship').catchError((_) => <Map<String, dynamic>>[]);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ctx.t('promo.sponsor'), style: Theme.of(ctx).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(ctx.t('promo.hint'), style: Theme.of(ctx).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (plans.isEmpty) Text(ctx.t('common.no_results')),
        for (final p in plans)
          ListTile(
            title: Text(p['name'] as String),
            subtitle: Text('${formatPrice(p['price'] as num, p['currency_code'] as String, ctx.lang)} · ${p['duration_days']} ${ctx.t('common.days')}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              Navigator.pop(ctx);
              await guard(context, () => Repo.requestPromotion(l.id, p['code'] as String), ok: 'promo.requested');
            },
          ),
      ]),
    ),
  );
}
