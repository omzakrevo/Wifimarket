import 'package:intl/intl.dart';

import '../config.dart';

const _noDecimals = {'XOF', 'GNF', 'CVE'};
const _symbols = {'XOF': 'FCFA', 'GNF': 'GNF', 'CVE': 'CVE'};

/// Affiche un prix dans sa devise d'origine (aucune conversion).
String formatPrice(num amount, String currency, String lang) {
  final f = NumberFormat.decimalPattern(lang == 'en' ? 'en_US' : 'fr_FR')
    ..minimumFractionDigits = 0
    ..maximumFractionDigits = _noDecimals.contains(currency) ? 0 : 2;
  final n = f.format(amount).replaceAll(' ', ' ').replaceAll(' ', ' ');
  return '$n ${_symbols[currency] ?? currency}';
}

String timeAgo(DateTime d, String lang) {
  final diff = DateTime.now().difference(d.toLocal());
  final fr = lang != 'en';
  String s(int n, String fu, String fp, String eu, String ep) => fr ? 'il y a $n ${n > 1 ? fp : fu}' : '$n ${n > 1 ? ep : eu} ago';
  if (diff.inSeconds < 60) return fr ? "à l'instant" : 'just now';
  if (diff.inMinutes < 60) return s(diff.inMinutes, 'min', 'min', 'minute', 'minutes');
  if (diff.inHours < 24) return s(diff.inHours, 'heure', 'heures', 'hour', 'hours');
  if (diff.inDays < 30) return s(diff.inDays, 'jour', 'jours', 'day', 'days');
  return DateFormat.yMMMd(fr ? 'fr_FR' : 'en_GB').format(d.toLocal());
}

String shortDate(DateTime d, String lang) => DateFormat.yMMMd(lang == 'en' ? 'en_GB' : 'fr_FR').format(d.toLocal());

String publicUrl(String bucket, String path) => '${AppConfig.supabaseUrl}/storage/v1/object/public/$bucket/$path';

const conditions = ['new', 'used', 'refurbished', 'broken', 'for_parts'];

/// Nettoie un terme de recherche destiné à un filtre PostgREST.
String sanitizeSearch(String q) => q.replaceAll(RegExp(r'''[(),%*\\"']'''), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

bool isUuid(String v) => RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false).hasMatch(v);

/// Valeur numérique tolérante (virgule décimale, espaces).
num? parseNum(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  return num.tryParse(v.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));
}
