import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Choix du pays : crée (ou retrouve) le compte visiteur de ce pays.
class CountryScreen extends StatelessWidget {
  final bool firstRun;
  const CountryScreen({super.key, this.firstRun = false});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: firstRun ? AppColors.navy : AppColors.bg,
      appBar: firstRun ? null : AppBar(title: const Text('Changer de pays')),
      body: SafeArea(
        child: MaxWidth(
          max: 560,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (firstRun) ...[
                const SizedBox(height: 20),
                const BrandLogo(light: true),
                const SizedBox(height: 28),
                const Text(
                  'Bienvenue 👋',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choisissez votre pays. Un compte visiteur est créé pour ce pays : '
                  'vous voyez les boutiques, les prix et les annonces d\'occasion locales.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 24),
              ],
              for (final c in countries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: firstRun ? AppColors.navy2 : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: Text(
                        c.flag,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        c.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: firstRun ? Colors.white : AppColors.text,
                        ),
                      ),
                      subtitle: Text(
                        '${c.currency} • ${c.phonePrefix}'
                        '${app.visitorAccounts.containsKey(c.code) ? ' • compte existant' : ''}',
                        style: TextStyle(
                          color: firstRun ? Colors.white60 : AppColors.muted,
                        ),
                      ),
                      trailing: app.user?.countryCode == c.code
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primaryLight,
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: firstRun
                                  ? Colors.white54
                                  : AppColors.muted,
                            ),
                      onTap: () {
                        app.chooseCountry(c.code);
                        if (!firstRun) Navigator.pop(context);
                      },
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
