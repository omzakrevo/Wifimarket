import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/motion.dart';
import 'data/models.dart';
import 'data/providers.dart';
import 'features/account/account_screens.dart';
import 'features/admin/admin_screens.dart';
import 'features/auth/auth_screen.dart';
import 'features/chat/chat_screens.dart';
import 'features/home/home_screen.dart';
import 'features/info/info_screens.dart';
import 'features/listing/listing_form.dart';
import 'features/listing/listing_screen.dart';
import 'features/nego/nego_screens.dart';
import 'features/orders/cart_screens.dart';
import 'features/orders/order_screens.dart';
import 'features/search/search_screen.dart';
import 'features/shell.dart';
import 'features/shops/shop_screens.dart';
import 'features/wanted/wanted_screens.dart';

CustomTransitionPage<void> _page(GoRouterState s, Widget child) => CustomTransitionPage<void>(
      key: s.pageKey,
      child: child,
      transitionDuration: Motion.page,
      reverseTransitionDuration: Motion.base,
      transitionsBuilder: (context, anim, sec, child) {
        final curved = CurvedAnimation(parent: anim, curve: Motion.emphasized);
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: SlideTransition(position: Tween(begin: const Offset(0, .035), end: Offset.zero).animate(curved), child: child),
        );
      },
    );

const _protected = [
  '/sell', '/favorites', '/messages', '/account', '/cart', '/checkout', '/orders', '/negotiations', '/notifications', '/wanted/new', '/shop/manage', '/admin',
];

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => auth.value++);
  ref.onDispose(auth.dispose);
  return GoRouter(
    refreshListenable: auth,
    redirect: (context, state) {
      final logged = ref.read(sessionProvider) != null;
      final path = state.uri.path;
      if (!logged && _protected.any((p) => path == p || path.startsWith('$p/'))) {
        return '/auth?next=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (logged && path == '/auth') return state.uri.queryParameters['next'] ?? '/';
      return null;
    },
    errorBuilder: (c, s) => const NotFoundScreen(),
    routes: [
      ShellRoute(
        builder: (c, s, child) => AppShell(location: s.uri.path, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (c, s) => _page(s, const HomeScreen())),
          GoRoute(path: '/search', pageBuilder: (c, s) => _page(s, SearchScreen(params: SearchParams(
                q: s.uri.queryParameters['q'],
                category: s.uri.queryParameters['category'],
                brand: s.uri.queryParameters['brand'],
                shop: s.uri.queryParameters['shop'],
                seller: s.uri.queryParameters['seller'],
                condition: s.uri.queryParameters['condition'],
              )))),
          GoRoute(path: '/category/:slug', pageBuilder: (c, s) => _page(s, SearchScreen(params: SearchParams(category: s.pathParameters['slug']), lockedCategory: true))),
          GoRoute(path: '/listing/:id', pageBuilder: (c, s) => _page(s, ListingScreen(id: s.pathParameters['id']!, initial: s.extra is Listing ? s.extra as Listing : null))),
          GoRoute(path: '/sell', pageBuilder: (c, s) => _page(s, const ListingFormScreen())),
          GoRoute(path: '/sell/:id', pageBuilder: (c, s) => _page(s, ListingFormScreen(editId: s.pathParameters['id']))),
          GoRoute(path: '/auth', pageBuilder: (c, s) => _page(s, AuthScreen(next: s.uri.queryParameters['next'], signup: s.uri.queryParameters['mode'] == 'signup'))),
          GoRoute(path: '/auth/reset', pageBuilder: (c, s) => _page(s, const ResetPasswordScreen())),
          GoRoute(path: '/account', pageBuilder: (c, s) => _page(s, const AccountScreen())),
          GoRoute(path: '/account/profile', pageBuilder: (c, s) => _page(s, const ProfileScreen())),
          GoRoute(path: '/account/listings', pageBuilder: (c, s) => _page(s, const MyListingsScreen())),
          GoRoute(path: '/account/searches', pageBuilder: (c, s) => _page(s, const SavedSearchesScreen())),
          GoRoute(path: '/favorites', pageBuilder: (c, s) => _page(s, const FavoritesScreen())),
          GoRoute(path: '/notifications', pageBuilder: (c, s) => _page(s, const NotificationsScreen())),
          GoRoute(path: '/messages', pageBuilder: (c, s) => _page(s, const MessagesScreen())),
          GoRoute(path: '/messages/:id', pageBuilder: (c, s) => _page(s, ChatScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/wanted', pageBuilder: (c, s) => _page(s, const WantedScreen())),
          GoRoute(path: '/wanted/new', pageBuilder: (c, s) => _page(s, const WantedNewScreen())),
          GoRoute(path: '/wanted/:id', pageBuilder: (c, s) => _page(s, WantedDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/negotiations', pageBuilder: (c, s) => _page(s, const NegotiationsScreen())),
          GoRoute(path: '/shops', pageBuilder: (c, s) => _page(s, const ShopsScreen())),
          GoRoute(path: '/shop/manage', pageBuilder: (c, s) => _page(s, const MyShopScreen())),
          GoRoute(path: '/shop/:slug', pageBuilder: (c, s) => _page(s, ShopScreen(slug: s.pathParameters['slug']!))),
          GoRoute(path: '/seller/:id', pageBuilder: (c, s) => _page(s, SellerScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/cart', pageBuilder: (c, s) => _page(s, const CartScreen())),
          GoRoute(path: '/checkout', pageBuilder: (c, s) => _page(s, const CheckoutScreen())),
          GoRoute(path: '/orders', pageBuilder: (c, s) => _page(s, OrdersScreen(sales: s.uri.queryParameters['tab'] == 'sales'))),
          GoRoute(path: '/orders/:id', pageBuilder: (c, s) => _page(s, OrderDetailScreen(id: s.pathParameters['id']!))),
          GoRoute(path: '/admin', pageBuilder: (c, s) => _page(s, const AdminScreen())),
          GoRoute(path: '/admin/:section', pageBuilder: (c, s) => _page(s, AdminScreen(section: s.pathParameters['section']))),
          GoRoute(path: '/info/:doc', pageBuilder: (c, s) => _page(s, InfoScreen(doc: s.pathParameters['doc']!))),
        ],
      ),
    ],
  );
});
