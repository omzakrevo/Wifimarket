# WiFiMarket — application Flutter (web + Android + iOS)

Marketplace du matériel Wi-Fi et réseau en Afrique de l'Ouest (FR/EN). Une seule base de code Flutter produit
le **site web** (statique) et les **applications mobiles**. Le backend est le projet Supabase **wifimarket**
(Postgres + RLS, Auth, Storage, Realtime).

> L'ancienne version Next.js est conservée sur la branche `legacy-nextjs`.

## Fonctionnalités

Comptes (e-mail / mot de passe, Google et SMS activables) · accueil animé · recherche avancée (RPC `search_listings`,
filtres, tri, alertes de recherche) · fiches annonces (galerie, zoom, partage, WhatsApp avec consentement) ·
publication / édition avec photos (caméra ou galerie) et vidéo · favoris · messagerie temps réel (images, accusés de lecture,
blocage, signalement) · demandes de matériel + offres · négociations et échanges · boutiques et profils vendeurs ·
panier, commande (retrait / local / inter-villes / international — **frais issus uniquement des règles configurées**) ·
suivi de commande, litiges, avis · notifications · administration complète (modération, utilisateurs, boutiques,
commandes, litiges, promotions, catalogue, pays, réglages, plans, livraison, prestataires, mots interdits, audit, suppressions RGPD) ·
mode sombre · FR/EN · design « Signal » avec motion design (cascades d'apparition, rebond tactile, anneaux Wi-Fi animés, cœur animé, compteurs, transitions de pages).

Paiements en ligne : **désactivés** (aucun prestataire n'est activé ; seul « paiement convenu entre les parties » est actif).

## Démarrer

```bash
flutter pub get
flutter run -d chrome            # web
flutter run                      # appareil / émulateur Android ou iOS
flutter test                     # tests unitaires
flutter analyze
```

Configuration (valeurs par défaut = projet Supabase `wifimarket`, clé **publique** uniquement) :

```bash
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=sb_publishable_... \
            --dart-define=SITE_URL=https://wifimarket.tech \
            --dart-define=AUTH_GOOGLE=true --dart-define=AUTH_PHONE=true   # si activés dans Supabase Auth
```

La clé `service_role` ne doit **jamais** figurer dans l'application.

## Textes (i18n)

`tool/strings.src.txt` (clé | français | anglais) → `python3 tool/build_strings.py` → `lib/core/i18n/strings.g.dart`.
Utilisation : `context.t('clé')`.

## Base de données

`supabase/migrations/0001…0011` + `supabase/seed_demo.sql` (données de démonstration, à supprimer avant le lancement réel).
La migration `0009_gdpr.sql` (fonction `anonymize_user`) est à exécuter manuellement dans le SQL editor si elle n'est pas appliquée.
### Devenir administrateur

Créez votre compte sur le site, puis exécutez dans le SQL editor de Supabase (remplacez l'e-mail) :

```sql
insert into public.user_roles (user_id, role)
select id, 'superadmin' from auth.users where email = 'vous@exemple.com';
```

Le menu **Administration** apparaît alors dans l'application.

### Supprimer les données de test

La migration `0011_purge_demo.sql` ajoute le bouton **Administration → Données de test → Supprimer les données de test** (superadmin réel uniquement). Il supprime les comptes `@demo.wifimarket.test` et tout ce qui leur est lié (annonces, boutiques, demandes, conversations, commandes, tarif « DEMO »). Les données réelles ne sont pas touchées ; un compte de démonstration ne peut pas lancer la suppression.

Réglages Supabase Auth à faire : *Site URL* = votre domaine, *Redirect URLs* = `https://votre-domaine/**`.

## Compilation

| Cible | Commande |
|---|---|
| Web (statique) | `bash tool/build_web.sh` → `build/web` |
| Android | `flutter build apk --release` / `flutter build appbundle` |
| iOS | `flutter build ipa` (macOS + Xcode requis) |

Hébergement : voir [docs/DEPLOIEMENT.md](docs/DEPLOIEMENT.md) (Netlify, LWS / Apache, DNS).

## Structure

```
lib/
  core/      config, i18n, thème, utilitaires
  data/      modèles, repository Supabase, providers Riverpod
  widgets/   composants communs et animations
  features/  home, search, listing, auth, account, chat, wanted, nego, shops, orders, admin, info
  router.dart, app.dart, main.dart
supabase/    migrations SQL, données de démonstration, tests SQL
```
