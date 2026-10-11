import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/format.dart';
import '../../data/providers.dart';
import '../../data/repo.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class _Section {
  const _Section(this.id, this.icon, this.labelKey);
  final String id;
  final IconData icon;
  final String labelKey;
}

const _sections = [
  _Section('dashboard', Icons.dashboard_outlined, 'admin.dashboard'),
  _Section('listings', Icons.sell_outlined, 'admin.listings'),
  _Section('reports', Icons.flag_outlined, 'admin.reports'),
  _Section('users', Icons.people_outline_rounded, 'admin.users'),
  _Section('shops', Icons.storefront_outlined, 'nav.shops'),
  _Section('orders', Icons.receipt_long_outlined, 'admin.orders'),
  _Section('disputes', Icons.gavel_rounded, 'admin.disputes'),
  _Section('promotions', Icons.bolt_rounded, 'admin.promotions'),
  _Section('subscriptions', Icons.workspace_premium_outlined, 'admin.subscriptions'),
  _Section('catalog', Icons.category_outlined, 'admin.catalog'),
  _Section('countries', Icons.public_rounded, 'admin.countries'),
  _Section('settings', Icons.settings_outlined, 'admin.settings'),
  _Section('plans', Icons.payments_outlined, 'admin.plans'),
  _Section('shipping', Icons.local_shipping_outlined, 'admin.shipping'),
  _Section('providers', Icons.account_balance_wallet_outlined, 'admin.providers'),
  _Section('keywords', Icons.block_rounded, 'admin.keywords'),
  _Section('audit', Icons.history_rounded, 'admin.audit'),
  _Section('deletions', Icons.person_remove_outlined, 'admin.deletions'),
];

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key, this.section});
  final String? section;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(myRolesProvider);
    return roles.when(
      loading: () => const WPage(title: '', child: SkeletonList()),
      error: (e, _) => WPage(title: '', child: ErrorState(error: e)),
      data: (r) {
        if (r.isEmpty) return WPage(title: context.t('admin.title'), child: EmptyState(icon: Icons.lock_outline_rounded, title: context.t('err.not_allowed')));
        final isSuper = r.contains('superadmin');
        final cur = section ?? 'dashboard';
        final body = _body(cur, isSuper);
        final nav = isWide(context)
            ? SizedBox(
                width: 230,
                child: Column(children: [
                  for (final s in _sections)
                    ListTile(
                      dense: true,
                      selected: s.id == cur,
                      leading: Icon(s.icon, size: 20),
                      title: Text(context.t(s.labelKey)),
                      onTap: () => context.go('/admin/${s.id}'),
                    ),
                ]),
              )
            : null;
        return WPage(
          title: context.t('admin.title'),
          maxWidth: 1280,
          scroll: false,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (nav != null) ...[SingleChildScrollView(child: nav), const SizedBox(width: 16)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (nav == null)
                  SizedBox(
                    height: 46,
                    child: ListView(scrollDirection: Axis.horizontal, children: [
                      for (final s in _sections)
                        Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(avatar: Icon(s.icon, size: 16), label: Text(context.t(s.labelKey)), selected: s.id == cur, onSelected: (_) => context.go('/admin/${s.id}'))),
                    ]),
                  ),
                const SizedBox(height: 8),
                Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 40), child: body)),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _body(String id, bool isSuper) {
    switch (id) {
      case 'listings':
        return _ListingsAdmin(key: ValueKey(id));
      case 'reports':
        return _ReportsAdmin(key: ValueKey(id));
      case 'users':
        return _UsersAdmin(key: ValueKey(id), isSuper: isSuper);
      case 'shops':
        return _ShopsAdmin(key: ValueKey(id));
      case 'orders':
        return _OrdersAdmin(key: ValueKey(id));
      case 'disputes':
        return _DisputesAdmin(key: ValueKey(id));
      case 'promotions':
        return _ActivateAdmin(key: ValueKey(id), table: 'promotions', select: '*, listings(title)', titleOf: (r) => ((r['listings'] as Map?)?['title'] as String?) ?? '', activeStatus: 'active');
      case 'subscriptions':
        return _ActivateAdmin(key: ValueKey(id), table: 'subscriptions', select: '*, shops(name)', titleOf: (r) => ((r['shops'] as Map?)?['name'] as String?) ?? '', activeStatus: 'active');
      case 'catalog':
        return _CatalogAdmin(key: ValueKey(id));
      case 'countries':
        return _CountriesAdmin(key: ValueKey(id));
      case 'settings':
        return _SettingsAdmin(key: ValueKey(id));
      case 'plans':
        return _PlansAdmin(key: ValueKey(id));
      case 'shipping':
        return _ShippingAdmin(key: ValueKey(id));
      case 'providers':
        return _ProvidersAdmin(key: ValueKey(id));
      case 'keywords':
        return _KeywordsAdmin(key: ValueKey(id));
      case 'audit':
        return _AuditAdmin(key: ValueKey(id));
      case 'deletions':
        return _DeletionsAdmin(key: ValueKey(id));
      default:
        return const _Dashboard();
    }
  }
}

