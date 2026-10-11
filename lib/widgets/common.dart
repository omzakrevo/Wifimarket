import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../core/utils/format.dart';
import '../data/models.dart';
import '../data/providers.dart';
import '../data/repo.dart';
import 'motion.dart';

bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 900;

/// Colonnes d'une grille d'annonces selon la largeur.
int gridColumns(double w) => w >= 1250 ? 5 : w >= 980 ? 4 : w >= 700 ? 3 : 2;

void toast(BuildContext context, String message, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  m?.hideCurrentSnackBar();
  m?.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? WM.coral : null,
  ));
}

String errMsg(BuildContext context, Object e) => context.t(errorKey(e));

Future<void> guard(BuildContext context, Future<void> Function() job, {String? ok}) async {
  try {
    await job();
    if (ok != null && context.mounted) toast(context, context.t(ok));
  } catch (e) {
    if (context.mounted) toast(context, errMsg(context, e), error: true);
  }
}

/// Vrai si connecté ; sinon redirige vers la connexion.
bool requireLogin(BuildContext context, WidgetRef ref) {
  if (ref.read(uidProvider) != null) return true;
  final from = GoRouterState.of(context).uri.toString();
  context.push('/auth?next=${Uri.encodeComponent(from)}');
  return false;
}

Future<bool> confirmDialog(BuildContext context, String message, {String? ok}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.t('common.cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok ?? c.t('common.yes'))),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptDialog(BuildContext context, String title, {String? hint, bool multiline = true, String? initial}) async {
  final ctl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctl, autofocus: true, maxLines: multiline ? 4 : 1, minLines: multiline ? 2 : 1, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(c.t('common.cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: Text(c.t('common.apply'))),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}

/// Page : barre de titre sur mobile, titre intégré sur grand écran, largeur maîtrisée.
class WPage extends StatelessWidget {
  const WPage({super.key, this.title, required this.child, this.actions = const [], this.maxWidth = 1180, this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 32), this.scroll = true, this.fab, this.bottom});
  final String? title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsets padding;
  final bool scroll;
  final Widget? fab;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final canPop = context.canPop();
    Widget body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: scroll ? SingleChildScrollView(padding: padding, child: child) : Padding(padding: padding, child: child),
      ),
    );
    if (wide && title != null) {
      body = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left, 20, padding.right, 0),
              child: Row(children: [
                if (canPop) IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)),
                Expanded(child: Text(title!, style: Theme.of(context).textTheme.headlineSmall)),
                ...actions,
              ]).reveal(),
            ),
            Expanded(child: scroll ? SingleChildScrollView(padding: padding, child: child) : Padding(padding: padding, child: child)),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: wide || title == null
          ? null
          : AppBar(
              title: Text(title!),
              leading: canPop ? IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_rounded)) : null,
              actions: actions,
            ),
      floatingActionButton: fab,
      bottomNavigationBar: bottom,
      body: SafeArea(top: wide || title == null, bottom: false, child: body),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll, this.subtitle});
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 26, 0, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Row(mainAxisSize: MainAxisSize.min, children: [Text(context.t('common.see_all')), const Icon(Icons.arrow_forward_rounded, size: 16)])),
        ]),
      ).reveal();
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action, this.actionLabel});
  final IconData icon;
  final String title;
  final String? body;
  final VoidCallback? action;
  final String? actionLabel;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            Container(width: 96, height: 96, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary.withValues(alpha: .1))),
            Icon(icon, size: 40, color: cs.primary),
          ]).popIn(),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium).reveal(index: 1),
          if (body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)).reveal(index: 2)),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 18), child: GradientButton(label: actionLabel ?? '', onPressed: action, expand: false).reveal(index: 3)),
        ]),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: errMsg(context, error),
        body: context.t('error.generic_body'),
        action: onRetry,
        actionLabel: context.t('error.retry'),
      );
}

/// Résout un AsyncValue avec chargement par squelettes et erreur réessayable.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.loading, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T) data;
  final Widget? loading;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.base,
        child: value.when(
          data: (d) => KeyedSubtree(key: const ValueKey('d'), child: data(d)),
          error: (e, _) => KeyedSubtree(key: const ValueKey('e'), child: ErrorState(error: e, onRetry: onRetry)),
          loading: () => KeyedSubtree(key: const ValueKey('l'), child: loading ?? const SkeletonList()),
        ),
      );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5});
  final int count;
  @override
  Widget build(BuildContext context) => Column(
        children: [for (var i = 0; i < count; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: ShimmerBox(height: 72, radius: 18))],
      );
}

class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({super.key, this.count = 6});
  final int count;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, b) {
        final cols = gridColumns(b.maxWidth);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: .66,
          children: [for (var i = 0; i < count; i++) const ShimmerBox(radius: 20)],
        );
      });
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, this.url, required this.name, this.size = 40});
  final String? url;
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _fallback(initials))
            : _fallback(initials),
      ),
    );
  }

  Widget _fallback(String i) => DecoratedBox(
        decoration: const BoxDecoration(gradient: WM.signalGradient),
        child: Center(child: Text(i, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .38))),
      );
}

class Net extends StatelessWidget {
  const Net(this.url, {super.key, this.fit = BoxFit.cover, this.radius = 0});
  final String? url;
  final BoxFit fit;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ph = Container(color: cs.surfaceContainerHighest, child: Icon(Icons.router_rounded, color: cs.onSurfaceVariant.withValues(alpha: .5), size: 36));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? ph
          : CachedNetworkImage(
              imageUrl: url!,
              fit: fit,
              fadeInDuration: Motion.base,
              placeholder: (_, __) => const ShimmerBox(radius: 0),
              errorWidget: (_, __, ___) => ph,
            ),
    );
  }
}

