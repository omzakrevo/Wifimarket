import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_screen.dart';
import 'country_screen.dart';
import 'home_screen.dart';
import 'seller_screen.dart';
import 'shops_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.user!;
    final roleLabel = switch (u.role) {
      UserRole.visitor => 'Visiteur',
      UserRole.seller => 'Vendeur',
      UserRole.admin => 'Administrateur',
    };
    final favs = app.products
        .where((p) => app.favorites.contains(p.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon compte'),
        automaticallyImplyLeading: false,
      ),
      body: MaxWidth(
        max: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.navy, AppColors.navy2],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      app.country.flag,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          '$roleLabel • ${app.country.name} • ${app.country.currency}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _tile(
              context,
              Icons.public,
              'Changer de pays',
              'Chaque pays a son propre compte visiteur',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CountryScreen()),
                );
              },
            ),
            if (app.visitorAccounts.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mes comptes visiteurs',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final a in app.visitorAccounts.values)
                              ActionChip(
                                avatar: Text(countryByCode(a.countryCode).flag),
                                label: Text(a.id),
                                onPressed: () =>
                                    app.chooseCountry(a.countryCode),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            _tile(
              context,
              Icons.favorite_border,
              'Mes favoris',
              '${favs.length} produit(s)',
              () {
                showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  builder: (_) => favs.isEmpty
                      ? const SizedBox(
                          height: 160,
                          child: Center(
                            child: Text('Aucun favori pour l\'instant'),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final p in favs)
                              ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: NetImage(
                                    p.imageUrl,
                                    width: 48,
                                    height: 48,
                                  ),
                                ),
                                title: Text(p.name),
                                subtitle: Text(app.country.format(p.priceXof)),
                                onTap: () {
                                  Navigator.pop(context);
                                  openProduct(context, p);
                                },
                              ),
                          ],
                        ),
                );
              },
            ),
            _tile(
              context,
              Icons.storefront_outlined,
              'Ouvrir ma boutique',
              'Vendez votre matériel WiFi zone (SaaS)',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OpenShopScreen()),
                );
              },
            ),
            if (u.role == UserRole.seller)
              _tile(
                context,
                Icons.dashboard_customize_outlined,
                'Espace vendeur',
                'Produits, abonnement, statistiques',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SellerScreen()),
                  );
                },
              ),
            if (u.role == UserRole.admin)
              _tile(
                context,
                Icons.admin_panel_settings_outlined,
                'Administration',
                'Boutiques, annonces, pays, revenus',
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                },
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mode démo — changer de rôle',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'En production, le rôle vient du compte (Supabase Auth). Ici vous pouvez tester les 3 espaces.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.visitor,
                          label: Text('Visiteur'),
                          icon: Icon(Icons.person_outline),
                        ),
                        ButtonSegment(
                          value: UserRole.seller,
                          label: Text('Vendeur'),
                          icon: Icon(Icons.storefront_outlined),
                        ),
                        ButtonSegment(
                          value: UserRole.admin,
                          label: Text('Admin'),
                          icon: Icon(Icons.shield_outlined),
                        ),
                      ],
                      selected: {u.role},
                      onSelectionChanged: (s) => app.switchRole(s.first),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8EEFF),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    ),
  );
}