// ---------- briques communes

class _Loader extends StatefulWidget {
  const _Loader({super.key, required this.load, required this.builder});
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(BuildContext, List<Map<String, dynamic>>, VoidCallback reload) builder;
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> {
  late Future<List<Map<String, dynamic>>> f = widget.load();
  void reload() => setState(() => f = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: f,
        builder: (context, s) {
          if (s.hasError) return ErrorState(error: s.error!, onRetry: reload);
          if (!s.hasData) return const SkeletonList();
          if (s.data!.isEmpty) return EmptyState(icon: Icons.inbox_outlined, title: context.t('common.no_results'));
          return widget.builder(context, s.data!, reload);
        },
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, this.subtitle, this.chips = const [], this.actions = const [], this.index = 0});
  final String title;
  final String? subtitle;
  final List<Widget> chips;
  final List<Widget> actions;
  final int index;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: softCard(Theme.of(context).colorScheme),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
          if (chips.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: chips)),
          if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, runSpacing: 6, children: actions)),
        ]),
      ).reveal(index: index);
}

Widget _act(BuildContext c, String label, Future<void> Function() job, VoidCallback reload, {bool danger = false, String? confirm}) {
  final style = danger ? OutlinedButton.styleFrom(foregroundColor: WM.coral, side: const BorderSide(color: WM.coral)) : null;
  return OutlinedButton(
    style: style,
    onPressed: () async {
      if (confirm != null && !await confirmDialog(c, confirm)) return;
      if (!c.mounted) return;
      await guard(c, () async {
        await job();
        reload();
      });
    },
    child: Text(label),
  );
}

// ---------- tableau de bord

class _Dashboard extends StatefulWidget {
  const _Dashboard();
  @override
  State<_Dashboard> createState() => _DashState();
}

