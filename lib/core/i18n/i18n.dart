import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.g.dart';

/// Traduit une clé ; une clé d'erreur inconnue retombe sur `err.generic`.
String translate(String lang, String key, [Map<String, Object?>? vars]) {
  final entry = kStrings[key] ?? (key.startsWith('err.') ? kStrings['err.generic'] : null);
  var s = entry == null ? key : (lang == 'en' ? entry[1] : entry[0]);
  if (vars != null) {
    vars.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  }
  return s;
}

/// Langue courante (fr / en), mémorisée sur l'appareil.
class LangNotifier extends Notifier<String> {
  static const _key = 'wm_lang';
  @override
  String build() => 'fr';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_key);
    if (saved == 'fr' || saved == 'en') state = saved!;
  }

  Future<void> set(String lang) async {
    state = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, lang);
  }

  Future<void> toggle() => set(state == 'fr' ? 'en' : 'fr');
}

final langProvider = NotifierProvider<LangNotifier, String>(LangNotifier.new);

/// Diffuse la langue dans l'arbre de widgets : `context.t('clé')` reconstruit l'UI au changement.
class I18nScope extends InheritedWidget {
  const I18nScope({super.key, required this.lang, required super.child});
  final String lang;

  static String langOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<I18nScope>()?.lang ?? 'fr';

  @override
  bool updateShouldNotify(I18nScope old) => old.lang != lang;
}

extension I18nContext on BuildContext {
  String get lang => I18nScope.langOf(this);
  String t(String key, [Map<String, Object?>? vars]) => translate(lang, key, vars);
}
