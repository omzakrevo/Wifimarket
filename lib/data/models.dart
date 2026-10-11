import '../core/utils/format.dart';

T? _enum<T>(dynamic v, T Function(String) f) => v == null ? null : f(v as String);

class Category {
  Category({required this.id, required this.parentId, required this.slug, required this.nameFr, required this.nameEn, this.icon, this.enabled = true, this.sortOrder = 0});
  final int id;
  final int? parentId;
  final String slug, nameFr, nameEn;
  final String? icon;
  final bool enabled;
  final int sortOrder;
  String name(String lang) => lang == 'en' ? nameEn : nameFr;
  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as int,
        parentId: j['parent_id'] as int?,
        slug: j['slug'] as String,
        nameFr: j['name_fr'] as String,
        nameEn: j['name_en'] as String,
        icon: j['icon'] as String?,
        enabled: j['enabled'] as bool? ?? true,
        sortOrder: j['sort_order'] as int? ?? 0,
      );
}

class Brand {
  Brand({required this.id, required this.slug, required this.name, this.enabled = true});
  final int id;
  final String slug, name;
  final bool enabled;
  factory Brand.fromJson(Map<String, dynamic> j) =>
      Brand(id: j['id'] as int, slug: j['slug'] as String, name: j['name'] as String, enabled: j['enabled'] as bool? ?? true);
}

class ProductModel {
  ProductModel({required this.id, required this.brandId, required this.name});
  final int id, brandId;
  final String name;
  factory ProductModel.fromJson(Map<String, dynamic> j) =>
      ProductModel(id: j['id'] as int, brandId: j['brand_id'] as int, name: j['name'] as String);
}

class Country {
  Country({required this.code, required this.nameFr, required this.nameEn, required this.currency});
  final String code, nameFr, nameEn, currency;
  String name(String lang) => lang == 'en' ? nameEn : nameFr;
  factory Country.fromJson(Map<String, dynamic> j) => Country(
      code: j['code'] as String, nameFr: j['name_fr'] as String, nameEn: j['name_en'] as String, currency: j['currency_code'] as String);
}

class City {
  City({required this.country, required this.name});
  final String country, name;
  factory City.fromJson(Map<String, dynamic> j) => City(country: j['country_code'] as String, name: j['name'] as String);
}

class Profile {
  Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.countryCode,
    this.city,
    this.showWhatsapp = false,
    this.verification = 'unverified',
    this.isSuspended = false,
    this.createdAt,
  });
  final String id, displayName;
  final String? avatarUrl, bio, countryCode, city;
  final bool showWhatsapp, isSuspended;
  final String verification;
  final DateTime? createdAt;
  bool get verified => verification == 'verified';
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        displayName: (j['display_name'] as String?) ?? '?',
        avatarUrl: j['avatar_url'] as String?,
        bio: j['bio'] as String?,
        countryCode: j['country_code'] as String?,
        city: j['city'] as String?,
        showWhatsapp: j['show_whatsapp'] as bool? ?? false,
        verification: j['verification_status'] as String? ?? 'unverified',
        isSuspended: j['is_suspended'] as bool? ?? false,
        createdAt: j['created_at'] == null ? null : DateTime.parse(j['created_at'] as String),
      );
}

class Media {
  Media({required this.path, required this.kind, required this.position});
  final String path, kind;
  final int position;
  bool get isImage => kind == 'image';
  String get url => publicUrl('listing-media', path);
}

class Listing {
  Listing({
    required this.id,
    required this.sellerId,
    this.shopId,
    required this.categoryId,
    this.brandId,
    this.modelId,
    this.modelText,
    required this.title,
    required this.slug,
    required this.description,
    required this.condition,
    required this.price,
    required this.currency,
    required this.quantity,
    required this.country,
    this.city,
    required this.delivery,
    this.defects,
    this.warranty,
    required this.negotiable,
    required this.exchange,
    this.exchangeWanted,
    required this.status,
    this.rejectionReason,
    required this.sponsored,
    this.sponsoredUntil,
    required this.views,
    this.publishedAt,
    this.expiresAt,
    required this.createdAt,
    this.media = const [],
    this.categorySlug,
    this.categoryNameFr,
    this.categoryNameEn,
    this.categoryIcon,
    this.brandName,
    this.brandSlug,
    this.seller,
  });