class _DashState extends State<_Dashboard> {
  late Future<Map<String, dynamic>> f = Repo.adminStats();
  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: f,
        builder: (context, s) {
          if (s.hasError) return ErrorState(error: s.error!, onRetry: () => setState(() => f = Repo.adminStats()));
          if (!s.hasData) return const SkeletonList();
          final d = s.data!;
          final cs = Theme.of(context).colorScheme;
          Widget card(String label, num v, {Color? color, String? to}) => Pressable(
                onTap: to == null ? null : () => context.go(to),
                child: Container(
                  width: 170,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(18), border: Border.all(color: (color ?? cs.outlineVariant).withValues(alpha: .5))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [AnimatedCount(value: v, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color ?? cs.primary, fontWeight: FontWeight.w800)), Text(label, style: Theme.of(context).textTheme.bodySmall)]),
                ),
              );
          final listings = Map<String, dynamic>.from(d['listings'] as Map);
          final orders = Map<String, dynamic>.from(d['orders'] as Map);
          Widget money(String title, Map m) => Container(
                padding: const EdgeInsets.all(16),
                decoration: softCard(cs),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  if (m.isEmpty) const Text('—'),
                  for (final e in m.entries) Text(formatPrice(e.value as num, e.key as String, context.lang), style: Theme.of(context).textTheme.titleMedium),
                ]),
              );
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              card(context.t('admin.users'), d['users'] as num),
              card(context.t('nav.shops'), d['shops'] as num),
              card(context.t('admin.listings_active'), (listings['active'] ?? 0) as num),
              card(context.t('admin.pending_listings'), d['pending_listings'] as num, color: WM.volt, to: '/admin/listings'),
              card(context.t('admin.open_reports'), d['open_reports'] as num, color: WM.coral, to: '/admin/reports'),
              card(context.t('admin.open_disputes'), d['open_disputes'] as num, color: WM.coral, to: '/admin/disputes'),
              card(context.t('admin.pending_shops'), d['pending_shops'] as num, color: WM.volt, to: '/admin/shops'),
              card(context.t('admin.deletions'), d['pending_deletions'] as num, color: WM.volt, to: '/admin/deletions'),
              card(context.t('admin.orders'), orders.values.fold<num>(0, (a, b) => a + (b as num))),
            ]),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(width: 260, child: money(context.t('admin.sales'), Map.from(d['sales_by_currency'] as Map))),
              SizedBox(width: 260, child: money(context.t('admin.commissions'), Map.from(d['commission_by_currency'] as Map))),
            ]),
            const SizedBox(height: 8),
            Text(context.t('admin.no_conversion'), style: Theme.of(context).textTheme.bodySmall),
          ]);
        },
      );
}

// ---------- modération

class _ListingsAdmin extends StatefulWidget {
  const _ListingsAdmin({super.key});
  @override
  State<_ListingsAdmin> createState() => _ListingsAdminState();
}

class _ListingsAdminState extends State<_ListingsAdmin> {
  String status = 'pending_review';
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [for (final s in const ['pending_review', 'active', 'rejected', 'removed', 'paused']) ChoiceChip(label: Text(context.t('status.$s')), selected: status == s, onSelected: (_) => setState(() => status = s))]),
        const SizedBox(height: 12),
        _Loader(
          key: ValueKey(status),
          load: () => Repo.table('listings', select: 'id,title,price,currency_code,status,country_code,city,description,seller_id,created_at', eq: {'status': status}, order: 'created_at', limit: 80),
          builder: (c, rows, reload) => Column(children: [
            for (final (i, r) in rows.indexed)
              _Row(
                index: i,
                title: r['title'] as String,
                subtitle: '${formatPrice(r['price'] as num, r['currency_code'] as String, c.lang)} · ${r['city'] ?? ''} ${r['country_code']}\n${r['description'] ?? ''}',
                chips: [StatusChip(c.t('status.${r['status']}'), tone: statusTone(r['status'] as String))],
                actions: [
                  OutlinedButton(onPressed: () => c.push('/listing/${r['id']}'), child: Text(c.t('common.view'))),
                  if (r['status'] != 'active') _act(c, c.t('admin.approve'), () => Repo.update('listings', 'id', r['id'] as Object, {'status': 'active', 'rejection_reason': null}), reload),
                  if (r['status'] != 'rejected' && r['status'] != 'removed')
                    OutlinedButton(
                      onPressed: () async {
                        final reason = await promptDialog(c, c.t('admin.reason_prompt'));
                        if (reason == null || !c.mounted) return;
                        await guard(c, () async {
                          await Repo.update('listings', 'id', r['id'] as Object, {'status': 'rejected', 'rejection_reason': reason});
                          reload();
                        });
                      },
                      child: Text(c.t('admin.reject')),
                    ),
                  if (r['status'] != 'removed') _act(c, c.t('admin.remove'), () => Repo.update('listings', 'id', r['id'] as Object, {'status': 'removed'}), reload, danger: true, confirm: c.t('admin.confirm_delete')),
                ],
              ),
          ]),
        ),
      ]);
}

class _ReportsAdmin extends StatefulWidget {
  const _ReportsAdmin({super.key});
  @override
  State<_ReportsAdmin> createState() => _ReportsState();
}

