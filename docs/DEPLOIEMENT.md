# Déploiement : GitHub → Netlify → wifimarket.tech (DNS chez LWS)

> Ne modifiez **aucun** enregistrement DNS avant d'avoir noté la configuration actuelle (en particulier les MX si vous avez des e-mails sur ce domaine).

## 1. Code sur GitHub
Dépôt : `omzakrevo/Wifimarket`. La branche de travail de cette livraison est `ccr-665fff5f-w8zqvl` ; fusionnez-la dans `main` après relecture (pull request).

## 2. Site Netlify
1. Netlify → *Add new site → Import an existing project* → GitHub → `omzakrevo/Wifimarket`.
2. Build : `npm run build` (déjà dans `netlify.toml`), Node 22. Le runtime Next.js est détecté automatiquement.
3. *Site configuration → Environment variables* :
   - `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY` (clé publique uniquement)
   - `NEXT_PUBLIC_SITE_URL=https://wifimarket.tech`
   - `SUPABASE_SERVICE_ROLE_KEY` (serveur uniquement ; marquer comme secrète)
   - optionnels : `NEXT_PUBLIC_AUTH_GOOGLE_ENABLED`, `NEXT_PUBLIC_AUTH_PHONE_ENABLED`, `PAYSTACK_SECRET_KEY` (sandbox `sk_test_…` d'abord)
4. Déployer, tester l'URL `https://<nom>.netlify.app` (accueil, connexion, `/sitemap.xml`).

## 3. Domaine personnalisé
Netlify → *Domain management → Add a domain* → `wifimarket.tech`. Deux options :

**A. DNS conservés chez LWS (le plus simple, MX intacts)** — dans la zone DNS LWS :
- enregistrement `A` de `wifimarket.tech` (apex) → **l'adresse affichée par Netlify** pour votre site (Domain management → DNS configuration) ;
- enregistrement `CNAME` de `www` → `<nom>.netlify.app`.
Supprimez d'abord l'éventuel `A`/`CNAME` existant qui pointe vers un hébergement LWS inexistant.

**B. Netlify DNS** : Netlify fournit 4 serveurs de noms à saisir chez LWS (*Serveurs DNS personnalisés*). Recréez alors vos MX/TXT dans Netlify avant de basculer.

## 4. HTTPS
Après propagation DNS (de quelques minutes à 48 h), Netlify → *Domain management → HTTPS → Verify DNS configuration → Provision certificate* (Let's Encrypt, renouvellement automatique), puis activer *Force HTTPS*. `netlify.toml` redirige déjà `www` et `http` vers `https://wifimarket.tech`.

## 5. Après la mise en ligne
- Supabase → Auth → URL Configuration (Site URL et Redirect URLs avec `https://wifimarket.tech/auth/callback`).
- Vérifier : inscription/connexion, publication avec photo, messagerie, `/sitemap.xml`, installation PWA sur Android.
- Search Console : soumettre `https://wifimarket.tech/sitemap.xml`.
- Ne considérez le site « en ligne » qu'après ces vérifications.
