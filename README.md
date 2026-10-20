# ZoneHub — Marketplace SaaS de matériel WiFi zone

Application **Flutter (web + Android + iOS)** inspirée du design « TechHub » :
une place de marché **uniquement dédiée au matériel de WiFi zone**
(routeurs hotspot, antennes, point-à-point, switch PoE, câbles, énergie, Starlink, tickets).

## Fonctionnalités

| Espace | Ce qu'on peut faire |
|---|---|
| **Visiteur (par pays)** | Choix du pays au premier lancement → un compte visiteur est créé pour ce pays (un compte par pays, réutilisé ensuite). Catalogue, boutiques, annonces et devise (FCFA, GH₵, ₦) filtrés par pays. Recherche, filtres, favoris, panier, commande (Orange Money, Moov, Wave, à la livraison). |
| **Occasion** | Publication gratuite d'annonces de matériel d'occasion (état, prix négociable, contact), modérées par l'admin avant publication. |
| **Vendeur (SaaS)** | Demande d'ouverture de boutique + choix d'abonnement (Starter gratuit / Pro 15 000 / Business 35 000 FCFA/mois). Tableau de bord, ajout/modification/suppression de produits, limite selon le plan. |
| **Admin** | Tableau de bord (MRR, boutiques, produits, annonces, comptes), validation / suspension des boutiques, badge « vérifié », changement de plan, modération des annonces, vue par pays. |

Dans l'onglet **Compte**, le sélecteur « Mode démo » permet de passer Visiteur / Vendeur / Admin pour tester.

## Lancer

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # téléphone Android/iOS branché
flutter build apk --release  # APK Android
flutter build web --release  # site web (dossier build/web)
flutter test                 # tests (mobile + desktop)
```

## Structure

```
lib/
  main.dart                 point d'entrée
  theme.dart                couleurs/typo inspirées du design (bleu + bannières sombres)
  data/models.dart          Pays, Boutique, Produit, Annonce, Plans SaaS, Utilisateur
  data/demo_data.dart       données de démo + photos libres de droits
  state/app_state.dart      état global (à brancher sur Supabase)
  widgets/common.dart       cartes produit, logo, grille responsive
  screens/                  accueil, catégories, recherche, produit, panier,
                            boutiques, occasion, compte, vendeur, admin, pays
backend/supabase_schema.sql tables, plans, RLS multi-boutiques, stats admin
```

## Passer en production (Supabase)

1. Créer un projet Supabase et exécuter `backend/supabase_schema.sql`.
2. Ajouter `supabase_flutter` et remplacer les méthodes de `AppState` par des requêtes
   (chaque méthode est commentée pour ça). Les visiteurs utilisent `signInAnonymously()`
   + une ligne `profiles` avec leur `country_code`.
3. Stockage des photos produits/annonces : bucket Supabase Storage.
4. Paiement des abonnements et commandes : CinetPay / PayDunya / FedaPay (Mobile Money).

## Images

Photos issues d'**Unsplash** (Licence Unsplash : usage commercial gratuit, sans attribution obligatoire).
Elles sont chargées par URL (`lib/data/demo_data.dart`, classe `Img`) — remplacez-les par vos propres
photos produit dès que les boutiques sont en ligne.