class _ReportsState extends State<_ReportsAdmin> {
  String status = 'open';
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [for (final s in const ['open', 'reviewing', 'actioned', 'dismissed']) ChoiceChip(label: Text(s), selected: status == s, onSelected: (_) => setState(() => status = s))]),
        const SizedBox(height: 12),
        _Loader(
          key: ValueKey(status),
          load: () => Repo.table('reports', eq: {'status': status}, order: 'created_at', limit: 80),
          builder: (c, rows, reload) => Column(children: [
            for (final (i, r) in rows.indexed)
              _Row(
                index: i,
                title: '${r['target_type']} · ${c.t('report.r.${r['reason']}')}',
                subtitle: '${r['details'] ?? ''}\n${r['target_id']}',
                chips: [StatusChip(r['status'] as String, tone: statusTone(r['status'] as String))],
                actions: [
                  if (r['target_type'] == 'listing') OutlinedButton(onPressed: () => c.push('/listing/${r['target_id']}'), child: Text(c.t('common.view'))),
                  if (r['target_type'] == 'user') OutlinedButton(onPressed: () => c.push('/seller/${r['target_id']}'), child: Text(c.t('common.view'))),
                  if (r['status'] == 'open') _act(c, c.t('admin.reviewing'), () => Repo.update('reports', 'id', r['id'] as Object, {'status': 'reviewing'}), reload),
                  _act(c, c.t('admin.mark_actioned'), () => Repo.update('reports', 'id', r['id'] as Object, {'status': 'actioned'}), reload),
                  _act(c, c.t('admin.dismiss'), () => Repo.update('reports', 'id', r['id'] as Object, {'status': 'dismissed'}), reload),
                ],
              ),
          ]),
        ),
      ]);
}

class _UsersAdmin extends StatefulWidget {
  const _UsersAdmin({super.key, required this.isSuper});
  final bool isSuper;
  @override
  State<_UsersAdmin> createState() => _UsersState();
}

class _UsersState extends State<_UsersAdmin> {
  String q = '';
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(decoration: InputDecoration(hintText: context.t('common.search'), prefixIcon: const Icon(Icons.search_rounded)), onSubmitted: (v) => setState(() => q = sanitizeSearch(v))),
        const SizedBox(height: 12),
        _Loader(
          key: ValueKey(q),
          load: () async {
            var qq = sb.from('profiles').select('id,display_name,verification_status,is_suspended,country_code,created_at');
            if (q.isNotEmpty) qq = qq.ilike('display_name', '%$q%');
            return List<Map<String, dynamic>>.from(await qq.order('created_at', ascending: false).limit(60));
          },
          builder: (c, rows, reload) => Column(children: [
            for (final (i, r) in rows.indexed)
              _Row(
                index: i,
                title: r['display_name'] as String,
                subtitle: '${r['country_code'] ?? ''} · ${r['id']}',
                chips: [StatusChip(c.t('verif.${r['verification_status']}'), tone: statusTone(r['verification_status'] as String)), if (r['is_suspended'] == true) StatusChip(c.t('admin.suspended'), tone: 3)],
                actions: [
                  OutlinedButton(onPressed: () => c.push('/seller/${r['id']}'), child: Text(c.t('common.view'))),
                  if (r['verification_status'] != 'verified') _act(c, c.t('admin.verify'), () => Repo.update('profiles', 'id', r['id'] as Object, {'verification_status': 'verified'}), reload),
                  if (r['verification_status'] == 'verified') _act(c, c.t('admin.unverify'), () => Repo.update('profiles', 'id', r['id'] as Object, {'verification_status': 'unverified'}), reload, confirm: c.t('admin.confirm_revoke')),
                  if (r['is_suspended'] != true) _act(c, c.t('admin.suspend'), () => Repo.update('profiles', 'id', r['id'] as Object, {'is_suspended': true}), reload, danger: true, confirm: c.t('admin.confirm_suspend')),
                  if (r['is_suspended'] == true) _act(c, c.t('admin.reinstate'), () => Repo.update('profiles', 'id', r['id'] as Object, {'is_suspended': false}), reload),
                  if (widget.isSuper)
                    PopupMenuButton<String>(
                      tooltip: c.t('admin.grant_role'),
                      onSelected: (role) => guard(c, () => Repo.insert('user_roles', {'user_id': r['id'], 'role': role})),
                      itemBuilder: (_) => [for (final role in const ['moderator', 'country_admin', 'shop_manager', 'superadmin']) PopupMenuItem(value: role, child: Text(c.t('role.$role')))],
                      child: Chip(avatar: const Icon(Icons.admin_panel_settings_outlined, size: 16), label: Text(c.t('admin.grant_role'))),
                    ),
                ],
              ),
          ]),
        ),
      ]);
}

