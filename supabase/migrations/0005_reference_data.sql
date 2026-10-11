-- WiFiMarket — données de référence (pays, devises, catégories, marques, paramètres)

insert into public.currencies (code, name, symbol, decimals, enabled) values
  ('XOF','Franc CFA (BCEAO)','FCFA',0,true),
  ('GHS','Cedi ghanéen','GH₵',2,true),
  ('NGN','Naira nigérian','₦',2,true),
  ('GNF','Franc guinéen','FG',0,true),
  ('GMD','Dalasi gambien','D',2,true),
  ('LRD','Dollar libérien','L$',2,true),
  ('SLE','Leone sierra-léonais','Le',2,true),
  ('CVE','Escudo cap-verdien','Esc',0,true),
  ('USD','Dollar américain','$',2,false),
  ('EUR','Euro','€',2,false)
on conflict (code) do nothing;

insert into public.countries (code, name_fr, name_en, currency_code, phone_prefix, sort_order) values
  ('BF','Burkina Faso','Burkina Faso','XOF','+226',0),
  ('ML','Mali','Mali','XOF','+223',1),
  ('NE','Niger','Niger','XOF','+227',2),
  ('CI','Côte d''Ivoire','Côte d''Ivoire','XOF','+225',3),
  ('SN','Sénégal','Senegal','XOF','+221',4),
  ('BJ','Bénin','Benin','XOF','+229',5),
  ('TG','Togo','Togo','XOF','+228',6),
  ('GW','Guinée-Bissau','Guinea-Bissau','XOF','+245',7),
  ('GH','Ghana','Ghana','GHS','+233',8),
  ('NG','Nigeria','Nigeria','NGN','+234',9),
  ('GN','Guinée','Guinea','GNF','+224',10),
  ('GM','Gambie','Gambia','GMD','+220',11),
  ('LR','Liberia','Liberia','LRD','+231',12),
  ('SL','Sierra Leone','Sierra Leone','SLE','+232',13),
  ('CV','Cap-Vert','Cape Verde','CVE','+238',14)
on conflict (code) do nothing;

insert into public.cities (country_code, name) values
  ('BF','Ouagadougou'),
  ('BF','Bobo-Dioulasso'),
  ('BF','Koudougou'),
  ('BF','Banfora'),
  ('BF','Ouahigouya'),
  ('BF','Dédougou'),
  ('BF','Fada N''Gourma'),
  ('BF','Kaya'),
  ('BF','Tenkodogo'),
  ('BF','Dori'),
  ('ML','Bamako'),
  ('ML','Sikasso'),
  ('ML','Ségou'),
  ('ML','Mopti'),
  ('ML','Kayes'),
  ('ML','Koutiala'),
  ('NE','Niamey'),
  ('NE','Zinder'),
  ('NE','Maradi'),
  ('NE','Agadez'),
  ('NE','Tahoua'),
  ('CI','Abidjan'),
  ('CI','Bouaké'),
  ('CI','Yamoussoukro'),
  ('CI','San-Pédro'),
  ('CI','Korhogo'),
  ('CI','Daloa'),
  ('SN','Dakar'),
  ('SN','Thiès'),
  ('SN','Saint-Louis'),
  ('SN','Touba'),
  ('SN','Kaolack'),
  ('SN','Ziguinchor'),
  ('BJ','Cotonou'),
  ('BJ','Porto-Novo'),
  ('BJ','Parakou'),
  ('BJ','Abomey-Calavi'),
  ('BJ','Bohicon'),
  ('TG','Lomé'),
  ('TG','Kara'),
  ('TG','Sokodé'),
  ('TG','Atakpamé'),
  ('GW','Bissau'),
  ('GW','Bafatá'),
  ('GH','Accra'),
  ('GH','Kumasi'),
  ('GH','Tamale'),
  ('GH','Takoradi'),
  ('NG','Lagos'),
  ('NG','Abuja'),
  ('NG','Kano'),
  ('NG','Ibadan'),
  ('NG','Port Harcourt'),
  ('GN','Conakry'),
  ('GN','Kankan'),
  ('GN','Labé'),
  ('GN','Nzérékoré'),
  ('GM','Banjul'),
  ('GM','Serekunda'),
  ('LR','Monrovia'),
  ('SL','Freetown'),
  ('SL','Bo'),
  ('CV','Praia'),
  ('CV','Mindelo')
on conflict do nothing;

insert into public.categories (parent_id, slug, name_fr, name_en, icon, sort_order) values
  (null,'antennes-radio','Antennes et équipements radio','Antennas & radio equipment','radio',0),
  (null,'routeurs-hotspots','Routeurs et Hotspots','Routers & Hotspots','router',1),
  (null,'internet-satellitaire','Internet satellitaire','Satellite internet','satellite',2),
  (null,'reseau-filaire','Réseau filaire','Wired networking','cable',3),
  (null,'outils-accessoires','Outils et accessoires','Tools & accessories','wrench',4)
