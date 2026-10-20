import 'package:flutter/material.dart';

/// Pays couvert par la plateforme. Chaque visiteur est rattaché à un pays :
/// catalogue, boutiques, annonces et devise en dépendent.
class Country {
  final String code; // ISO 3166-1 alpha-2
  final String name;
  final String flag;
  final String currency; // XOF, XAF, GHS, NGN…
  final String symbol;
  final double ratePerXof; // 1 XOF = ratePerXof unités locales
  final String phonePrefix;

  const Country({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.symbol,
    required this.ratePerXof,
    required this.phonePrefix,
  });

  String format(int priceXof) {
    final v = (priceXof * ratePerXof).round();
    final s = v.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$s $symbol';
  }
}

class Category {
  final String id;
  final String name;
  final IconData icon;
  const Category(this.id, this.name, this.icon);
}

enum ShopStatus { pending, active, suspended }

enum Plan { starter, pro, business }

extension PlanInfo on Plan {
  String get label => switch (this) {
    Plan.starter => 'Starter',
    Plan.pro => 'Pro',
    Plan.business => 'Business',
  };
  int get monthlyXof => switch (this) {
    Plan.starter => 0,
    Plan.pro => 15000,
    Plan.business => 35000,
  };
  int get productLimit => switch (this) {
    Plan.starter => 10,
    Plan.pro => 200,
    Plan.business => 100000,
  };
  String get perks => switch (this) {
    Plan.starter => '10 produits • commission 8 %',
    Plan.pro => '200 produits • commission 5 % • statistiques',
    Plan.business =>
      'Illimité • commission 3 % • mise en avant • badge vérifié',
  };
}

class Shop {
  final String id;
  String name;
  String owner;
  String phone;
  String city;
  String countryCode;
  String description;
  String logoUrl;
  ShopStatus status;
  Plan plan;
  bool verified;
  final DateTime createdAt;

  Shop({
    required this.id,
    required this.name,
    required this.owner,
    required this.phone,
    required this.city,
    required this.countryCode,
    required this.description,
    required this.logoUrl,
    this.status = ShopStatus.pending,
    this.plan = Plan.starter,
    this.verified = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class Product {
  final String id;
  final String shopId;
  final String categoryId;
  String name;
  String brand;
  String description;
  List<String> specs;
  int priceXof;
  int? oldPriceXof;
  int stock;
  double rating;
  int reviews;
  String imageUrl;
  String? badge; // MEILLEURE VENTE, TENDANCE, POPULAIRE…

  Product({
    required this.id,
    required this.shopId,
    required this.categoryId,
    required this.name,
    required this.brand,
    required this.description,
    required this.specs,
    required this.priceXof,
    this.oldPriceXof,
    required this.stock,
    required this.rating,
    required this.reviews,
    required this.imageUrl,
    this.badge,
  });
}

enum ListingCondition { likeNew, good, fair, forParts }

extension ConditionInfo on ListingCondition {
  String get label => switch (this) {
    ListingCondition.likeNew => 'Comme neuf',
    ListingCondition.good => 'Bon état',
    ListingCondition.fair => 'État correct',
    ListingCondition.forParts => 'Pour pièces',
  };
  Color get color => switch (this) {
    ListingCondition.likeNew => const Color(0xFF16A34A),
    ListingCondition.good => const Color(0xFF2563EB),
    ListingCondition.fair => const Color(0xFFD97706),
    ListingCondition.forParts => const Color(0xFFDC2626),
  };
}

enum ListingStatus { pending, published, rejected, sold }

/// Annonce de matériel d'occasion publiée par un particulier ou une boutique.
class Listing {
  final String id;
  final String sellerName;
  final String sellerPhone;
  final String countryCode;
  final String city;
  final String categoryId;
  String title;
  String description;
  int priceXof;
  bool negotiable;
  ListingCondition condition;
  ListingStatus status;
  String imageUrl;
  final DateTime createdAt;
  int views;

  Listing({
    required this.id,
    required this.sellerName,
    required this.sellerPhone,
    required this.countryCode,
    required this.city,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.priceXof,
    this.negotiable = true,
    required this.condition,
    this.status = ListingStatus.pending,
    required this.imageUrl,
    DateTime? createdAt,
    this.views = 0,
  }) : createdAt = createdAt ?? DateTime.now();
}

enum UserRole { visitor, seller, admin }

/// Compte utilisateur. Par défaut chaque appareil reçoit un compte
/// « visiteur » rattaché au pays choisi au premier lancement.
class AppUser {
  final String id;
  String displayName;
  String countryCode;
  UserRole role;
  String? shopId;
  String? phone;

  AppUser({
    required this.id,
    required this.displayName,
    required this.countryCode,
    this.role = UserRole.visitor,
    this.shopId,
    this.phone,
  });
}

class CartLine {
  final Product product;
  int qty;
  CartLine(this.product, this.qty);
}
