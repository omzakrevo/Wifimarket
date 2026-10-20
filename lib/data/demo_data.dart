import 'package:flutter/material.dart';

import 'models.dart';

/// Photos libres de droits (Licence Unsplash — usage commercial gratuit,
/// sans attribution obligatoire). Remplacez par vos propres photos produit
/// une fois les boutiques en ligne.
class Img {
  static const _q = '?auto=format&fit=crop&w=800&q=70';
  static const router =
      'https://images.unsplash.com/photo-1745847768408-b7b83796cae6$_q';
  static const modem =
      'https://images.unsplash.com/photo-1554098415-cae1af5e4f1a$_q';
  static const device =
      'https://images.unsplash.com/photo-1612045194743-877419047a35$_q';
  static const switchPoe =
      'https://images.unsplash.com/photo-1750711731797-25c3f2551ff8$_q';
  static const tower =
      'https://images.unsplash.com/photo-1742534620800-fc7caae0dd45$_q';
  static const tower2 =
      'https://images.unsplash.com/photo-1602823284936-463177448097$_q';
  static const tower3 =
      'https://images.unsplash.com/photo-1643155193188-38eb08e2b54f$_q';
  static const dish =
      'https://images.unsplash.com/photo-1590433333434-09df2b2a35a5$_q';
  static const wires =
      'https://images.unsplash.com/photo-1691435828932-911a7801adfb$_q';
  static const utp =
      'https://images.unsplash.com/photo-1544197150-b99a580bb7a8$_q';
  static const cableRoll =
      'https://images.unsplash.com/photo-1518181835702-6eef8b4b2113$_q';
  static const blueWires =
      'https://images.unsplash.com/photo-1683322499436-f4383dd59f5a$_q';
  static const serverRack =
      'https://images.unsplash.com/photo-1762163516269-3c143e04175c$_q';
  static const serverRoom =
      'https://images.unsplash.com/photo-1584169417032-d34e8d805e8b$_q';
  static const cableNet =
      'https://images.unsplash.com/photo-1558494949-ef010cbdcc31$_q';
  static const pcb =
      'https://images.unsplash.com/photo-1592919347498-69564e361791$_q';
  static const laptop =
      'https://images.unsplash.com/photo-1722316805351-d5a56965f926$_q';
  static const pos =
      'https://images.unsplash.com/photo-1742836531271-98fd8151d257$_q';
  static const space =
      'https://images.unsplash.com/photo-1451187580459-43490279c0fa$_q';
}

const countries = <Country>[
  Country(
    code: 'BF',
    name: 'Burkina Faso',
    flag: '🇧🇫',
    currency: 'XOF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+226',
  ),
  Country(
    code: 'CI',
    name: "Côte d'Ivoire",
    flag: '🇨🇮',
    currency: 'XOF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+225',
  ),
  Country(
    code: 'ML',
    name: 'Mali',
    flag: '🇲🇱',
    currency: 'XOF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+223',
  ),
  Country(
    code: 'SN',
    name: 'Sénégal',
    flag: '🇸🇳',
    currency: 'XOF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+221',
  ),
  Country(
    code: 'NE',
    name: 'Niger',
    flag: '🇳🇪',
    currency: 'XOF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+227',
  ),
  Country(
    code: 'TG',
    name: 'Togo',
    flag: '🇹🇬',
    currency: 'XOF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+228',
  ),
  Country(
    code: 'BJ',
    name: 'Bénin',
    flag: '🇧🇯',
    currency: 'XOF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+229',
  ),
  Country(
    code: 'CM',
    name: 'Cameroun',
    flag: '🇨🇲',
    currency: 'XAF',
    symbol: 'FCFA',
    ratePerXof: 1,
    phonePrefix: '+237',
  ),
  Country(
    code: 'GH',
    name: 'Ghana',
    flag: '🇬🇭',
    currency: 'GHS',
    symbol: 'GH₵',
    ratePerXof: 0.025,
    phonePrefix: '+233',
  ),
  Country(
    code: 'NG',
    name: 'Nigeria',
    flag: '🇳🇬',
    currency: 'NGN',
    symbol: '₦',
    ratePerXof: 2.6,
    phonePrefix: '+234',
  ),
];

Country countryByCode(String code) =>
    countries.firstWhere((c) => c.code == code, orElse: () => countries.first);

