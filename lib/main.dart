import 'package:flutter/material.dart';

import 'screens/country_screen.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() => runApp(ZoneHubApp(state: AppState()));

class ZoneHubApp extends StatelessWidget {
  final AppState state;
  const ZoneHubApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'ZoneHub — Matériel WiFi zone',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return app.onboarded ? const Shell() : const CountryScreen(firstRun: true);
  }
}
