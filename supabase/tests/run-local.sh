#!/usr/bin/env bash
# Lance un Postgres jetable, applique les migrations + les données de démo et exécute les tests SQL (RLS, logique métier).
# Usage : supabase/tests/run-local.sh   (nécessite les binaires PostgreSQL 14+)
set -euo pipefail
cd "$(dirname "$0")/.."
PGBIN=${PGBIN:-$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1)}
DIR=$(mktemp -d); PORT=${PGPORT:-54329}
RUN="su postgres -c"
trap '$RUN "$PGBIN/pg_ctl -D $DIR/data stop -m immediate" >/dev/null 2>&1 || true; rm -rf "$DIR"' EXIT
chmod 777 "$DIR"
$RUN "$PGBIN/initdb -D $DIR/data -A trust -U postgres >/dev/null"
$RUN "$PGBIN/pg_ctl -D $DIR/data -o '-p $PORT -k /tmp' -l $DIR/log -w start >/dev/null"
PSQL="psql -h /tmp -p $PORT -U postgres -v ON_ERROR_STOP=1 -q"
$PSQL -c "create database wm" postgres
export PGDATABASE=wm
PSQL="$PSQL -d wm"
$PSQL -f tests/00_stub_supabase.sql
for f in migrations/*.sql; do echo "-- $f"; $PSQL -f "$f"; done
$PSQL -f seed_demo.sql
for f in tests/[1-9]*.sql; do echo "== $f"; $PSQL -f "$f" >/dev/null; done
echo "TOUS LES TESTS SQL SONT PASSÉS"
