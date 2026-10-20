import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'account_screen.dart';
import 'categories_screen.dart';
import 'home_screen.dart';
import 'listings_screen.dart';
import 'shops_screen.dart';

/// Barre de navigation inférieure (mobile) / rail latéral (web large),
/// avec le bouton « Boutiques » central mis en avant comme sur le design.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  void go(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    final pages = [
      HomeScreen(onNavigate: go),
      const CategoriesScreen(),
      const ShopsScreen(),
      const ListingsScreen(),
      const AccountScreen(),
    ];
    const items = [
      (Icons.home_outlined, Icons.home, 'Accueil'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'Catégories'),
      (Icons.storefront_outlined, Icons.storefront, 'Boutiques'),
      (Icons.sell_outlined, Icons.sell, 'Occasion'),
      (Icons.person_outline, Icons.person, 'Compte'),
    ];

    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              backgroundColor: Colors.white,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Icon(
                  Icons.wifi_tethering,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              destinations: [
                for (final it in items)
                  NavigationRailDestination(
                    icon: Icon(it.$1),
                    selectedIcon: Icon(it.$2),
                    label: Text(it.$3),
                  ),
              ],
            ),
            Expanded(
              child: IndexedStack(index: index, children: pages),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 74,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: i == 2
                      ? _CenterButton(
                          selected: index == 2,
                          onTap: () => go(2),
                          label: items[2].$3,
                        )
                      : InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => go(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                index == i ? items[i].$2 : items[i].$1,
                                color: index == i
                                    ? AppColors.primary
                                    : AppColors.text,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                items[i].$3,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: index == i
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: index == i
                                      ? AppColors.primary
                                      : AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String label;
  const _CenterButton({
    required this.selected,
    required this.onTap,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x551746E0),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront, color: Colors.white, size: 22),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
