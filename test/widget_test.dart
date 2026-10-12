import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wifimarket/features/admin/demo_sql.dart';
import 'package:wifimarket/core/i18n/i18n.dart';
import 'package:wifimarket/core/utils/format.dart';
import 'package:wifimarket/data/models.dart';
import 'package:wifimarket/features/auth/auth_screen.dart';

void main() {
  group('i18n', () {
    test('traduit FR/EN et retombe sur err.generic', () {
      expect(translate('fr', 'nav.home'), 'Accueil');
      expect(translate('en', 'nav.home'), 'Home');
      expect(translate('fr', 'err.inconnue'), translate('fr', 'err.generic'));
      expect(translate('fr', 'search.count', {'n': 3}), contains('3'));
    });
  });

  group('données de test', () {
    test('le SQL copiable est identique à la migration 0011', () {
      expect(kDemoPurgeSql, File('supabase/migrations/0011_purge_demo.sql').readAsStringSync());
    });
  });

  group('téléphone', () {
    test('normalizePhone met le numéro au format international', () {
      expect(normalizePhone('+226 70 00 00 00'), '+22670000000');
      expect(normalizePhone('0022670-00-00-00'), '+22670000000');
      expect(normalizePhone('(+226)70.00.00.00'), '+22670000000');
    });
  });

  group('format', () {
    test('prix dans la devise d\'origine, sans conversion', () {
      expect(formatPrice(15000, 'XOF', 'fr'), contains('FCFA'));
      expect(formatPrice(15000, 'XOF', 'fr'), contains('15'));
      expect(formatPrice(10.5, 'EUR', 'en'), contains('EUR'));
    });
    test('parseNum tolère virgule et espaces', () {
      expect(parseNum('1 500,5'), 1500.5);
      expect(parseNum(''), isNull);
      expect(parseNum('abc'), isNull);
    });
    test('sanitizeSearch retire les caractères de filtre', () {
      expect(sanitizeSearch('a,b(c)%*"x'), 'a b c x');
    });
  });

  group('SearchParams', () {
    test('compte les filtres actifs et copyWith peut effacer', () {
      const p = SearchParams(q: 'x', category: 'routeurs', min: 10, inStock: true);
      expect(p.activeFilters, 3);
      final c = p.copyWith(category: null);
      expect(c.category, isNull);
      expect(c.min, 10);
      expect(p == p.copyWith(), isTrue);
    });
    test('arguments RPC', () {
      final a = const SearchParams(q: ' wifi ', country: 'BF').baseArgs();
      expect(a['p_q'], 'wifi');
      expect(a['p_country'], 'BF');
      expect(a['p_in_stock'], false);
    });
  });

  group('Listing.fromJson', () {
    test('lit les médias, la catégorie et le vendeur', () {
      final l = Listing.fromJson({
        'id': 'a', 'seller_id': 's', 'category_id': 1, 'title': 'LiteBeam', 'slug': 'l', 'description': 'd', 'condition': 'new',
        'price': 25000, 'currency_code': 'XOF', 'quantity': 2, 'country_code': 'BF', 'status': 'active', 'created_at': '2026-01-01T00:00:00Z',
        'listing_media': [
          {'storage_path': 'u/2.jpg', 'kind': 'image', 'position': 1},
          {'storage_path': 'u/1.jpg', 'kind': 'image', 'position': 0},
        ],
        'categories': {'slug': 'antennes', 'name_fr': 'Antennes', 'name_en': 'Antennas', 'icon': 'radio'},
        'profiles': {'id': 's', 'display_name': 'Awa'},
      });
      expect(l.images.first.path, 'u/1.jpg');
      expect(l.cover, endsWith('u/1.jpg'));
      expect(l.categoryName('en'), 'Antennas');
      expect(l.seller?.displayName, 'Awa');
    });
  });
}
