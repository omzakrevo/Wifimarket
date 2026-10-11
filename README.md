# WiFiMarket

Marketplace ouverte et multivendeurs du matériel Wi-Fi, radio, Starlink et réseau en Afrique de l'Ouest (neuf, occasion, reconditionné, pièces, échanges, demandes, boutiques, commandes).
Domaine : https://wifimarket.tech · Français / English · PWA installable.

**Stack** : Next.js 16 (App Router, TypeScript) · React 19 · Tailwind CSS 4 · Supabase (PostgreSQL + RLS, Auth, Storage, Realtime) · Netlify.

## Démarrage rapide

```bash
npm install
cp .env.example .env.local        # renseigner NEXT_PUBLIC_SUPABASE_URL et NEXT_PUBLIC_SUPABASE_ANON_KEY
npm run dev                       # http://localhost:3000
```

Sans variables Supabase, le site s'affiche avec un bandeau « Configuration requise » (aucun crash).

### Base de données Supabase

1. Créer (ou choisir) un projet Supabase.
2. Appliquer **dans l'ordre** les fichiers de `supabase/migrations/` (SQL Editor, ou `supabase db push` avec la CLI) :
   `0001_schema` → `0002_logic` → `0003_rls` → `0004_storage` → `0005_reference_data` → `0006_search` → `0007_realtime` → `0008_verification` → `0009_gdpr`.
3. *(Développement / démo uniquement)* `supabase/seed_demo.sql` : 8 vendeurs, 3 boutiques, 30 annonces, demandes, conversations, commandes de test (e-mails `*@demo.wifimarket.test`, mot de passe `Demo!2345`, données marquées `is_demo`). **Ne jamais l'exécuter en production.**
4. Auth → URL Configuration : *Site URL* = `https://wifimarket.tech`, *Redirect URLs* = `https://wifimarket.tech/auth/callback`, `http://localhost:3000/auth/callback`.
5. Créer le premier superadministrateur (après inscription via le site) :
   ```sql
   insert into public.user_roles (user_id, role)
   select id, 'superadmin' from auth.users where email = 'vous@exemple.com';
   ```
6. Annonces expirées : planifier `select public.expire_listings();` (pg_cron ou fonction planifiée) — par exemple chaque heure.
7. Connexions optionnelles : Google (Auth → Providers) puis `NEXT_PUBLIC_AUTH_GOOGLE_ENABLED=true` ; téléphone/OTP (fournisseur SMS requis) puis `NEXT_PUBLIC_AUTH_PHONE_ENABLED=true`.

## Tests

| Commande | Contenu |
|---|---|
| `npm run test:sql` | PostgreSQL jetable : applique migrations + démo, 100+ vérifications RLS / logique métier / recherche / RGPD |
| `npm test` | Tests unitaires (formats, i18n, anti open-redirect, signature de webhook Paystack) |
| `npm run build && npm run test:e2e` | Playwright mobile + desktop : pages publiques, responsive, PWA, SEO, en-têtes, redirections |
| `E2E_SUPABASE=1 npm run test:e2e` | Parcours complets (inscription, recherche, favoris, messagerie, publication, commande, admin) sur un vrai projet Supabase avec la démo |
| `npm run typecheck` · `npm run lint` · `npm run check:i18n` | Types, ESLint, clés de traduction |

## Architecture

- `supabase/migrations` — schéma (35+ tables), RLS, fonctions métier SECURITY DEFINER (modération, commandes, négociations…), Storage, recherche plein texte.
- `src/app` — pages (App Router) et `actions/` (Server Actions validées par Zod ; droits **toujours** contrôlés par la RLS / fonctions SQL).
- `src/app/api/payments/paystack` — initialisation et webhook authentifié (signature HMAC + revérification API + idempotence).
- `src/lib/i18n` + `scripts/messages.src.txt` — traductions FR/EN (`npm run build:messages` régénère `messages.ts`).
- `public/sw.js` — service worker (cache statique, page hors connexion ; jamais de cache des pages connectées).

### Principes de sécurité
- Clé `service_role` jamais exposée au navigateur (`server-only`, variable sans préfixe `NEXT_PUBLIC`).
- RLS activée sur toutes les tables ; données privées (`private_profiles`), commandes, paiements et messages limités à leurs participants.
- WhatsApp : numéro jamais lisible directement, exposé seulement via `get_whatsapp()` si le vendeur a consenti.
- Prix stockés avec leur devise d'origine, **aucune conversion automatique** ; frais de livraison issus uniquement de règles configurées (`shipping_rules`).
- Photos ré-encodées côté navigateur (EXIF/géolocalisation supprimés) ; buckets avec limites de taille et types MIME.
- Modération : mots interdits, file de revue, signalements, limites anti-spam, journal d'audit des actions sensibles.

## Paiements
Aucun paiement réel n'est simulé. Au départ, seul « paiement convenu entre les parties » (hors plateforme) est actif.
Paystack est intégré (initialisation + webhook vérifié) mais **inactif** tant qu'un administrateur n'a pas, dans *Admin → Paramètres → Prestataires*, activé le prestataire **et** confirmé pays/devises/moyens avec Paystack, et que `PAYSTACK_SECRET_KEY` (clé `sk_test_…` = sandbox) est définie. CinetPay : table et interface prêtes, adaptateur serveur **non écrit** (à faire dès réception de la documentation/identifiants marchands). Les versements aux vendeurs et la conservation des fonds dépendent des capacités contractuelles du prestataire : non implémentés.

## Déploiement
Voir [docs/DEPLOIEMENT.md](docs/DEPLOIEMENT.md) (GitHub → Netlify → domaine wifimarket.tech chez LWS, HTTPS, redirections).
