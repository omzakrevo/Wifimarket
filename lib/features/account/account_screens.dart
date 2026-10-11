import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logged = ref.watch(uidProvider) != null;
    if (!logged) {
      return WPage(child: EmptyState(icon: Icons.person_outline_rounded, title: context.t('auth.login'), action: () => context.go('/auth'), actionLabel: context.t('auth.login')));
    }
    final p = ref.watch(myProfileProvider).asData?.value;
    final roles = ref.watch(myRolesProvider).asData?.value ?? [];
    final mine = ref.watch(myListingsProvider).asData?.value ?? [];
    final favs = ref.watch(favoritesProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isStaff = roles.isNotEmpty;
    final cs = Theme.of(context).colorScheme;

    Widget tile(IconData i, String label, String to, {String? trailing, int idx = 0}) => Pressable(
          onTap: () => context.push(to),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(width: 38, height: 38, decoration: BoxDecoration(color: cs.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: cs.primary, size: 20)),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
              if (trailing != null) Text(trailing, style: Theme.of(context).textTheme.bodySmall),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        ).reveal(index: idx);

    return WPage(
      maxWidth: 760,
      padding: EdgeInsets.fromLTRB(16, isWide(context) ? 24 : MediaQuery.paddingOf(context).top + 12, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: WM.nightGradient, borderRadius: BorderRadius.circular(26)),
          child: Stack(children: [
            const Positioned.fill(child: WifiRings(rings: 4, alignment: Alignment.topRight)),
            Row(children: [
              Avatar(url: p?.avatarUrl, name: p?.displayName ?? '?', size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.t('account.hello', {'name': p?.displayName ?? ''}), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(p?.verified == true ? Icons.verified_rounded : Icons.shield_outlined, size: 16, color: p?.verified == true ? WM.volt : Colors.white60),
                    const SizedBox(width: 4),
                    Text(p?.verified == true ? context.t('profile.verified') : context.t('profile.unverified'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ]),
              ),
            ]),
          ]),
        ).reveal(),
        const SizedBox(height: 14),
        Row(children: [
          for (final (i, s) in [
            (mine.where((l) => l.status == 'active').length, context.t('account.my_listings')),
            (favs.length, context.t('account.favorites')),
            (mine.fold<int>(0, (a, l) => a + l.views), context.t('listing.views')),
          ].indexed)
            Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == 2 ? 0 : 10),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(18)),
                child: Column(children: [AnimatedCount(value: s.$1, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)), Text(s.$2, style: Theme.of(context).textTheme.bodySmall)]),
              ).reveal(index: i + 1),
            ),
        ]),
        const SizedBox(height: 18),
        tile(Icons.sell_outlined, context.t('account.my_listings'), '/account/listings', idx: 3),
        tile(Icons.favorite_border_rounded, context.t('account.favorites'), '/favorites', idx: 4),
        tile(Icons.shopping_bag_outlined, context.t('cart.title'), '/cart', idx: 5),
        tile(Icons.receipt_long_outlined, context.t('account.orders'), '/orders', idx: 6),
        tile(Icons.handshake_outlined, context.t('account.negotiations'), '/negotiations', idx: 7),
        tile(Icons.travel_explore_rounded, context.t('account.my_wanted'), '/wanted?mine=1', idx: 8),
        tile(Icons.notifications_active_outlined, context.t('account.searches'), '/account/searches', idx: 9),
        tile(Icons.storefront_outlined, context.t('account.shop'), '/shop/manage', idx: 10),
        tile(Icons.person_outline_rounded, context.t('account.profile'), '/account/profile', idx: 11),
        if (isStaff) tile(Icons.admin_panel_settings_outlined, context.t('admin.title'), '/admin', idx: 12),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            SwitchListTile(title: Text(context.t('common.theme')), secondary: Icon(dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded), value: dark, onChanged: (v) => ref.read(themeProvider.notifier).set(v)),
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(context.lang == 'fr' ? 'Français' : 'English'),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: 'fr', label: Text('FR')), ButtonSegment(value: 'en', label: Text('EN'))],
                selected: {context.lang},
                onSelectionChanged: (s) => ref.read(langProvider.notifier).set(s.first),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: WM.coral),
              title: Text(context.t('auth.logout'), style: const TextStyle(color: WM.coral, fontWeight: FontWeight.w700)),
              onTap: () async {
                await sb.auth.signOut();
                if (context.mounted) context.go('/');
              },
            ),
          ]),
        ).reveal(index: 13),
      ]),
    );
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _city = TextEditingController();
  final _wa = TextEditingController();
  final _reason = TextEditingController();
  String? country, avatar;
  bool showWa = false, busy = false, loaded = false, deletionPending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await Repo.profile(myId!);
    final pr = await Repo.privateProfile();
    final del = await Repo.deletionRequest();
    if (!mounted) return;
    setState(() {
      _name.text = p?.displayName ?? '';
      _bio.text = p?.bio ?? '';
      _city.text = p?.city ?? '';
      country = p?.countryCode;
      avatar = p?.avatarUrl;
      showWa = p?.showWhatsapp ?? false;
      _wa.text = (pr?['whatsapp_number'] as String?) ?? '';
      deletionPending = del != null;
      loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _bio, _city, _wa, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (f == null) return;
    await guard(context, () async {
      final url = await Repo.uploadAvatar(await f.readAsBytes(), f.name.contains('.') ? f.name.split('.').last : 'jpg');
      await Repo.updateProfile({'avatar_url': url});
      setState(() => avatar = url);
      ref.invalidate(myProfileProvider);
    }, ok: 'profile.saved');
  }

  Future<void> _save() async {
    final wa = _wa.text.trim();
    if (wa.isNotEmpty && !RegExp(r'^\+\d{8,15}$').hasMatch(wa)) return toast(context, context.t('profile.err_whatsapp'), error: true);
    if (showWa && wa.isEmpty) return toast(context, context.t('profile.err_whatsapp'), error: true);
    setState(() => busy = true);
    await guard(context, () async {
      await Repo.updateProfile({
        'display_name': _name.text.trim(),
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'country_code': country,
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'show_whatsapp': showWa,
      }, whatsapp: wa.isEmpty ? null : wa, touchWhatsapp: true);
      ref.invalidate(myProfileProvider);
    }, ok: 'profile.saved');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(countriesProvider).asData?.value ?? [];
    if (!loaded) return WPage(title: context.t('account.profile'), child: const SkeletonList());
    return WPage(
      title: context.t('account.profile'),
      maxWidth: 640,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Pressable(
            onTap: _pickAvatar,
            child: Stack(children: [
              Avatar(url: avatar, name: _name.text, size: 96),
              Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(gradient: WM.signalGradient, shape: BoxShape.circle), child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white))),
            ]),
          ),
        ).popIn(),
        const SizedBox(height: 20),
        field(_name, context.t('auth.display_name')),
        field(_bio, context.t('profile.bio'), lines: 3, maxLength: 300),
        DropdownButtonFormField<String?>(
          initialValue: countries.any((c) => c.code == country) ? country : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.t('common.country')),
          items: [for (final c in countries) DropdownMenuItem(value: c.code, child: Text(c.name(context.lang)))],
          onChanged: (v) => setState(() => country = v),
        ),
        const SizedBox(height: 14),
        field(_city, context.t('common.city')),
        const Divider(height: 32),
        field(_wa, context.t('profile.whatsapp'), hint: '+22670000000', type: TextInputType.phone, icon: Icons.chat_rounded),
        Text(context.t('profile.whatsapp_hint'), style: Theme.of(context).textTheme.bodySmall),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.t('profile.show_whatsapp')), value: showWa, onChanged: (v) => setState(() => showWa = v)),
        const SizedBox(height: 8),
        GradientButton(label: context.t('common.save'), loading: busy, onPressed: _save),
        const Divider(height: 40),
        Text(context.t('profile.privacy'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(context.t('profile.deletion_info'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (deletionPending)
          Text(context.t('profile.deletion_pending'), style: const TextStyle(fontWeight: FontWeight.w700))
        else ...[
          field(_reason, context.t('profile.deletion_reason')),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: WM.coral, side: const BorderSide(color: WM.coral)),
            onPressed: () async {
              if (!await confirmDialog(context, context.t('admin.confirm_delete_account'))) return;
              if (!context.mounted) return;
              await guard(context, () async {
                await Repo.requestDeletion(_reason.text.trim().isEmpty ? null : _reason.text.trim());
                setState(() => deletionPending = true);
              }, ok: 'profile.deletion_requested');
            },
            child: Text(context.t('profile.request_deletion')),
          ),
        ],
      ]),
    );
  }
}

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(myListingsProvider);
    final lang = context.lang;
    final cs = Theme.of(context).colorScheme;
    return WPage(
      title: context.t('account.my_listings'),
      maxWidth: 860,
      fab: FloatingActionButton.extended(onPressed: () => context.push('/sell'), icon: const Icon(Icons.add_rounded), label: Text(context.t('nav.sell'))),
      child: AsyncView<List<Listing>>(
        value: v,
        onRetry: () => ref.invalidate(myListingsProvider),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.sell_outlined, title: context.t('account.no_listings'), action: () => context.push('/sell'), actionLabel: context.t('nav.sell'))
            : Column(children: [
                for (final (i, l) in list.indexed)
                  Pressable(
                    onTap: () => context.push('/listing/${l.id}', extra: l),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(18)),
                      child: Row(children: [
                        SizedBox(width: 72, height: 72, child: Net(l.cover, radius: 14)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                            Text(formatPrice(l.price, l.currency, lang), style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Row(children: [StatusChip(context.t('status.${l.status}'), tone: statusTone(l.status)), const SizedBox(width: 8), Text('${l.views} ${context.t('listing.views')}', style: Theme.of(context).textTheme.bodySmall)]),
                          ]),
                        ),
                        IconButton(onPressed: () => context.push('/sell/${l.id}'), icon: const Icon(Icons.edit_outlined)),
                      ]),
                    ),
                  ).reveal(index: i),
              ]),
      ),
    );
  }
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(favoriteListingsProvider);
    return WPage(
      title: context.t('account.favorites'),
      child: AsyncView<List<Listing>>(
        value: v,
        loading: const SkeletonGrid(),
        onRetry: () => ref.invalidate(favoriteListingsProvider),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.favorite_border_rounded, title: context.t('account.no_favorites'), action: () => context.go('/'), actionLabel: context.t('cart.browse'))
            : ListingGrid(list),
      ),
    );
  }
}