class _ShopsAdmin extends StatelessWidget {
  const _ShopsAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('shops', select: 'id,slug,name,plan,verification_status,is_active,country_code,city', order: 'created_at', limit: 80),
        builder: (c, rows, reload) => Column(children: [
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: r['name'] as String,
              subtitle: '${r['city'] ?? ''} ${r['country_code'] ?? ''} · ${r['plan']}',
              chips: [StatusChip(c.t('verif.${r['verification_status']}'), tone: statusTone(r['verification_status'] as String)), if (r['is_active'] != true) StatusChip(c.t('status.paused'), tone: 3)],
              actions: [
                OutlinedButton(onPressed: () => c.push('/shop/${r['slug']}'), child: Text(c.t('common.view'))),
                if (r['verification_status'] != 'verified') _act(c, c.t('admin.verify'), () => Repo.update('shops', 'id', r['id'] as Object, {'verification_status': 'verified'}), reload),
                if (r['verification_status'] == 'pending') _act(c, c.t('admin.reject'), () => Repo.update('shops', 'id', r['id'] as Object, {'verification_status': 'rejected'}), reload),
                if (r['verification_status'] == 'verified') _act(c, c.t('admin.unverify'), () => Repo.update('shops', 'id', r['id'] as Object, {'verification_status': 'unverified'}), reload, confirm: c.t('admin.confirm_revoke')),
                _act(c, r['is_active'] == true ? c.t('admin.disable') : c.t('admin.enable'), () => Repo.update('shops', 'id', r['id'] as Object, {'is_active': r['is_active'] != true}), reload),
              ],
            ),
        ]),
      );
}

class _OrdersAdmin extends StatelessWidget {
  const _OrdersAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('orders', select: 'id,order_number,status,total,currency_code,delivery_method,created_at', order: 'created_at', limit: 80),
        builder: (c, rows, reload) => Column(children: [
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: '#${r['order_number']} · ${formatPrice(r['total'] as num, r['currency_code'] as String, c.lang)}',
              subtitle: c.t('ship.${r['delivery_method']}'),
              chips: [StatusChip(c.t('order.s.${r['status']}'), tone: statusTone(r['status'] as String))],
              actions: [
                if (['pending', 'awaiting_payment', 'processing', 'paid'].contains(r['status']))
                  _act(c, c.t('order.cancel'), () => Repo.cancelOrder(r['id'] as String, 'admin'), reload, danger: true, confirm: c.t('admin.confirm_cancel_order')),
              ],
            ),
        ]),
      );
}

class _DisputesAdmin extends StatelessWidget {
  const _DisputesAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('disputes', order: 'created_at', limit: 80),
        builder: (c, rows, reload) => Column(children: [
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: r['reason'] as String,
              subtitle: '${r['order_id']}',
              chips: [StatusChip(r['status'] as String, tone: statusTone(r['status'] as String))],
              actions: [
                OutlinedButton(onPressed: () => c.push('/orders/${r['order_id']}'), child: Text(c.t('common.view'))),
                if (r['status'] == 'open') _act(c, c.t('admin.reviewing'), () => Repo.update('disputes', 'id', r['id'] as Object, {'status': 'investigating'}), reload),
                if (r['status'] == 'open' || r['status'] == 'investigating') ...[
                  _act(c, c.t('admin.favor_buyer'), () => Repo.update('disputes', 'id', r['id'] as Object, {'status': 'resolved_buyer'}), reload),
                  _act(c, c.t('admin.favor_seller'), () => Repo.update('disputes', 'id', r['id'] as Object, {'status': 'resolved_seller'}), reload),
                  _act(c, c.t('admin.close'), () => Repo.update('disputes', 'id', r['id'] as Object, {'status': 'closed'}), reload),
                ],
              ],
            ),
        ]),
      );
}