on conflict (slug) do nothing;

insert into public.categories (parent_id, slug, name_fr, name_en, sort_order)
select p.id, v.slug, v.name_fr, v.name_en, v.ord from (values
  ('antennes-radio','ubiquiti-litebeam','Ubiquiti LiteBeam','Ubiquiti LiteBeam',0),
  ('antennes-radio','ubiquiti-liteap','Ubiquiti LiteAP','Ubiquiti LiteAP',1),
  ('antennes-radio','ubiquiti-nanostation','Ubiquiti NanoStation','Ubiquiti NanoStation',2),
  ('antennes-radio','ubiquiti-powerbeam','Ubiquiti PowerBeam','Ubiquiti PowerBeam',3),
  ('antennes-radio','ubiquiti-rocket','Ubiquiti Rocket','Ubiquiti Rocket',4),
  ('antennes-radio','grandstream-gwn','Grandstream GWN','Grandstream GWN',5),
  ('antennes-radio','tp-link-cpe','TP-Link CPE','TP-Link CPE',6),
  ('antennes-radio','comfast','Comfast','Comfast',7),
  ('antennes-radio','cudy','Cudy','Cudy',8),
  ('antennes-radio','mikrotik-wireless','MikroTik Wireless','MikroTik Wireless',9),
  ('routeurs-hotspots','routeurs-mikrotik','MikroTik','MikroTik',0),
  ('routeurs-hotspots','routeurs-tp-link','TP-Link','TP-Link',1),
  ('routeurs-hotspots','routeurs-ubiquiti','Ubiquiti','Ubiquiti',2),
  ('routeurs-hotspots','routeurs-4g-5g','Routeurs 4G/5G','4G/5G routers',3),
  ('routeurs-hotspots','routeurs-wifi-6-7','Routeurs Wi-Fi 6/7','Wi-Fi 6/7 routers',4),
  ('routeurs-hotspots','controleurs-hotspot','Contrôleurs Hotspot','Hotspot controllers',5),
  ('internet-satellitaire','starlink-standard','Starlink Standard','Starlink Standard',0),
  ('internet-satellitaire','starlink-mini','Starlink Mini','Starlink Mini',1),
  ('internet-satellitaire','starlink-performance','Starlink Performance','Starlink Performance',2),
  ('internet-satellitaire','accessoires-starlink','Accessoires Starlink','Starlink accessories',3),
  ('internet-satellitaire','adaptateurs-ethernet','Adaptateurs Ethernet','Ethernet adapters',4),
  ('internet-satellitaire','alimentations-starlink','Alimentations','Power supplies',5),
  ('internet-satellitaire','supports-starlink','Supports','Mounts',6),
  ('reseau-filaire','switchs','Switchs','Switches',0),
  ('reseau-filaire','injecteurs-poe','Injecteurs PoE','PoE injectors',1),
  ('reseau-filaire','cables-rj45','Câbles RJ45','RJ45 cables',2),
  ('reseau-filaire','fibre-optique','Fibre optique','Fiber optic',3),
  ('reseau-filaire','modules-sfp','Modules SFP','SFP modules',4),
  ('reseau-filaire','connecteurs','Connecteurs','Connectors',5),
  ('reseau-filaire','baies-coffrets','Baies et coffrets réseau','Racks & network cabinets',6),
  ('outils-accessoires','testeurs-reseau','Testeurs réseau','Network testers',0),
  ('outils-accessoires','pinces-a-sertir','Pinces à sertir','Crimping tools',1),
  ('outils-accessoires','outils-fibre','Outils de fibre optique','Fiber optic tools',2),
  ('outils-accessoires','onduleurs','Onduleurs','UPS',3),
  ('outils-accessoires','batteries','Batteries','Batteries',4),
  ('outils-accessoires','alimentations','Alimentations','Power supplies',5)
) as v(parent, slug, name_fr, name_en, ord) join public.categories p on p.slug = v.parent
on conflict (slug) do nothing;

insert into public.brands (slug, name) values
  ('ubiquiti','Ubiquiti'),
  ('mikrotik','MikroTik'),
  ('tp-link','TP-Link'),
  ('grandstream','Grandstream'),
  ('comfast','Comfast'),
  ('cudy','Cudy'),
  ('starlink','Starlink'),
  ('huawei','Huawei'),
  ('zte','ZTE'),
  ('cisco','Cisco'),
  ('d-link','D-Link'),
  ('netgear','Netgear'),
  ('tenda','Tenda'),
  ('mercusys','Mercusys'),
  ('autre','Autre')
on conflict (slug) do nothing;

