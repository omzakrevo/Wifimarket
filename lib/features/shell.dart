import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/i18n/i18n.dart';
import '../core/theme/colors.dart';
import '../core/theme/motion.dart';
import '../data/providers.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';

const _tabRoots = ['/', '/search', '/messages', '/account'];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = isWide(context);
    final cs = Theme.of(context).colorScheme;
    final showBottom = !wide && _tabRoots.contains(location);
    return Scaffold(
      body: Column(children: [
        if (wide) const _TopBar(),
        Expanded(child: child),
      ]),
      bottomNavigationBar: showBottom ? _BottomBar(location: location) : null,
      backgroundColor: cs.surface,
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.location});
  final String location;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final unread = ref.watch(countersProvider).messages;
    int idx = _tabRoots.indexOf(location);
    Widget item(IconData icon, IconData sel, String label, String path, int i, {int badge = 0}) {
      final on = idx == i;
      return Expanded(
        child: Pressable(
          scale: .9,
          onTap: () => context.go(path),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: Motion.base,
                curve: Motion.emphasized,
                width: on ? 6 : 0,
                height: 6,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
              ),
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: AnimatedSwitcher(duration: Motion.quick, child: Icon(on ? sel : icon, key: ValueKey(on), color: on ? cs.primary : cs.onSurfaceVariant)),
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: on ? cs.primary : cs.onSurfaceVariant)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: WM.signalDeep.withValues(alpha: .10), blurRadius: 30, offset: const Offset(0, -8))],
      ),
      child: SafeArea(
        top: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          item(Icons.home_outlined, Icons.home_rounded, context.t('nav.home'), '/', 0),
          item(Icons.search_rounded, Icons.search_rounded, context.t('common.search'), '/search', 1),
          Expanded(
            child: Pressable(
              onTap: () => context.push('/sell'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 52,
                    height: 40,
                    decoration: BoxDecoration(gradient: WM.signalGradient, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: WM.wave.withValues(alpha: .35), blurRadius: 14, offset: const Offset(0, 6))]),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1, end: 1.06, duration: 1600.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 2),
                  Text(context.t('nav.sell_short'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
          item(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, context.t('nav.messages'), '/messages', 2, badge: unread),
          item(Icons.person_outline_rounded, Icons.person_rounded, context.t('nav.account'), '/account', 3),
        ]),
      ),
    );
  }
}

class _TopBar extends ConsumerStatefulWidget {
  const _TopBar();
  @override
  ConsumerState<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<_TopBar> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logged = ref.watch(uidProvider) != null;
    final counters = ref.watch(countersProvider);
    final profile = ref.watch(myProfileProvider).asData?.value;
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    final country = ref.watch(countryProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final path = GoRouterState.of(context).uri.path;

    Widget link(String label, String to) {
      final on = to == '/' ? path == '/' : path.startsWith(to);
      return TextButton(
        onPressed: () => context.go(to),
        style: TextButton.styleFrom(foregroundColor: on ? cs.primary : cs.onSurface),
        child: Text(label, style: TextStyle(fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
      );
    }

    return Material(
      color: cs.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: .6)))),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1380),
            child: Row(children: [
              Pressable(onTap: () => context.go('/'), child: const LogoWordmark(size: 32)),
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _q,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => context.go('/search?q=${Uri.encodeQueryComponent(v.trim())}'),
                    decoration: InputDecoration(
                      hintText: context.t('home.search_placeholder'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              link(context.t('nav.wanted'), '/wanted'),
              link(context.t('nav.shops'), '/shops'),
              const Spacer(),
              PopupMenuButton<String?>(
                tooltip: context.t('loc.title'),
                icon: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.place_outlined, size: 20),
                  const SizedBox(width: 4),
                  Text(country ?? context.t('common.all'), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                onSelected: (v) => ref.read(countryProvider.notifier).set(v == '' ? null : v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: '', child: Text(context.t('loc.all'))),
                  for (final c in countries) PopupMenuItem(value: c.code, child: Text(c.name(context.lang))),
                ],
              ),
              TextButton(onPressed: () => ref.read(langProvider.notifier).toggle(), child: Text(context.lang == 'fr' ? 'EN' : 'FR', style: const TextStyle(fontWeight: FontWeight.w800))),
              IconButton(
                tooltip: context.t('common.theme'),
                onPressed: () => ref.read(themeProvider.notifier).set(!dark),
                icon: AnimatedSwitcher(duration: Motion.base, transitionBuilder: (c, a) => RotationTransition(turns: a, child: FadeTransition(opacity: a, child: c)), child: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, key: ValueKey(dark))),
              ),
              if (logged) ...[
                IconButton(onPressed: () => context.go('/favorites'), icon: const Icon(Icons.favorite_border_rounded)),
                IconButton(onPressed: () => context.go('/cart'), icon: const Icon(Icons.shopping_bag_outlined)),
                IconButton(onPressed: () => context.go('/messages'), icon: Badge(isLabelVisible: counters.messages > 0, label: Text('${counters.messages}'), child: const Icon(Icons.chat_bubble_outline_rounded))),
                IconButton(onPressed: () => context.go('/notifications'), icon: Badge(isLabelVisible: counters.notifications > 0, label: Text('${counters.notifications}'), child: const Icon(Icons.notifications_none_rounded))),
              ],
              const SizedBox(width: 8),
              GradientButton(label: context.t('nav.sell'), icon: Icons.add_rounded, expand: false, onPressed: () => context.go('/sell')),
              const SizedBox(width: 12),
              if (logged)
                Pressable(onTap: () => context.go('/account'), child: Avatar(url: profile?.avatarUrl, name: profile?.displayName ?? '?', size: 40))
              else
                OutlinedButton(onPressed: () => context.go('/auth'), child: Text(context.t('auth.login'))),
            ]),
          ),
        ),
      ),
    );
  }
}
