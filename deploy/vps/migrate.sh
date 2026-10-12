#!/usr/bin/env bash
# WiFiMarket — applique sur le serveur uniquement les migrations SQL pas encore appliquées.
#
# Lecture : une archive tar de supabase/migrations/ arrive sur l'entrée standard (envoyée par GitHub Actions) :
#     tar c -C supabase migrations | ssh deploy@serveur
# Suivi : table wm_deploy.schema_migrations (schéma non exposé par l'API). Chaque migration s'applique dans UNE transaction,
# avec l'inscription de son nom : si elle échoue, rien n'est modifié et le déploiement s'arrête.
# Premier lancement sur une base déjà installée à la main : les migrations existantes sont enregistrées comme appliquées.
set -euo pipefail

# Commande psql (surchargeable pour les tests) : par défaut, dans le conteneur Supabase.
PSQL_CMD="${PSQL_CMD:-docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q}"
read -r -a PSQL <<<"$PSQL_CMD"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
tar -x -C "$tmp"
dir="$tmp/migrations"
[ -d "$dir" ] || { echo "ERREUR : l'archive ne contient pas de dossier migrations/" >&2; exit 1; }

"${PSQL[@]}" -c "create schema if not exists wm_deploy; create table if not exists wm_deploy.schema_migrations (name text primary key, applied_at timestamptz not null default now()); revoke all on schema wm_deploy from public, anon, authenticated;"

count="$("${PSQL[@]}" -tA -c "select count(*) from wm_deploy.schema_migrations")"
if [ "$count" = "0" ]; then
  installed="$("${PSQL[@]}" -tA -c "select to_regclass('public.currencies') is not null")"
  if [ "$installed" = "t" ]; then
    echo "Base déjà installée : enregistrement des migrations existantes comme appliquées."
    for f in "$dir"/*.sql; do
      n="$(basename "$f")"
      "${PSQL[@]}" -c "insert into wm_deploy.schema_migrations(name) values ('$n') on conflict do nothing"
    done
  fi
fi

applied=0
for f in "$dir"/*.sql; do
  n="$(basename "$f")"
  done_already="$("${PSQL[@]}" -tA -c "select exists (select 1 from wm_deploy.schema_migrations where name = '$n')")"
  if [ "$done_already" = "t" ]; then continue; fi
  echo "-> application de $n"
  { cat "$f"; printf "\ninsert into wm_deploy.schema_migrations(name) values ('%s');\n" "$n"; } | "${PSQL[@]}" -1
  applied=$((applied + 1))
done
echo "Terminé : $applied migration(s) appliquée(s)."