class SavedSearchesScreen extends ConsumerStatefulWidget {
  const SavedSearchesScreen({super.key});
  @override
  ConsumerState<SavedSearchesScreen> createState() => _SavedState();
}

class _SavedState extends ConsumerState<SavedSearchesScreen> {
  late Future<List<Map<String, dynamic>>> f = Repo.savedSearches();
  void _reload() => setState(() => f = Repo.savedSearches());

  @override
  Widget build(BuildContext context) {
    return WPage(
      title: context.t('account.searches'),
      maxWidth: 760,
      child: FutureBuilder(
        future: f,
        builder: (context, s) {
          if (s.hasError) return ErrorState(error: s.error!, onRetry: _reload);
          if (!s.hasData) return const SkeletonList(count: 3);
          final rows = s.data!;
          if (rows.isEmpty) return EmptyState(icon: Icons.notifications_off_outlined, title: context.t('account.no_searches'), body: context.t('search.alerts_hint'));
          return Column(children: [
            for (final (i, r) in rows.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: Text((r['label'] as String?) ?? (r['query'] as String?) ?? '—'),
                  subtitle: Text(r['notify'] == true ? context.t('search.alerts_on') : context.t('search.alerts_off')),
                  onTap: () => context.go('/search?q=${Uri.encodeQueryComponent((r['query'] as String?) ?? '')}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(value: r['notify'] == true, onChanged: (v) async { await Repo.updateSavedSearch(r['id'] as String, v); _reload(); }),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () async { await Repo.deleteSavedSearch(r['id'] as String); _reload(); }),
                  ]),
                ),
              ).reveal(index: i),
          ]);
        },
      ),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotifState();
}