  final String id, sellerId, title, slug, description, condition, currency, country, status;
  final String? shopId, modelText, city, defects, warranty, exchangeWanted, rejectionReason;
  final int categoryId, quantity, views;
  final int? brandId, modelId;
  final num price;
  final bool delivery, negotiable, exchange, sponsored;
  final DateTime? sponsoredUntil, publishedAt, expiresAt;
  final DateTime createdAt;
  final List<Media> media;
  final String? categorySlug, categoryNameFr, categoryNameEn, categoryIcon, brandName, brandSlug;
  final Profile? seller;

  bool get isSponsoredNow => sponsored && (sponsoredUntil == null || sponsoredUntil!.isAfter(DateTime.now()));
  List<Media> get images => ([...media]..sort((a, b) => a.position.compareTo(b.position))).where((m) => m.isImage).toList();
  String? get cover => images.isEmpty ? null : images.first.url;
  String? categoryName(String lang) => lang == 'en' ? categoryNameEn : categoryNameFr;

  factory Listing.fromJson(Map<String, dynamic> j) {
    final cat = j['categories'] as Map<String, dynamic>?;
    final brand = j['brands'] as Map<String, dynamic>?;
    final prof = j['profiles'] as Map<String, dynamic>?;
    return Listing(
      id: j['id'] as String,
      sellerId: j['seller_id'] as String,
      shopId: j['shop_id'] as String?,
      categoryId: j['category_id'] as int,
      brandId: j['brand_id'] as int?,
      modelId: j['model_id'] as int?,
      modelText: j['model_text'] as String?,
      title: j['title'] as String,
      slug: j['slug'] as String,
      description: (j['description'] as String?) ?? '',
      condition: j['condition'] as String,
      price: j['price'] as num,
      currency: j['currency_code'] as String,
      quantity: j['quantity'] as int,
      country: j['country_code'] as String,
      city: j['city'] as String?,
      delivery: j['delivery_available'] as bool? ?? false,
      defects: j['defects'] as String?,
      warranty: j['warranty'] as String?,
      negotiable: j['negotiable'] as bool? ?? true,
      exchange: j['exchange_possible'] as bool? ?? false,
      exchangeWanted: j['exchange_wanted'] as String?,
      status: j['status'] as String,
      rejectionReason: j['rejection_reason'] as String?,
      sponsored: j['is_sponsored'] as bool? ?? false,
      sponsoredUntil: _enum(j['sponsored_until'], DateTime.parse),
      views: j['views_count'] as int? ?? 0,
      publishedAt: _enum(j['published_at'], DateTime.parse),
      expiresAt: _enum(j['expires_at'], DateTime.parse),
      createdAt: DateTime.parse(j['created_at'] as String),
      media: ((j['listing_media'] as List?) ?? const [])
          .map((m) => Media(path: m['storage_path'] as String, kind: m['kind'] as String, position: (m['position'] as int?) ?? 0))
          .toList(),
      categorySlug: cat?['slug'] as String?,
      categoryNameFr: cat?['name_fr'] as String?,
      categoryNameEn: cat?['name_en'] as String?,
      categoryIcon: cat?['icon'] as String?,
      brandName: brand?['name'] as String?,
      brandSlug: brand?['slug'] as String?,
      seller: prof == null ? null : Profile.fromJson(prof),
    );
  }
}

