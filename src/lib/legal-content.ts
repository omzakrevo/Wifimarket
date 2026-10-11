/** Textes légaux de base. MODÈLES à faire relire et adapter par un juriste avant la mise en production. */
export type LegalPage = { title: [string, string]; sections: { h: [string, string]; p: [string, string] }[] };

export const LEGAL: Record<string, LegalPage> = {
  conditions: {
    title: ["Conditions générales d'utilisation", "Terms of use"],
    sections: [
      { h: ["Objet", "Purpose"], p: ["WiFiMarket est une place de marché en ligne mettant en relation des acheteurs et des vendeurs de matériel informatique, Wi-Fi et réseau. WiFiMarket n'est pas partie aux ventes conclues entre utilisateurs, sauf mention contraire pour les services de paiement intégrés.", "WiFiMarket is an online marketplace connecting buyers and sellers of computer, Wi-Fi and networking equipment. WiFiMarket is not a party to sales between users, unless stated otherwise for integrated payment services."] },
      { h: ["Compte et responsabilité", "Account and responsibility"], p: ["Chaque utilisateur est responsable des informations qu'il publie et de la confidentialité de ses identifiants. Les annonces doivent être exactes (état, défauts, prix) et concerner du matériel dont l'utilisateur est légalement propriétaire.", "Each user is responsible for the information they publish and for keeping their credentials confidential. Listings must be accurate (condition, defects, price) and concern equipment the user legally owns."] },
      { h: ["Modération", "Moderation"], p: ["WiFiMarket peut refuser, suspendre ou retirer toute annonce ou tout compte en cas de fraude, de matériel volé, contrefait ou interdit, ou de non-respect des présentes conditions.", "WiFiMarket may refuse, suspend or remove any listing or account in case of fraud, stolen, counterfeit or prohibited equipment, or breach of these terms."] },
      { h: ["Transactions", "Transactions"], p: ["Les prix sont affichés dans la devise choisie par le vendeur, sans conversion. Les frais de livraison sont ceux configurés par la plateforme. Les paiements en ligne ne sont proposés que lorsqu'un prestataire est activé pour le pays et la devise concernés.", "Prices are shown in the currency chosen by the seller, without conversion. Delivery fees are those configured by the platform. Online payments are offered only where a provider is enabled for the relevant country and currency."] },
      { h: ["Droit applicable", "Governing law"], p: ["Les présentes conditions sont à compléter avec la législation applicable à l'exploitant (à valider par un conseil juridique).", "These terms must be completed with the law applicable to the operator (to be validated by legal counsel)."] },
    ],
  },
  confidentialite: {
    title: ["Politique de confidentialité", "Privacy policy"],
    sections: [
      { h: ["Données collectées", "Data collected"], p: ["Nous collectons les données nécessaires au service : e-mail ou téléphone, nom affiché, pays et ville, annonces, messages, commandes. Le numéro WhatsApp n'est affiché que si vous y consentez expressément.", "We collect the data needed to run the service: email or phone, display name, country and city, listings, messages, orders. Your WhatsApp number is only shown if you explicitly consent."] },
      { h: ["Protection", "Protection"], p: ["Les données privées sont protégées par des règles d'accès au niveau de la base de données : seuls vous et les personnes autorisées pouvez y accéder. Les photos sont nettoyées de leurs métadonnées (dont la géolocalisation) avant envoi.", "Private data is protected by database-level access rules: only you and authorized people can access it. Photos are stripped of metadata (including geolocation) before upload."] },
      { h: ["Vos droits", "Your rights"], p: ["Vous pouvez modifier votre profil et demander la suppression de vos données depuis « Mon compte → Profil ». Les commandes sont conservées de manière anonymisée pour des raisons comptables et de litiges.", "You can edit your profile and request deletion of your data from “My account → Profile”. Orders are kept in anonymized form for accounting and dispute purposes."] },
      { h: ["Cookies", "Cookies"], p: ["Nous utilisons uniquement des cookies nécessaires (session, langue, localisation choisie) ; aucun traceur publicitaire.", "We only use necessary cookies (session, language, chosen location); no advertising trackers."] },
    ],
  },
  "annonces-interdites": {
    title: ["Annonces interdites", "Prohibited listings"],
    sections: [
      { h: ["Matériel interdit", "Prohibited equipment"], p: ["Sont interdits : le matériel volé, les contrefaçons, les brouilleurs de signal (jammers), les équipements dont la vente est interdite par la réglementation applicable, et toute annonce trompeuse.", "Prohibited: stolen equipment, counterfeits, signal jammers, equipment whose sale is forbidden by applicable regulations, and any misleading listing."] },
      { h: ["Signalement", "Reporting"], p: ["Utilisez le bouton « Signaler » sur une annonce ou une conversation. Chaque signalement est examiné par la modération.", "Use the “Report” button on a listing or conversation. Every report is reviewed by moderation."] },
    ],
  },
  securite: {
    title: ["Conseils de sécurité", "Safety tips"],
    sections: [
      { h: ["Avant d'acheter", "Before buying"], p: ["Vérifiez l'état du matériel (testez-le sur place), demandez des photos supplémentaires, consultez les avis et le statut de vérification du vendeur.", "Check the equipment's condition (test it on the spot), ask for extra photos, read reviews and the seller's verification status."] },
      { h: ["Paiement", "Payment"], p: ["Ne payez jamais à l'avance à un inconnu hors plateforme. Privilégiez le retrait en main propre dans un lieu public ou un paiement vérifié.", "Never pay in advance to a stranger outside the platform. Prefer in-person pickup in a public place or a verified payment."] },
      { h: ["Arnaques", "Scams"], p: ["Méfiez-vous des prix anormalement bas, des demandes de paiement hors plateforme et des liens suspects. Signalez tout comportement suspect.", "Beware of unusually low prices, off-platform payment requests and suspicious links. Report any suspicious behavior."] },
    ],
  },
};