class Badge2 extends StatelessWidget {
  const Badge2(this.label, {super.key, this.color, this.fg = Colors.white, this.icon});
  final String label;
  final Color? color;
  final Color fg;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: color ?? WM.ink.withValues(alpha: .72), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Pastille de statut colorée (annonces, commandes, etc.).
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = 0});
  final String label;

  /// 0 neutre, 1 positif, 2 attention, 3 négatif, 4 info
  final int tone;
  @override
  Widget build(BuildContext context) {
    final c = [Theme.of(context).colorScheme.onSurfaceVariant, WM.success, const Color(0xFFB77900), WM.coral, WM.wave][tone];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .13), borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

int statusTone(String s) {
  switch (s) {
    case 'active':
    case 'paid':
    case 'completed':
    case 'delivered':
    case 'verified':
    case 'accepted':
    case 'fulfilled':
    case 'done':
    case 'resolved_buyer':
    case 'resolved_seller':
      return 1;
    case 'pending':
    case 'pending_review':
    case 'awaiting_payment':
    case 'processing':
    case 'countered':
    case 'open':
    case 'investigating':
    case 'reviewing':
      return 2;
    case 'rejected':
    case 'cancelled':
    case 'removed':
    case 'declined':
    case 'disputed':
    case 'refunded':
    case 'expired':
      return 3;
    case 'shipped':
    case 'sent':
      return 4;
    default:
      return 0;
  }
}

class VerifiedMark extends StatelessWidget {
  const VerifiedMark({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) => Icon(Icons.verified_rounded, size: size, color: WM.wave);
}

/// Carte d'annonce : image en vedette (Hero), cœur animé, prix en évidence.
class ListingCard extends ConsumerWidget {
  const ListingCard(this.l, {super.key, this.index = 0, this.width});
  final Listing l;
  final int index;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final cs = Theme.of(context).colorScheme;
    final fav = ref.watch(favoritesProvider.select((s) => s.contains(l.id)));
    final card = Pressable(
      onTap: () => context.push('/listing/${l.id}', extra: l),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: WM.softShadow(.06),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 1.12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(fit: StackFit.expand, children: [
                Hero(tag: 'img-${l.id}', child: Net(l.cover)),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
                    if (l.isSponsoredNow) Badge2(context.t('listing.sponsored'), color: WM.volt, fg: WM.ink, icon: Icons.bolt_rounded),
                    Badge2(context.t('cond.${l.condition}')),
                  ]),
                ),
                Positioned(right: 6, top: 6, child: HeartButton(active: fav, onTap: () async {
                  if (!requireLogin(context, ref)) return;
                  await guard(context, () async {
                    await ref.read(favoritesProvider.notifier).toggle(l.id);
                  });
                })),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(gradient: WM.signalGradient, borderRadius: BorderRadius.circular(10)),
                    child: Text(formatPrice(l.price, l.currency, lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ),
              ]),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.place_outlined, size: 13, color: WM.coral),
                  const SizedBox(width: 3),
                  Expanded(child: Text([l.city, l.country].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: WM.coral, fontWeight: FontWeight.w600))),
                ]),
                const SizedBox(height: 4),
                Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
              ]),
            ),
          ),
        ]),
      ),
    );
    final w = width == null ? card : SizedBox(width: width, child: card);
    return w.reveal(index: index);
  }
}

/// Grille responsive d'annonces.
class ListingGrid extends StatelessWidget {
  const ListingGrid(this.items, {super.key});
  final List<Listing> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, b) {
        final cols = gridColumns(b.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .66),
          itemBuilder: (_, i) => ListingCard(items[i], index: i % cols + (i ~/ cols)),
        );
      });
}

/// Rangée horizontale d'annonces.
class ListingRail extends StatelessWidget {
  const ListingRail(this.items, {super.key});
  final List<Listing> items;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 320,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, i) => ListingCard(items[i], index: i, width: 200),
        ),
      );
}

IconData categoryIcon(String? name) {
  const m = {
    'radio': Icons.cell_tower_rounded,
    'satellite': Icons.satellite_alt_rounded,
    'wrench': Icons.build_rounded,
    'wifi': Icons.wifi_rounded,
    'router': Icons.router_rounded,
    'cable': Icons.cable_rounded,
    'antenna': Icons.settings_input_antenna_rounded,
    'camera': Icons.videocam_rounded,
    'solar': Icons.solar_power_rounded,
    'power': Icons.power_rounded,
    'server': Icons.dns_rounded,
    'phone': Icons.smartphone_rounded,
    'laptop': Icons.laptop_rounded,
    'tools': Icons.build_rounded,
    'box': Icons.inventory_2_rounded,
    'battery': Icons.battery_charging_full_rounded,
    'signal': Icons.signal_cellular_alt_rounded,
    'network': Icons.hub_rounded,
    'plug': Icons.electrical_services_rounded,
  };
  return m[name] ?? Icons.category_rounded;
}

/// Champ avec libellé flottant + espacement standard.
Widget field(TextEditingController c, String label, {String? hint, TextInputType? type, int lines = 1, bool obscure = false, String? Function(String?)? validator, Widget? suffix, IconData? icon, int? maxLength, ValueChanged<String>? onChanged}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        minLines: lines,
        maxLines: obscure ? 1 : lines,
        obscureText: obscure,
        validator: validator,
        maxLength: maxLength,
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix, prefixIcon: icon == null ? null : Icon(icon), counterText: ''),
      ),
    );
