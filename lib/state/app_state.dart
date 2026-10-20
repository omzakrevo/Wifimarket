import 'dart:math';

import 'package:flutter/widgets.dart';

import '../data/demo_data.dart';
import '../data/models.dart';

/// État global de l'application (démo en mémoire).
/// En production, chaque méthode correspond à un appel Supabase
/// (voir backend/supabase_schema.sql).
class AppState extends ChangeNotifier {
  final List<Shop> shops = demoShops();
  final List<Product> products = demoProducts();
  final List<Listing> listings = demoListings();
  final List<CartLine> cart = [];
  final Set<String> favorites = {};

  /// Un compte visiteur par pays : il est créé à la volée la première fois
  /// que l'utilisateur choisit un pays, puis réutilisé.
  final Map<String, AppUser> visitorAccounts = {};
  AppUser? user;

  bool get onboarded => user != null;
  Country get country => countryByCode(user?.countryCode ?? 'BF');
  bool get isAdmin => user?.role == UserRole.admin;
  bool get isSeller => user?.role == UserRole.seller;

  // ---------- Comptes ----------
  void chooseCountry(String code) {
    final prev = user;
    final account = visitorAccounts.putIfAbsent(code, () {
      final id = '$code-${Random().nextInt(90000) + 10000}';
      return AppUser(id: id, displayName: 'Visiteur $id', countryCode: code);
    });
    // On conserve le rôle courant (vendeur/admin) quand on change de pays.
    if (prev != null && prev.role != UserRole.visitor) {
      prev.countryCode = code;
      user = prev;
    } else {
      user = account;
    }
    cart.clear();
    notifyListeners();
  }

  void switchRole(UserRole role) {
    final u = user;
    if (u == null) return;
    u.role = role;
    if (role == UserRole.seller && u.shopId == null) {
      // Démo : rattache le vendeur à la première boutique active du pays.
      final s = shops.where(
        (s) => s.countryCode == u.countryCode && s.status == ShopStatus.active,
      );
      if (s.isNotEmpty) u.shopId = s.first.id;
    }
    notifyListeners();
  }

  // ---------- Catalogue filtré par pays ----------
  Iterable<Shop> get activeShops => shops.where(
    (s) => s.status == ShopStatus.active && s.countryCode == country.code,
  );

  Shop? shopById(String id) {
    for (final s in shops) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Produits visibles : boutiques actives du pays du visiteur.
  /// S'il n'y en a aucune, on montre les boutiques actives de la sous-région
  /// (livraison internationale).
  List<Product> get visibleProducts {
    final ids = activeShops.map((s) => s.id).toSet();
    final local = products.where((p) => ids.contains(p.shopId)).toList();
    if (local.isNotEmpty) return local;
    final all = shops
        .where((s) => s.status == ShopStatus.active)
        .map((s) => s.id)
        .toSet();
    return products.where((p) => all.contains(p.shopId)).toList();
  }

  List<Product> search(String q, {String? categoryId}) {
    final s = q.trim().toLowerCase();
    return visibleProducts.where((p) {
      if (categoryId != null && p.categoryId != categoryId) return false;
      if (s.isEmpty) return true;
      return p.name.toLowerCase().contains(s) ||
          p.brand.toLowerCase().contains(s);
    }).toList();
  }

  List<Listing> get publishedListings =>
      listings
          .where(
            (l) =>
                l.status == ListingStatus.published &&
                l.countryCode == country.code,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ---------- Panier ----------
  int get cartCount => cart.fold(0, (a, l) => a + l.qty);
  int get cartTotal => cart.fold(0, (a, l) => a + l.qty * l.product.priceXof);

  void addToCart(Product p) {
    final i = cart.indexWhere((l) => l.product.id == p.id);
    if (i >= 0) {
      cart[i].qty++;
    } else {
      cart.add(CartLine(p, 1));
    }
    notifyListeners();
  }

  void setQty(CartLine line, int qty) {
    if (qty <= 0) {
      cart.remove(line);
    } else {
      line.qty = qty;
    }
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  void toggleFavorite(String id) {
    favorites.contains(id) ? favorites.remove(id) : favorites.add(id);
    notifyListeners();
  }

  // ---------- Annonces d'occasion ----------
  void publishListing(Listing l) {
    listings.insert(0, l); // statut « pending » : modération admin
    notifyListeners();
  }

  void setListingStatus(Listing l, ListingStatus s) {
    l.status = s;
    notifyListeners();
  }

  // ---------- Boutiques (SaaS) ----------
  void applyForShop(Shop s) {
    shops.add(s);
    final u = user;
    if (u != null) u.shopId = s.id;
    notifyListeners();
  }

  void setShopStatus(Shop s, ShopStatus status) {
    s.status = status;
    notifyListeners();
  }

  void setShopPlan(Shop s, Plan plan) {
    s.plan = plan;
    notifyListeners();
  }

  void toggleVerified(Shop s) {
    s.verified = !s.verified;
    notifyListeners();
  }

  void addProduct(Product p) {
    products.insert(0, p);
    notifyListeners();
  }

  void removeProduct(Product p) {
    products.remove(p);
    notifyListeners();
  }

  int get monthlyRevenueXof => shops
      .where((s) => s.status == ShopStatus.active)
      .fold(0, (a, s) => a + s.plan.monthlyXof);
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
