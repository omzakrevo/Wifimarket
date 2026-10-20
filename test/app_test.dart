import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zonehub/data/models.dart';
import 'package:zonehub/main.dart';
import 'package:zonehub/screens/admin_screen.dart';
import 'package:zonehub/screens/seller_screen.dart';
import 'package:zonehub/state/app_state.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1366, 900)]) {
    testWidgets('parcours complet ${size.width}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final state = AppState();
      await tester.pumpWidget(ZoneHubApp(state: state));
      expect(find.text('Bienvenue 👋'), findsOneWidget);

      await tester.tap(find.text('Burkina Faso'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.user!.countryCode, 'BF');
      expect(find.text('Matériel tendance'), findsOneWidget);

      for (final tab in [
        'Catégories',
        'Boutiques',
        'Occasion',
        'Compte',
        'Accueil',
      ]) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 300));
      }

      state.switchRole(UserRole.seller);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.push(MaterialPageRoute(builder: (_) => const SellerScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Mon abonnement', skipOffstage: false), findsOneWidget);
      nav.pop();
      await tester.pump(const Duration(milliseconds: 500));

      state.switchRole(UserRole.admin);
      nav.push(MaterialPageRoute(builder: (_) => const AdminScreen()));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Revenu mensuel (MRR)', skipOffstage: false), findsOneWidget);
      await tester.tap(find.text('Boutiques', skipOffstage: false).last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      state.setShopStatus(state.shops.firstWhere((s) => s.status == ShopStatus.pending), ShopStatus.active);
      await tester.pump();
      nav.pop();
      await tester.pump(const Duration(milliseconds: 500));

      state.chooseCountry('NG');
      await tester.pump(const Duration(milliseconds: 300));
      expect(state.country.symbol, '₦');
      expect(state.visibleProducts, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    });
  }
}
