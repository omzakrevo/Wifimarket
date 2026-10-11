/// Configuration publique. Les valeurs par défaut pointent vers le projet Supabase « wifimarket »
/// (clé PUBLIQUE uniquement : la sécurité repose sur la RLS). Surchargeable :
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  AppConfig._();
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://gsukmkijatkmiopwwieg.supabase.co');
  static const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_yBIBPnUe4j966Xp-BV3NIQ_WprJ2t4l');
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://wifimarket.tech');
  static const googleAuth = bool.fromEnvironment('AUTH_GOOGLE', defaultValue: false);
  static const phoneAuth = bool.fromEnvironment('AUTH_PHONE', defaultValue: false);
}