class _ActivateAdmin extends StatelessWidget {
  const _ActivateAdmin({super.key, required this.table, required this.select, required this.titleOf, required this.activeStatus});
  final String table, select, activeStatus;
  final String Function(Map<String, dynamic>) titleOf;
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table(table, select: select, order: 'created_at', limit: 80),
        builder: (c, rows, reload) => Column(children: [
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: titleOf(r),
              subtitle: '${r['plan_code']}',
              chips: [StatusChip(r['status'] as String, tone: statusTone(r['status'] as String))],
              actions: [
                if (r['status'] == 'pending') _act(c, c.t('admin.activate_after_payment'), () => Repo.update(table, 'id', r['id'] as Object, {'status': activeStatus}), reload),
                if (r['status'] == 'pending') _act(c, c.t('admin.reject'), () => Repo.update(table, 'id', r['id'] as Object, {'status': table == 'promotions' ? 'cancelled' : 'rejected'}), reload, danger: true),
              ],
            ),
        ]),
      );
}

// ---------- référentiels

class _CatalogAdmin extends StatelessWidget {
  const _CatalogAdmin({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.t('admin.categories'), style: Theme.of(context).textTheme.titleMedium),
        _Loader(
          load: () => Repo.table('categories', select: 'id,slug,name_fr,parent_id,enabled', order: 'sort_order', asc: true, limit: 300),
          builder: (c, rows, reload) => Column(children: [
            for (final r in rows.where((r) => r['parent_id'] == null))
              ExpansionTile(
                title: Text(r['name_fr'] as String),
                trailing: Switch(value: r['enabled'] == true, onChanged: (v) => guard(c, () async { await Repo.update('categories', 'id', r['id'] as Object, {'enabled': v}); reload(); })),
                children: [for (final s in rows.where((x) => x['parent_id'] == r['id'])) SwitchListTile(dense: true, title: Text(s['name_fr'] as String), value: s['enabled'] == true, onChanged: (v) => guard(c, () async { await Repo.update('categories', 'id', s['id'] as Object, {'enabled': v}); reload(); }))],
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(context.t('admin.brands'), style: Theme.of(context).textTheme.titleMedium),
        _Loader(
          load: () => Repo.table('brands', order: 'name', asc: true, limit: 300),
          builder: (c, rows, reload) => Column(children: [for (final r in rows) SwitchListTile(dense: true, title: Text(r['name'] as String), value: r['enabled'] == true, onChanged: (v) => guard(c, () async { await Repo.update('brands', 'id', r['id'] as Object, {'enabled': v}); reload(); }))]),
        ),
      ]);
}

class _CountriesAdmin extends StatelessWidget {
  const _CountriesAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('countries', order: 'sort_order', asc: true, limit: 100),
        builder: (c, rows, reload) => Column(children: [
          for (final r in rows) SwitchListTile(title: Text('${r['name_fr']} (${r['code']})'), subtitle: Text('${r['currency_code']}'), value: r['enabled'] == true, onChanged: (v) => guard(c, () async { await Repo.update('countries', 'code', r['code'] as Object, {'enabled': v}); reload(); })),
        ]),
      );
}

class _SettingsAdmin extends StatelessWidget {
  const _SettingsAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('platform_settings', order: 'key', asc: true),
        builder: (c, rows, reload) => Column(children: [
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: r['key'] as String,
              subtitle: r['description'] as String?,
              chips: [Chip(label: Text('${r['value']}'))],
              actions: [
                OutlinedButton(
                  onPressed: () async {
                    final v = await promptDialog(c, r['key'] as String, initial: '${r['value']}', multiline: false);
                    if (v == null || !c.mounted) return;
                    dynamic parsed;
                    parsed = v == 'true' ? true : v == 'false' ? false : (num.tryParse(v) ?? v);
                    await guard(c, () async {
                      await Repo.update('platform_settings', 'key', r['key'] as Object, {'value': parsed});
                      reload();
                    });
                  },
                  child: Text(c.t('common.edit')),
                ),
              ],
            ),
        ]),
      );
}