const categories = <Category>[
  Category('routers', 'Routeurs & Hotspot', Icons.router_outlined),
  Category('ap', 'Antennes & AP', Icons.settings_input_antenna),
  Category('ptp', 'Point-à-point', Icons.compare_arrows),
  Category('switch', 'Switch & PoE', Icons.device_hub),
  Category('cables', 'Câbles & Connectique', Icons.cable),
  Category('power', 'Énergie & Solaire', Icons.solar_power_outlined),
  Category('sat', 'Starlink & Satellite', Icons.satellite_alt_outlined),
  Category('vouchers', 'Tickets & Gestion', Icons.confirmation_number_outlined),
];

Category categoryById(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.first);

List<Shop> demoShops() => [
  Shop(
    id: 's1',
    name: 'OMZAKREVO Informatique',
    owner: 'Zachari S.',
    phone: '+226 70 00 00 01',
    city: 'Ouagadougou',
    countryCode: 'BF',
    description: 'Réseaux, hotspots MikroTik, point-à-point et Starlink. Toujours une solution !',
    logoUrl: Img.router,
    status: ShopStatus.active,
    plan: Plan.business,
    verified: true,
  ),
  Shop(
    id: 's2',
    name: 'NetZone Bobo',
    owner: 'Awa T.',
    phone: '+226 76 00 00 02',
    city: 'Bobo-Dioulasso',
    countryCode: 'BF',
    description: 'Antennes, câbles et installation WiFi zone.',
    logoUrl: Img.tower,
    status: ShopStatus.active,
    plan: Plan.pro,
  ),
  Shop(
    id: 's3',
    name: 'Abidjan Wireless',
    owner: 'Koffi A.',
    phone: '+225 07 00 00 03',
    city: 'Abidjan',
    countryCode: 'CI',
    description: 'Distributeur Ubiquiti & TP-Link.',
    logoUrl: Img.switchPoe,
    status: ShopStatus.active,
    plan: Plan.pro,
    verified: true,
  ),
  Shop(
    id: 's4',
    name: 'Dakar Connect',
    owner: 'Moussa D.',
    phone: '+221 77 000 00 04',
    city: 'Dakar',
    countryCode: 'SN',
    description: 'Starlink, solaire et hotspots.',
    logoUrl: Img.dish,
    status: ShopStatus.active,
    plan: Plan.starter,
  ),
  Shop(
    id: 's5',
    name: 'Sahel Réseaux',
    owner: 'Issa K.',
    phone: '+223 70 00 00 05',
    city: 'Bamako',
    countryCode: 'ML',
    description: 'Demande en cours de validation.',
    logoUrl: Img.tower2,
    status: ShopStatus.pending,
    plan: Plan.pro,
  ),
  Shop(
    id: 's6',
    name: 'Lomé WiFi Pro',
    owner: 'Edem K.',
    phone: '+228 90 00 00 06',
    city: 'Lomé',
    countryCode: 'TG',
    description: 'Nouvelle boutique — documents envoyés.',
    logoUrl: Img.cableNet,
    status: ShopStatus.pending,
  ),
];

