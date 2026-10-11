# Déploiement

## 1. Version web (site)

```bash
bash tool/build_web.sh          # produit build/web (statique)
```

Le dossier `build/web` contient tout (CanvasKit et polices embarqués, aucun CDN). Il faut simplement servir `index.html`
pour toutes les URL (application monopage) et utiliser **HTTPS** (caméra, PWA).

### LWS (hébergement mutualisé Apache)
1. Compiler (`bash tool/build_web.sh`) puis téléverser **le contenu** de `build/web` (y compris le fichier caché `.htaccess`)
   dans `htdocs/` (ou le dossier du domaine) via FTP/gestionnaire de fichiers. Le `.htaccess` fournit la redirection HTTPS et le repli SPA.
2. Activer le certificat SSL du domaine dans le panneau LWS.
3. Supabase → Authentication → URL Configuration : *Site URL* et *Redirect URLs* = votre domaine.

### Netlify
`netlify.toml` est prêt : lier le dépôt GitHub dans Netlify (build = `bash tool/netlify_build.sh`, publish = `build/web`).
Le build installe Flutter automatiquement (premier build plus long).

### DNS (`wifimarket.tech`)
Ne modifiez les enregistrements qu'après avoir relevé l'existant. Netlify : `A 75.2.60.5` (apex) et `CNAME www → <site>.netlify.app`
(valeurs à confirmer dans Netlify → Domain management). LWS : utiliser l'IP de l'hébergement indiquée dans le panneau LWS.

## 2. Applications mobiles
- Android : `flutter build appbundle --release` (signature : créer un keystore, `android/key.properties` — non versionnés).
- iOS : `flutter build ipa` sur macOS, compte Apple Developer requis.
- Identifiant d'application actuel : `tech.wifimarket.wifimarket` (à modifier avant publication si besoin).

## 3. Limites connues
- Flutter web est rendu dans un canevas : le référencement (SEO) des pages d'annonces est limité. Pour un SEO fort, prévoir
  des pages de rendu serveur / pré-rendu (ex. Edge Function Supabase ou site vitrine) — non inclus.
- Paiements en ligne (Paystack / CinetPay) non branchés : ils exigent une fonction serveur (initialisation + webhook signé)
  à créer en Edge Function avec la clé secrète côté serveur. Le client Flutter n'embarque jamais de secret.
- Suppression de compte : le traitement (`anonymize_user`) nécessite la migration `0009_gdpr.sql`.