class _PlansAdmin extends StatelessWidget {
  const _PlansAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('plans', order: 'code', asc: true),
        builder: (c, rows, reload) => Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(c.t('admin.plans_sub'), style: Theme.of(c).textTheme.bodySmall)),
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: r['name'] as String,
              subtitle: '${formatPrice(r['price'] as num, r['currency_code'] as String, c.lang)} · ${r['duration_days']} ${c.t('common.days')}',
              chips: [StatusChip(r['kind'] as String), if (r['is_demo_price'] == true) const StatusChip('demo', tone: 2)],
              actions: [
                OutlinedButton(
                  onPressed: () async {
                    final v = await promptDialog(c, r['name'] as String, initial: '${r['price']}', multiline: false);
                    final p = parseNum(v);
                    if (p == null || !c.mounted) return;
                    await guard(c, () async {
                      await Repo.update('plans', 'code', r['code'] as Object, {'price': p, 'is_demo_price': false});
                      reload();
                    });
                  },
                  child: Text(c.t('common.edit')),
                ),
                Switch(value: r['enabled'] == true, onChanged: (v) => guard(c, () async { await Repo.update('plans', 'code', r['code'] as Object, {'enabled': v}); reload(); })),
              ],
            ),
        ]),
      );
}

class _ShippingAdmin extends StatelessWidget {
  const _ShippingAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('shipping_rules', order: 'from_country', asc: true),
        builder: (c, rows, reload) => Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(c.t('admin.shipping_sub'), style: Theme.of(c).textTheme.bodySmall)),
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: '${c.t('ship.${r['method']}')} · ${r['from_country']} → ${r['to_country']}',
              subtitle: '${formatPrice(r['fee'] as num, r['currency_code'] as String, c.lang)} · ${r['eta_days_min'] ?? '?'}–${r['eta_days_max'] ?? '?'} ${c.t('common.days')} ${r['carrier'] ?? ''}',
              actions: [
                Switch(value: r['enabled'] == true, onChanged: (v) => guard(c, () async { await Repo.update('shipping_rules', 'id', r['id'] as Object, {'enabled': v}); reload(); })),
                OutlinedButton(
                  onPressed: () async {
                    final v = await promptDialog(c, c.t('common.price'), initial: '${r['fee']}', multiline: false);
                    final p = parseNum(v);
                    if (p == null || !c.mounted) return;
                    await guard(c, () async { await Repo.update('shipping_rules', 'id', r['id'] as Object, {'fee': p}); reload(); });
                  },
                  child: Text(c.t('common.edit')),
                ),
                _act(c, c.t('common.delete'), () => Repo.remove('shipping_rules', 'id', r['id'] as Object), reload, danger: true, confirm: c.t('admin.confirm_delete')),
              ],
            ),
          OutlinedButton.icon(onPressed: () => _addRule(c, reload), icon: const Icon(Icons.add_rounded), label: Text(c.t('admin.add'))),
        ]),
      );

  Future<void> _addRule(BuildContext c, VoidCallback reload) async {
    final from = TextEditingController(text: 'BF');
    final to = TextEditingController(text: 'BF');
    final fee = TextEditingController();
    final cur = TextEditingController(text: 'XOF');
    String method = 'local';
    await showDialog<void>(
      context: c,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(ctx.t('admin.shipping')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(initialValue: method, items: [for (final m in const ['local', 'intercity', 'international']) DropdownMenuItem(value: m, child: Text(ctx.t('ship.$m')))], onChanged: (v) => set(() => method = v ?? method)),
              const SizedBox(height: 12),
              field(from, 'from (ISO)'),
              field(to, 'to (ISO)'),
              field(fee, ctx.t('common.price'), type: TextInputType.number),
              field(cur, ctx.t('common.currency')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('common.cancel'))),
            FilledButton(
              onPressed: () async {
                final f = parseNum(fee.text);
                if (f == null) return;
                Navigator.pop(ctx);
                await guard(c, () async {
                  await Repo.insert('shipping_rules', {'method': method, 'from_country': from.text.trim().toUpperCase(), 'to_country': to.text.trim().toUpperCase(), 'fee': f, 'currency_code': cur.text.trim().toUpperCase(), 'enabled': true});
                  reload();
                });
              },
              child: Text(ctx.t('common.save')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvidersAdmin extends StatelessWidget {
  const _ProvidersAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('payment_providers', order: 'code', asc: true),
        builder: (c, rows, reload) => Column(children: [
          Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: WM.volt.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)), child: Text(c.t('admin.providers_note'), style: Theme.of(c).textTheme.bodySmall)),
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: r['name'] as String,
              subtitle: r['notes'] as String?,
              chips: [if (r['sandbox'] == true) const StatusChip('sandbox', tone: 2), if (r['eligibility_verified'] == true) StatusChip(c.t('admin.eligibility_verified'), tone: 1)],
              actions: [
                Switch(
                  value: r['enabled'] == true,
                  onChanged: (v) => guard(c, () async {
                    if (v && r['code'] != 'offline' && r['eligibility_verified'] != true) throw Exception('provider_not_verified');
                    await Repo.update('payment_providers', 'code', r['code'] as Object, {'enabled': v});
                    reload();
                  }),
                ),
                if (r['code'] != 'offline') OutlinedButton(onPressed: () => guard(c, () async { await Repo.update('payment_providers', 'code', r['code'] as Object, {'eligibility_verified': r['eligibility_verified'] != true}); reload(); }), child: Text(c.t('admin.eligibility_verified'))),
              ],
            ),
        ]),
      );
}

