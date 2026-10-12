/// Configuration publique. Les valeurs par défaut pointent vers le Supabase auto-hébergé de WiFiMarket
/// (clé PUBLIQUE uniquement : la sécurité repose sur la RLS). Surchargeable :
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  AppConfig._();
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://vps-ef39f3a3.vps.ovh.ca');
  static const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_lO14OQV6MGKj4tMHeKRJU__kTETCwWJ');
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://wifimarket.tech');
  static const googleAuth = bool.fromEnvironment('AUTH_GOOGLE', defaultValue: false);
  static const phoneAuth = bool.fromEnvironment('AUTH_PHONE', defaultValue: false);
}
