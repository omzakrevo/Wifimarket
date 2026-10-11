#!/usr/bin/env bash
# Compile la version web (statique) dans build/web — sans dépendance à un CDN (CanvasKit et polices embarqués).
# Variables optionnelles : SUPABASE_URL, SUPABASE_ANON_KEY (clé PUBLIQUE uniquement), SITE_URL.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/build_strings.py
args=(--release --no-web-resources-cdn)
[ -n "${SUPABASE_URL:-}" ] && args+=("--dart-define=SUPABASE_URL=$SUPABASE_URL")
[ -n "${SUPABASE_ANON_KEY:-}" ] && args+=("--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY")
[ -n "${SITE_URL:-}" ] && args+=("--dart-define=SITE_URL=$SITE_URL")
flutter build web "${args[@]}"
echo "OK → build/web (à téléverser tel quel sur l'hébergement statique)"
