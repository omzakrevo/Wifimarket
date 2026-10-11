import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/i18n.dart';
import 'core/theme/theme.dart';
import 'data/providers.dart';
import 'router.dart';

class WifiMarketApp extends ConsumerStatefulWidget {
  const WifiMarketApp({super.key});
  @override
  ConsumerState<WifiMarketApp> createState() => _State();
}

class _State extends ConsumerState<WifiMarketApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(langProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final dark = ref.watch(themeProvider);
    final router = ref.watch(routerProvider);
    return I18nScope(
      lang: lang,
      child: MaterialApp.router(
        title: 'WiFiMarket',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: dark == null ? ThemeMode.system : (dark ? ThemeMode.dark : ThemeMode.light),
        routerConfig: router,
        locale: Locale(lang),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('fr'), Locale('en')],
      ),
    );
  }
}