List<Product> demoProducts() {
  var n = 0;
  Product p(
    String shop,
    String cat,
    String name,
    String brand,
    int price,
    String img, {
    int? old,
    String? badge,
    double rating = 4.6,
    int reviews = 120,
    int stock = 12,
    List<String>? specs,
    String? desc,
  }) => Product(
    id: 'p${++n}',
    shopId: shop,
    categoryId: cat,
    name: name,
    brand: brand,
    priceXof: price,
    oldPriceXof: old,
    imageUrl: img,
    badge: badge,
    rating: rating,
    reviews: reviews,
    stock: stock,
    specs: specs ?? const [],
    description:
        desc ??
        '$name de $brand, idéal pour monter ou étendre une WiFi zone : fiable, facile à configurer et adapté au climat sahélien.',
  );

  final base = <Product>[
    p(
      's1',
      'routers',
      'MikroTik hAP ac² — Routeur Hotspot',
      'MikroTik',
      45000,
      Img.router,
      old: 52000,
      badge: 'MEILLEURE VENTE',
      rating: 4.8,
      reviews: 1240,
      specs: [
        'Double bande 2,4/5 GHz',
        '5 ports Gigabit',
        'Hotspot & User Manager intégrés',
        'RouterOS licence L4',
      ],
    ),
    p(
      's1',
      'routers',
      'MikroTik RB951Ui-2HnD',
      'MikroTik',
      32000,
      Img.device,
      badge: 'POPULAIRE',
      rating: 4.7,
      reviews: 860,
      specs: ['2,4 GHz 1 W', '5 ports + PoE out', 'Idéal petites zones'],
    ),
    p(
      's3',
      'ap',
      'Ubiquiti NanoStation M5',
      'Ubiquiti',
      58000,
      Img.tower,
      badge: 'TENDANCE',
      rating: 4.7,
      reviews: 968,
      specs: ['5 GHz airMAX', '16 dBi', 'Portée 15 km+', 'PoE 24 V'],
    ),
    p(
      's2',
      'ap',
      'TP-Link CPE510 Outdoor',
      'TP-Link',
      36000,
      Img.tower2,
      rating: 4.5,
      reviews: 410,
      specs: ['5 GHz 300 Mb/s', '13 dBi', 'IP65'],
    ),
    p(
      's3',
      'ptp',
      'Ubiquiti LiteBeam 5AC Gen2',
      'Ubiquiti',
      62000,
      Img.tower3,
      old: 70000,
      rating: 4.8,
      reviews: 530,
      specs: ['airMAX AC', '23 dBi', 'Liaison jusqu\'à 20 km'],
    ),
    p(
      's1',
      'ptp',
      'Kit liaison point-à-point 10 km',
      'Mimosa',
      185000,
      Img.tower,
      badge: 'PRO',
      rating: 4.9,
      reviews: 88,
      specs: ['2 radios + supports', 'Débit 450 Mb/s', 'Installation possible'],
    ),
    p(
      's3',
      'switch',
      'Switch PoE 8 ports Gigabit',
      'TP-Link',
      48000,
      Img.switchPoe,
      badge: 'TENDANCE',
      rating: 4.6,
      reviews: 743,
      specs: ['8 ports PoE+ 802.3at', 'Budget 120 W', 'Plug & play'],
    ),
    p(
      's2',
      'switch',
      'Injecteur PoE passif 24 V',
      'Ubiquiti',
      6500,
      Img.pcb,
      rating: 4.4,
      reviews: 312,
      specs: ['24 V 0,5 A', 'Gigabit'],
    ),
    p(
      's2',
      'cables',
      'Câble FTP Cat6 extérieur 305 m',
      'Legrand',
      95000,
      Img.cableRoll,
      rating: 4.7,
      reviews: 205,
      specs: ['Blindé, anti-UV', 'Cuivre pur', 'Bobine 305 m'],
    ),
    p(
      's1',
      'cables',
      'Lot 100 connecteurs RJ45 blindés',
      'Generic',
      7500,
      Img.utp,
      rating: 4.3,
      reviews: 518,
      specs: ['Cat6 FTP', 'Passe-câble'],
    ),
    p(
      's4',
      'power',
      'Kit solaire 300 W + batterie WiFi zone',
      'Victron',
      245000,
      Img.space,
      badge: 'NOUVEAU',
      rating: 4.8,
      reviews: 64,
      specs: [
        'Panneau 300 W',
        'Batterie lithium 100 Ah',
        'Autonomie 24 h routeur + AP',
      ],
    ),
    p(
      's1',
      'power',
      'Onduleur 1 kVA line-interactive',
      'APC',
      68000,
      Img.serverRack,
      rating: 4.5,
      reviews: 190,
    ),
    p(
      's4',
      'sat',
      'Starlink Kit Standard',
      'Starlink',
      350000,
      Img.dish,
      badge: 'MEILLEURE VENTE',
      rating: 4.9,
      reviews: 1500,
      specs: ['Antenne + routeur WiFi 6', 'Câble 15 m', 'Activation assistée'],
    ),
    p(
      's1',
      'sat',
      'Support mât Starlink galvanisé',
      'Generic',
      25000,
      Img.tower2,
      rating: 4.4,
      reviews: 98,
    ),
    p(
      's1',
      'vouchers',
      'Imprimante tickets thermique 58 mm',
      'Xprinter',
      28000,
      Img.pos,
      rating: 4.5,
      reviews: 233,
      specs: ['USB + Bluetooth', 'Compatible tickets MikroTik'],
    ),
    p(
      's1',
      'vouchers',
      'Licence gestion hotspot (1 an)',
      'ZoneHub',
      20000,
      Img.laptop,
      badge: 'SaaS',
      rating: 4.7,
      reviews: 140,
      specs: [
        'Génération de tickets',
        'Paiement Mobile Money',
        'Multi-routeurs',
      ],
    ),
  ];
  return base;
}