class _KeywordsAdmin extends StatelessWidget {
  const _KeywordsAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('banned_keywords', order: 'keyword', asc: true, limit: 300),
        builder: (c, rows, reload) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.t('admin.keywords_sub'), style: Theme.of(c).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final r in rows) InputChip(label: Text(r['keyword'] as String), onDeleted: () => guard(c, () async { await Repo.remove('banned_keywords', 'id', r['id'] as Object); reload(); }))]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final k = await promptDialog(c, c.t('admin.add'), multiline: false);
              if (k == null || !c.mounted) return;
              await guard(c, () async { await Repo.insert('banned_keywords', {'keyword': k.toLowerCase()}); reload(); });
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(c.t('admin.add')),
          ),
        ]),
      );
}

class _AuditAdmin extends StatelessWidget {
  const _AuditAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('audit_logs', order: 'created_at', limit: 100),
        builder: (c, rows, reload) => Column(children: [
          for (final (i, r) in rows.indexed) _Row(index: i, title: '${r['action']} · ${r['entity_type']}', subtitle: '${r['entity_id']}\n${timeAgo(DateTime.parse(r['created_at'] as String), c.lang)}'),
        ]),
      );
}

class _DeletionsAdmin extends StatelessWidget {
  const _DeletionsAdmin({super.key});
  @override
  Widget build(BuildContext context) => _Loader(
        load: () => Repo.table('data_deletion_requests', order: 'created_at', limit: 100),
        builder: (c, rows, reload) => Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(c.t('admin.deletions_sub'), style: Theme.of(c).textTheme.bodySmall)),
          for (final (i, r) in rows.indexed)
            _Row(
              index: i,
              title: '${r['user_id']}',
              subtitle: r['reason'] as String?,
              chips: [StatusChip(r['status'] as String, tone: statusTone(r['status'] as String))],
              actions: [
                if (r['status'] == 'pending') ...[
                  _act(c, c.t('admin.execute_deletion'), () async {
                    await sb.rpc('anonymize_user', params: {'p_user': r['user_id']});
                    await Repo.update('data_deletion_requests', 'id', r['id'] as Object, {'status': 'done'});
                  }, reload, danger: true, confirm: c.t('admin.confirm_delete_account')),
                  _act(c, c.t('admin.reject'), () => Repo.update('data_deletion_requests', 'id', r['id'] as Object, {'status': 'rejected'}), reload),
                ],
              ],
            ),
        ]),
      );
}