class Shop {
  Shop({required this.id, required this.ownerId, required this.slug, required this.name, this.description, this.logo, this.banner, this.country, this.city, this.plan = 'free', this.verification = 'unverified', this.isActive = true});
  final String id, ownerId, slug, name, plan, verification;
  final String? description, logo, banner, country, city;
  final bool isActive;
  bool get verified => verification == 'verified';
  String? get logoUrl => logo == null ? null : publicUrl('shop-assets', logo!);
  String? get bannerUrl => banner == null ? null : publicUrl('shop-assets', banner!);
  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: j['id'] as String,
        ownerId: j['owner_id'] as String? ?? '',
        slug: j['slug'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        logo: j['logo_url'] as String?,
        banner: j['banner_url'] as String?,
        country: j['country_code'] as String?,
        city: j['city'] as String?,
        plan: j['plan'] as String? ?? 'free',
        verification: j['verification_status'] as String? ?? 'unverified',
        isActive: j['is_active'] as bool? ?? true,
      );
}

/// Filtres de recherche (miroir de la fonction SQL `search_listings`).
class SearchParams {
  const SearchParams({
    this.q,
    this.category,
    this.brand,
    this.country,
    this.city,
    this.min,
    this.max,
    this.currency,
    this.condition,
    this.inStock = false,
    this.delivery = false,
    this.exchange = false,
    this.sinceDays,
    this.shop,
    this.seller,
    this.sort = 'relevance',
  });
  final String? q, category, brand, country, city, currency, condition, shop, seller;
  final num? min, max;
  final bool inStock, delivery, exchange;
  final int? sinceDays;
  final String sort;

  SearchParams copyWith({
    Object? q = _unset,
    Object? category = _unset,
    Object? brand = _unset,
    Object? country = _unset,
    Object? city = _unset,
    Object? min = _unset,
    Object? max = _unset,
    Object? currency = _unset,
    Object? condition = _unset,
    bool? inStock,
    bool? delivery,
    bool? exchange,
    Object? sinceDays = _unset,
    Object? shop = _unset,
    Object? seller = _unset,
    String? sort,
  }) =>
      SearchParams(
        q: identical(q, _unset) ? this.q : q as String?,
        category: identical(category, _unset) ? this.category : category as String?,
        brand: identical(brand, _unset) ? this.brand : brand as String?,
        country: identical(country, _unset) ? this.country : country as String?,
        city: identical(city, _unset) ? this.city : city as String?,
        min: identical(min, _unset) ? this.min : min as num?,
        max: identical(max, _unset) ? this.max : max as num?,
        currency: identical(currency, _unset) ? this.currency : currency as String?,
        condition: identical(condition, _unset) ? this.condition : condition as String?,
        inStock: inStock ?? this.inStock,
        delivery: delivery ?? this.delivery,
        exchange: exchange ?? this.exchange,
        sinceDays: identical(sinceDays, _unset) ? this.sinceDays : sinceDays as int?,
        shop: identical(shop, _unset) ? this.shop : shop as String?,
        seller: identical(seller, _unset) ? this.seller : seller as String?,
        sort: sort ?? this.sort,
      );

  static const _unset = Object();

  Map<String, dynamic> baseArgs() => {
        'p_q': (q ?? '').trim().isEmpty ? null : q!.trim(),
        'p_category': category,
        'p_brand': brand,
        'p_country': country,
        'p_city': city,
        'p_min': min,
        'p_max': max,
        'p_currency': currency,
        'p_condition': condition,
        'p_in_stock': inStock,
        'p_delivery': delivery,
        'p_exchange': exchange,
        'p_since_days': sinceDays,
        'p_shop': shop,
        'p_seller': seller,
      };

  int get activeFilters => [category, brand, country, city, min, max, currency, condition, sinceDays].where((e) => e != null).length +
      (inStock ? 1 : 0) +
      (delivery ? 1 : 0) +
      (exchange ? 1 : 0);

  @override
  bool operator ==(Object other) =>
      other is SearchParams && other.q == q && other.category == category && other.brand == brand && other.country == country && other.city == city && other.min == min && other.max == max && other.currency == currency && other.condition == condition && other.inStock == inStock && other.delivery == delivery && other.exchange == exchange && other.sinceDays == sinceDays && other.shop == shop && other.seller == seller && other.sort == sort;

  @override
  int get hashCode => Object.hash(q, category, brand, country, city, min, max, currency, condition, inStock, delivery, exchange, sinceDays, shop, seller, sort);
}
