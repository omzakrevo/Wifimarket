import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(icon: Icons.wifi_off_rounded, title: context.t('error.not_found'), body: context.t('error.not_found_body'), action: () => context.go('/'), actionLabel: context.t('nav.home')),
      );
}

typedef _Doc = ({String title, List<(String, String)> sections});

const Map<String, Map<String, _Doc>> _docs = {
  'fr': {
    'about': (title: 'À propos de WiFiMarket', sections: [
      ('Notre mission', "WiFiMarket met en relation acheteurs et vendeurs de matériel Wi-Fi et réseau (antennes, routeurs, hotspots, câblage, accessoires) en Afrique de l'Ouest, avec des annonces claires, une messagerie intégrée et des boutiques vérifiées."),
      ('Comment ça marche', "Publiez gratuitement vos annonces avec photos, discutez avec les acheteurs, négociez ou échangez, puis convenez de la remise en main propre ou commandez avec livraison selon les règles configurées."),
      ('Paiements', "Le paiement convenu entre les parties est disponible. Les paiements en ligne ne sont activés qu'après vérification des prestataires et ne sont, pour l'instant, utilisables qu'en mode test."),
    ]),
    'safety': (title: 'Conseils de sécurité', sections: [
      ('Avant d\'acheter', "Vérifiez le profil du vendeur, ses évaluations et le badge « Vérifié ». Demandez des photos supplémentaires et testez le matériel devant vous."),
      ('Rencontre', "Retrouvez-vous dans un lieu public. Ne payez jamais à l'avance pour un article que vous n'avez pas vu, sauf via une commande suivie sur la plateforme."),
      ('Signalement', "Un doute ? Utilisez le bouton « Signaler » sur l'annonce ou la conversation : notre équipe examine chaque signalement."),
    ]),
    'prohibited': (title: 'Articles interdits', sections: [
      ('Liste', "Matériel volé ou de provenance douteuse, brouilleurs de signal (jammers), équipements contrefaits, équipements non conformes à la réglementation locale, offres frauduleuses, contenus illicites ou trompeurs."),
      ('Conséquences', "Les annonces concernées sont retirées et les comptes peuvent être suspendus."),
    ]),
    'terms': (title: "Conditions d'utilisation", sections: [
      ('1. Objet', "WiFiMarket est une plateforme d'annonces et de mise en relation. Les ventes sont conclues entre utilisateurs, sous leur responsabilité."),
      ('2. Compte', "Vous êtes responsable de la confidentialité de vos identifiants et de l'exactitude de vos informations."),
      ('3. Contenus', "Vous garantissez détenir les droits sur les photos et textes publiés et respecter la liste des articles interdits."),
      ('4. Modération', "Nous pouvons refuser, suspendre ou retirer tout contenu ou compte contraire aux règles de la plateforme."),
      ('5. Données', "Voir la politique de confidentialité."),
    ]),
    'privacy': (title: 'Confidentialité', sections: [
      ('Données collectées', "Adresse e-mail, nom affiché, annonces, messages, commandes. Votre numéro WhatsApp n'est jamais affiché sans votre accord explicite."),
      ('Vos droits', "Vous pouvez modifier votre profil et demander la suppression de vos données depuis votre compte. Certaines données de commande sont conservées pour obligations légales."),
      ('Sécurité', "Les données sont stockées chez Supabase avec des règles d'accès strictes (RLS)."),
    ]),
  },
  'en': {
    'about': (title: 'About WiFiMarket', sections: [
      ('Our mission', 'WiFiMarket connects buyers and sellers of Wi-Fi and networking gear (antennas, routers, hotspots, cabling, accessories) in West Africa, with clear listings, built-in messaging and verified shops.'),
      ('How it works', 'Post listings for free with photos, chat with buyers, negotiate or swap, then agree on in-person handover or order with delivery according to the configured rules.'),
      ('Payments', 'Payment agreed between the parties is available. Online payments are only enabled once providers are verified and are currently test-mode only.'),
    ]),
    'safety': (title: 'Safety tips', sections: [
      ('Before buying', "Check the seller's profile, ratings and the “Verified” badge. Ask for extra photos and test the equipment in front of you."),
      ('Meeting', "Meet in a public place. Never pay in advance for an item you haven't seen, except through a tracked order on the platform."),
      ('Reporting', 'Something off? Use the “Report” button on the listing or conversation: our team reviews every report.'),
    ]),
    'prohibited': (title: 'Prohibited items', sections: [
      ('List', 'Stolen or dubious-origin gear, signal jammers, counterfeit equipment, equipment not compliant with local regulations, fraudulent offers, illegal or misleading content.'),
      ('Consequences', 'Offending listings are removed and accounts may be suspended.'),
    ]),
    'terms': (title: 'Terms of use', sections: [
      ('1. Purpose', 'WiFiMarket is a classifieds and matchmaking platform. Sales are concluded between users, under their own responsibility.'),
      ('2. Account', 'You are responsible for keeping your credentials confidential and your information accurate.'),
      ('3. Content', 'You warrant that you hold the rights to the photos and text you post and comply with the prohibited items list.'),
      ('4. Moderation', 'We may refuse, suspend or remove any content or account that breaches platform rules.'),
      ('5. Data', 'See the privacy policy.'),
    ]),
    'privacy': (title: 'Privacy', sections: [
      ('Data collected', 'Email address, display name, listings, messages, orders. Your WhatsApp number is never shown without your explicit consent.'),
      ('Your rights', 'You can edit your profile and request deletion of your data from your account. Some order data is kept for legal obligations.'),
      ('Security', 'Data is stored on Supabase with strict row-level access rules.'),
    ]),
  },
};

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.doc});
  final String doc;
  @override
  Widget build(BuildContext context) {
    final d = _docs[context.lang]?[doc];
    if (d == null) return const NotFoundScreen();
    return WPage(
      title: d.title,
      maxWidth: 760,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, s) in d.sections.indexed) ...[
          Text(s.$1, style: Theme.of(context).textTheme.titleMedium).reveal(index: i),
          const SizedBox(height: 6),
          Text(s.$2, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55)).reveal(index: i),
          const SizedBox(height: 20),
        ],
        Wrap(spacing: 8, children: [for (final k in const ['about', 'safety', 'prohibited', 'terms', 'privacy']) if (k != doc) ActionChip(label: Text(_docs[context.lang]![k]!.title), onPressed: () => context.go('/info/$k'))]),
      ]),
    );
  }
}