class _NotifState extends ConsumerState<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> f = Repo.notifications();
  void _reload() {
    setState(() => f = Repo.notifications());
    ref.read(countersProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(countersProvider, (a, b) {
      if (a?.notifications != b.notifications) setState(() => f = Repo.notifications());
    });
    return WPage(
      title: context.t('nav.notifications'),
      maxWidth: 760,
      actions: [TextButton(onPressed: () async { await Repo.markAllNotifs(); _reload(); }, child: Text(context.t('notif.mark_all')))],
      child: FutureBuilder(
        future: f,
        builder: (context, s) {
          if (s.hasError) return ErrorState(error: s.error!, onRetry: _reload);
          if (!s.hasData) return const SkeletonList();
          final rows = s.data!;
          if (rows.isEmpty) return EmptyState(icon: Icons.notifications_none_rounded, title: context.t('notif.none'));
          return Column(children: [
            for (final (i, n) in rows.indexed)
              Pressable(
                onTap: () async {
                  await Repo.markNotif(n['id'] as String);
                  _reload();
                  final link = n['link'] as String?;
                  if (link != null && context.mounted) {
                    final to = await resolveNotificationLink(link);
                    if (to != null && context.mounted) context.push(to);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n['read_at'] == null ? WM.signal.withValues(alpha: .1) : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Icon(n['read_at'] == null ? Icons.circle : Icons.circle_outlined, size: 10, color: WM.signal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n['title'] as String, style: Theme.of(context).textTheme.titleSmall),
                        if (n['body'] != null) Text(n['body'] as String, style: Theme.of(context).textTheme.bodySmall),
                        Text(timeAgo(DateTime.parse(n['created_at'] as String), context.lang), style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                  ]),
                ),
              ).reveal(index: i),
          ]);
        },
      ),
    );
  }
}

/// Les liens enregistrés par la base suivent l'ancienne arborescence : on les traduit vers les routes de l'app.
Future<String?> resolveNotificationLink(String link) async {
  if (link.startsWith('/messages/')) return link;
  if (link == '/compte/commandes') return '/orders';
  if (link == '/compte/negociations') return '/negotiations';
  if (link == '/compte/annonces') return '/account/listings';
  if (link.startsWith('/demandes/')) return '/wanted/${link.substring(10)}';
  if (link.startsWith('/annonces/')) {
    final slug = link.substring(10);
    final r = await sb.from('listings').select('id').eq('slug', slug).maybeSingle();
    return r == null ? null : '/listing/${r['id']}';
  }
  return null;
}
