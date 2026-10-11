import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import 'repo.dart';

/// Session Supabase (null si non connecté).
class SessionNotifier extends Notifier<Session?> {
  StreamSubscription<AuthState>? _sub;
  @override
  Session? build() {
    _sub?.cancel();
    _sub = sb.auth.onAuthStateChange.listen((e) => state = e.session);
    ref.onDispose(() => _sub?.cancel());
    return sb.auth.currentSession;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
final uidProvider = Provider<String?>((ref) => ref.watch(sessionProvider)?.user.id);

final categoriesProvider = FutureProvider<List<Category>>((ref) => Repo.categories());
final brandsProvider = FutureProvider<List<Brand>>((ref) => Repo.brands());
final countriesProvider = FutureProvider<List<Country>>((ref) => Repo.countries());
final citiesProvider = FutureProvider<List<City>>((ref) => Repo.cities());
final settingsProvider = FutureProvider<Map<String, dynamic>>((ref) => Repo.settings());

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final uid = ref.watch(uidProvider);
  return uid == null ? null : Repo.profile(uid);
});
final myRolesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(uidProvider);
  return Repo.myRoles();
});

/// Pays choisi (code ISO) ou null = tous.
class CountryNotifier extends Notifier<String?> {
  @override
  String? build() {
    SharedPreferences.getInstance().then((p) {
      final v = p.getString('wm_country');
      if (v != null && v.isNotEmpty) state = v;
    });
    return null;
  }

  Future<void> set(String? c) async {
    state = c;
    final p = await SharedPreferences.getInstance();
    c == null ? await p.remove('wm_country') : await p.setString('wm_country', c);
  }
}

final countryProvider = NotifierProvider<CountryNotifier, String?>(CountryNotifier.new);

class ThemeNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    SharedPreferences.getInstance().then((p) {
      final v = p.getString('wm_theme');
      if (v == 'dark') state = true;
      if (v == 'light') state = false;
    });
    return null;
  }

  Future<void> set(bool? dark) async {
    state = dark;
    final p = await SharedPreferences.getInstance();
    dark == null ? await p.remove('wm_theme') : await p.setString('wm_theme', dark ? 'dark' : 'light');
  }
}

/// null = suit le système.
final themeProvider = NotifierProvider<ThemeNotifier, bool?>(ThemeNotifier.new);

class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final uid = ref.watch(uidProvider);
    if (uid != null) Repo.favoriteIds().then((s) => state = s).catchError((_) => state);
    return {};
  }

  /// Retourne false si l'utilisateur n'est pas connecté.
  Future<bool> toggle(String id) async {
    if (myId == null) return false;
    final add = !state.contains(id);
    state = add ? {...state, id} : ({...state}..remove(id));
    try {
      await Repo.toggleFavorite(id, add);
    } catch (_) {
      state = add ? ({...state}..remove(id)) : {...state, id};
      rethrow;
    }
    ref.invalidate(favoriteListingsProvider);
    return true;
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);
final favoriteListingsProvider = FutureProvider<List<Listing>>((ref) {
  ref.watch(uidProvider);
  return Repo.favorites();
});

/// Compteurs en direct (non lus / notifications) via Realtime.
class CountersNotifier extends Notifier<({int messages, int notifications})> {
  RealtimeChannel? _ch;
  @override
  ({int messages, int notifications}) build() {
    final uid = ref.watch(uidProvider);
    _ch?.unsubscribe();
    if (uid == null) return (messages: 0, notifications: 0);
    refresh();
    _ch = sb
        .channel('counters-$uid')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'messages', callback: (_) => refresh())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'notifications', callback: (_) => refresh())
        .subscribe();
    ref.onDispose(() => _ch?.unsubscribe());
    return (messages: 0, notifications: 0);
  }

  Future<void> refresh() async {
    final uid = myId;
    if (uid == null) return;
    try {
      final m = await sb.from('messages').select('id').neq('sender_id', uid).isFilter('read_at', null);
      final n = await sb.from('notifications').select('id').eq('user_id', uid).isFilter('read_at', null);
      state = (messages: m.length, notifications: n.length);
    } catch (_) {}
  }
}

final countersProvider = NotifierProvider<CountersNotifier, ({int messages, int notifications})>(CountersNotifier.new);

// ---------- accueil
final homeRecentProvider = FutureProvider.family<List<Listing>, String?>((ref, country) => Repo.latest(country: country, limit: 12));
final homeUsedProvider = FutureProvider.family<List<Listing>, String?>((ref, c) => Repo.latest(condition: 'used', country: c, limit: 10));
final homeNewProvider = FutureProvider.family<List<Listing>, String?>((ref, c) => Repo.latest(condition: 'new', country: c, limit: 10));
final homeSponsoredProvider = FutureProvider.family<List<Listing>, String?>((ref, c) => Repo.latest(sponsored: true, country: c, limit: 10));
final shopsProvider = FutureProvider<List<Shop>>((ref) => Repo.shops(limit: 12));
final listingProvider = FutureProvider.family<Listing?, String>((ref, id) => Repo.listing(id));
final myListingsProvider = FutureProvider<List<Listing>>((ref) {
  ref.watch(uidProvider);
  return Repo.myListings();
});