List<Listing> demoListings() {
  final now = DateTime.now();
  return [
    Listing(
      id: 'l1',
      sellerName: 'Ibrahim O.',
      sellerPhone: '+226 65 11 22 33',
      countryCode: 'BF',
      city: 'Ouagadougou',
      categoryId: 'routers',
      title: 'MikroTik hAP lite — 6 mois',
      description: 'Fonctionne parfaitement, vendu avec alimentation. Cause : passage à la fibre.',
      priceXof: 15000,
      condition: ListingCondition.good,
      status: ListingStatus.published,
      imageUrl: Img.modem,
      createdAt: now.subtract(const Duration(hours: 5)),
      views: 54,
    ),
    Listing(
      id: 'l2',
      sellerName: 'Fatou B.',
      sellerPhone: '+226 74 55 66 77',
      countryCode: 'BF',
      city: 'Koudougou',
      categoryId: 'ap',
      title: '3 antennes NanoStation M2',
      description: 'Lot de 3 antennes démontées, testées, sans PoE.',
      priceXof: 60000,
      condition: ListingCondition.fair,
      status: ListingStatus.published,
      imageUrl: Img.tower3,
      createdAt: now.subtract(const Duration(days: 1)),
      views: 120,
    ),
    Listing(
      id: 'l3',
      sellerName: 'Yao K.',
      sellerPhone: '+225 05 44 33 22',
      countryCode: 'CI',
      city: 'Yamoussoukro',
      categoryId: 'sat',
      title: 'Starlink Standard comme neuf',
      description: 'Utilisé 2 mois, boîte d\'origine. Facture disponible.',
      priceXof: 260000,
      condition: ListingCondition.likeNew,
      status: ListingStatus.published,
      imageUrl: Img.dish,
      createdAt: now.subtract(const Duration(days: 2)),
      views: 310,
    ),
    Listing(
      id: 'l4',
      sellerName: 'Cheikh N.',
      sellerPhone: '+221 76 123 45 67',
      countryCode: 'SN',
      city: 'Thiès',
      categoryId: 'switch',
      title: 'Switch 16 ports non PoE',
      description: 'Bon état, quelques rayures.',
      priceXof: 18000,
      condition: ListingCondition.good,
      status: ListingStatus.published,
      imageUrl: Img.switchPoe,
      createdAt: now.subtract(const Duration(days: 3)),
      views: 42,
    ),
    Listing(
      id: 'l5',
      sellerName: 'Adama S.',
      sellerPhone: '+226 70 98 76 54',
      countryCode: 'BF',
      city: 'Ouagadougou',
      categoryId: 'cables',
      title: 'Reste de câble Cat6 ~120 m',
      description: 'Câble extérieur, à récupérer sur place.',
      priceXof: 25000,
      condition: ListingCondition.good,
      status: ListingStatus.pending,
      imageUrl: Img.blueWires,
      createdAt: now.subtract(const Duration(minutes: 40)),
    ),
    Listing(
      id: 'l6',
      sellerName: 'Moussa T.',
      sellerPhone: '+223 66 00 11 22',
      countryCode: 'ML',
      city: 'Bamako',
      categoryId: 'power',
      title: 'Batterie 100 Ah pour pièces',
      description: 'Ne tient plus la charge, cellules récupérables.',
      priceXof: 8000,
      condition: ListingCondition.forParts,
      status: ListingStatus.published,
      imageUrl: Img.serverRoom,
      createdAt: now.subtract(const Duration(days: 4)),
      views: 18,
    ),
  ];
}

class PromoBanner {
  final String tag;
  final String title;
  final String highlight;
  final String text;
  final String cta;
  final String image;
  const PromoBanner(
    this.tag,
    this.title,
    this.highlight,
    this.text,
    this.cta,
    this.image,
  );
}

const banners = [
  PromoBanner(
    'NOUVEAUTÉS',
    'WIFI ZONE.',
    'PLUS LOIN, PLUS FORT.',
    'Routeurs hotspot, antennes et kits point-à-point pour lancer votre zone.',
    'ACHETER',
    Img.tower,
  ),
  PromoBanner(
    'STARLINK',
    'CONNECTEZ',
    'MÊME EN BROUSSE.',
    'Kits Starlink, supports et énergie solaire livrés dans votre ville.',
    'DÉCOUVRIR',
    Img.dish,
  ),
  PromoBanner(
    'OCCASION',
    'VENDEZ VOTRE',
    'MATÉRIEL USAGÉ.',
    'Publiez une annonce gratuite en 1 minute et touchez tout votre pays.',
    'PUBLIER',
    Img.cableNet,
  ),
];