insert into public.product_models (brand_id, category_id, name, specs)
select b.id, c.id, v.name, v.specs::jsonb from (values
  ('ubiquiti','ubiquiti-litebeam','LiteBeam 5AC Gen2','{"frequence": "5 GHz", "gain": "23 dBi", "poe": "24V passif"}'),
  ('ubiquiti','ubiquiti-liteap','LiteAP AC (LAP-120)','{"frequence": "5 GHz", "secteur": "120°", "gain": "16 dBi"}'),
  ('ubiquiti','ubiquiti-nanostation','NanoStation M5','{"frequence": "5 GHz", "gain": "16 dBi"}'),
  ('ubiquiti','ubiquiti-nanostation','NanoStation 5AC Loco','{"frequence": "5 GHz", "gain": "13 dBi"}'),
  ('ubiquiti','ubiquiti-powerbeam','PowerBeam 5AC 400','{"frequence": "5 GHz", "gain": "25 dBi"}'),
  ('ubiquiti','ubiquiti-rocket','Rocket Prism 5AC','{"frequence": "5 GHz"}'),
  ('mikrotik','routeurs-mikrotik','hAP ac2','{"wifi": "2.4/5 GHz", "ports": "5 x Gigabit"}'),
  ('mikrotik','routeurs-mikrotik','hEX (RB750Gr3)','{"ports": "5 x Gigabit"}'),
  ('mikrotik','routeurs-mikrotik','RB951Ui-2HnD','{"wifi": "2.4 GHz", "ports": "5 x 10/100"}'),
  ('tp-link','tp-link-cpe','CPE210','{"frequence": "2.4 GHz", "gain": "9 dBi"}'),
  ('tp-link','tp-link-cpe','CPE510','{"frequence": "5 GHz", "gain": "13 dBi"}'),
  ('grandstream','grandstream-gwn','GWN7660','{"wifi": "Wi-Fi 6"}'),
  ('grandstream','grandstream-gwn','GWN7003','{"type": "routeur"}'),
  ('starlink','starlink-standard','Starlink Standard','{"type": "kit complet"}'),
  ('starlink','starlink-mini','Starlink Mini','{"type": "kit complet"}')
) as v(brand, cat, name, specs) join public.brands b on b.slug = v.brand join public.categories c on c.slug = v.cat
on conflict do nothing;

insert into public.platform_settings (key, value, description) values
  ('commission_rate', '0.03', 'Commission indicative sur les transactions intégrées (3 %) — tarif de démonstration'),
  ('auto_approve_listings', 'true', 'Publication automatique si aucun mot interdit n''est détecté'),
  ('listing_duration_days', '60', 'Durée de vie d''une annonce avant expiration'),
  ('max_listings_per_day', '30', 'Limite anti-spam : annonces créées par utilisateur sur 24 h'),
  ('max_messages_per_minute', '20', 'Limite anti-spam : messages par minute et par utilisateur'),
  ('exchange_rates_enabled', 'false', 'Conversion monétaire désactivée tant qu''aucune source de taux fiable n''est configurée')
on conflict (key) do nothing;

-- Tarifs de démonstration (modifiables dans l'administration)
insert into public.plans (code, name, kind, price, currency_code, duration_days) values
  ('sponsored_7d', 'Annonce sponsorisée 7 jours', 'sponsorship', 500, 'XOF', 7),
  ('shop_pro', 'Boutique Pro', 'shop_subscription', 3000, 'XOF', 30),
  ('shop_premium', 'Boutique Premium', 'shop_subscription', 7500, 'XOF', 30)
on conflict (code) do nothing;

-- Prestataires de paiement : AUCUN n'est activé et l'éligibilité par pays/devise n'est pas vérifiée.
-- Un administrateur doit renseigner les pays/devises/moyens confirmés par le prestataire, puis fournir les identifiants marchands.
insert into public.payment_providers (code, name, enabled, sandbox, eligibility_verified, notes) values
  ('cinetpay', 'CinetPay', false, true, false, 'Intégration préparée. Vérifier pays, devises et moyens de paiement avec CinetPay avant activation.'),
  ('paystack', 'Paystack', false, true, false, 'Intégration préparée. Vérifier pays, devises et moyens de paiement avec Paystack avant activation.'),
  ('offline', 'Paiement convenu entre les parties', true, false, true, 'Paiement à la remise ou au retrait, hors plateforme : aucun fonds n''est géré par WiFiMarket.')
on conflict (code) do nothing;

insert into public.banned_keywords (keyword, reason) values
  ('volé', 'Matériel volé interdit'), ('brouilleur', 'Équipement de brouillage interdit'), ('jammer', 'Équipement de brouillage interdit'),
  ('contrefait', 'Contrefaçon'), ('contrefaçon', 'Contrefaçon'), ('piraté', 'Contenu frauduleux'), ('carte clonée', 'Fraude')
on conflict (keyword) do nothing;
