#!/usr/bin/env python3
"""Génère supabase/seed_demo.sql : données FICTIVES de démonstration (isolées via is_demo = true, e-mails @demo.wifimarket.test).
Ne jamais exécuter en production. Mot de passe de tous les comptes de démo : voir DEMO_PASSWORD."""
import uuid, json, os
NS = uuid.UUID("5d0c2f0e-4a49-4c8e-9a62-0a5a4d0a1111")
DEMO_PASSWORD = "Demo!2345"
u = lambda name: str(uuid.uuid5(NS, name))
q = lambda s: "null" if s is None else "'" + str(s).replace("'", "''") + "'"
out = []
w = out.append

w("-- DONNÉES FICTIVES DE DÉMONSTRATION — NE PAS EXÉCUTER EN PRODUCTION")
w("-- Généré par supabase/tools/gen_seed_demo.py. Comptes de démo : *@demo.wifimarket.test / mot de passe: %s" % DEMO_PASSWORD)
w("create extension if not exists pgcrypto with schema extensions;\n")

sellers = [
 ("awa", "Awa Traoré", "BF", "Bobo-Dioulasso", "Technicienne réseau, installations Wi-Fi communautaires.", "verified"),
 ("ibrahim", "Ibrahim Ouédraogo", "BF", "Ouagadougou", "Gérant de Faso Réseau Pro.", "verified"),
 ("moussa", "Moussa Diarra", "ML", "Bamako", "Distributeur matériel radio au Mali.", "verified"),
 ("fatou", "Fatou Ndiaye", "SN", "Dakar", "Revente de matériel reconditionné.", "unverified"),
 ("kofi", "Kofi Mensah", "GH", "Accra", "Installateur Starlink et Ubiquiti.", "verified"),
 ("chinedu", "Chinedu Okafor", "NG", "Lagos", "ISP local, vend son surplus de matériel.", "unverified"),
 ("seydou", "Koné Seydou", "CI", "Abidjan", "Responsable Abidjan Wireless Store.", "verified"),
 ("aminata", "Aminata Camara", "GN", "Conakry", "Particulier, matériel d'occasion.", "unverified"),
]
buyers = [("demo_admin", "Admin Démo", "BF", "Ouagadougou", "Compte superadmin de démonstration.", "verified"),
          ("demo_buyer", "Acheteur Démo", "BF", "Bobo-Dioulasso", "Compte acheteur de démonstration.", "unverified")]
allu = sellers + buyers
w("-- Utilisateurs")
for key, name, cc, city, bio, ver in allu:
    uid = u(key); email = f"{key}@demo.wifimarket.test"
    w(f"insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, confirmation_token, recovery_token, email_change, email_change_token_new, raw_app_meta_data, raw_user_meta_data) values "
      f"('{uid}','00000000-0000-0000-0000-000000000000','authenticated','authenticated','{email}',extensions.crypt('{DEMO_PASSWORD}', extensions.gen_salt('bf')),now(),'','','','',"
      f"'{{\"provider\":\"email\",\"providers\":[\"email\"]}}'::jsonb, {q(json.dumps({'display_name': name, 'country_code': cc, 'city': city}, ensure_ascii=False))}::jsonb);")
    w(f"insert into auth.identities (user_id, provider_id, identity_data, provider, last_sign_in_at) values ('{uid}','{uid}', jsonb_build_object('sub','{uid}','email','{email}','email_verified',true), 'email', now());")
    w(f"update public.profiles set bio = {q(bio)}, verification_status = '{ver}', is_demo = true, show_whatsapp = {'true' if key in ('awa','ibrahim','moussa','seydou') else 'false'} where id = '{uid}';")
w("update public.private_profiles set whatsapp_number = '+22670000001' where id = '%s';" % u('awa'))
w("update public.private_profiles set whatsapp_number = '+22670000002' where id = '%s';" % u('ibrahim'))
w("update public.private_profiles set whatsapp_number = '+22370000003' where id = '%s';" % u('moussa'))
w("update public.private_profiles set whatsapp_number = '+22507000004' where id = '%s';" % u('seydou'))
w("insert into public.user_roles (user_id, role) values ('%s','superadmin');" % u('demo_admin'))

shops = [("faso-reseau-pro", "Faso Réseau Pro", "ibrahim", "BF", "Ouagadougou", "pro", "Spécialiste du matériel Ubiquiti, MikroTik et TP-Link pour opérateurs Wi-Fi au Burkina Faso."),
         ("sahelnet-distribution", "SahelNet Distribution", "moussa", "ML", "Bamako", "premium", "Distribution de matériel radio et réseau pour FAI et revendeurs."),
         ("abidjan-wireless-store", "Abidjan Wireless Store", "seydou", "CI", "Abidjan", "free", "Boutique d'équipements Wi-Fi, Starlink et accessoires.")]
w("-- Boutiques")
for slug, name, owner, cc, city, plan, desc in shops:
    w(f"insert into public.shops (id, owner_id, slug, name, description, country_code, city, plan, verification_status, is_demo) values ('{u(slug)}','{u(owner)}','{slug}',{q(name)},{q(desc)},'{cc}',{q(city)},'{plan}','verified',true);")

# (seller, shop, category, brand, model, title, desc, cond, price, cur, qty, cc, city, delivery, negotiable, exchange, defects, warranty, sponsored)
L = [
 ("ibrahim","faso-reseau-pro","ubiquiti-litebeam","ubiquiti","LiteBeam 5AC Gen2","Ubiquiti LiteBeam 5AC Gen2 neuf","Antenne CPE 5 GHz 23 dBi, livrée avec alimentation PoE 24V. Idéale pour liaison point à point.","new",45000,"XOF",12,"BF","Ouagadougou",True,False,False,None,"6 mois",True),
 ("awa",None,"ubiquiti-liteap","ubiquiti","LiteAP AC (LAP-120)","LiteAP AC 120 d'occasion","Point d'accès sectoriel 120° en très bon état, utilisé 8 mois sur un hotspot de quartier.","used",60000,"XOF",1,"BF","Bobo-Dioulasso",True,True,False,None,None,False),
 ("moussa","sahelnet-distribution","ubiquiti-nanostation","ubiquiti","NanoStation M5","NanoStation M5 occasion lot de 4","Lot de 4 NanoStation M5 testées, fonctionnelles, sans boîtier d'origine.","used",28000,"XOF",4,"ML","Bamako",True,True,True,"Boîtier d'origine manquant",None,False),
 ("ibrahim","faso-reseau-pro","ubiquiti-powerbeam","ubiquiti","PowerBeam 5AC 400","PowerBeam 5AC 400 neuf","Antenne directive 25 dBi pour liaisons longue distance. Garantie boutique.","new",115000,"XOF",5,"BF","Ouagadougou",True,False,False,None,"6 mois",False),
 ("chinedu",None,"ubiquiti-rocket","ubiquiti","Rocket Prism 5AC","Rocket Prism 5AC reconditionné","Radio Rocket Prism 5AC testée, mise à jour firmware, sans antenne.","refurbished",95000,"NGN",3,"NG","Lagos",False,True,False,None,"1 mois",False),
 ("seydou","abidjan-wireless-store","grandstream-gwn","grandstream","GWN7660","Grandstream GWN7660 Wi-Fi 6 neuf","Point d'accès Wi-Fi 6 plafonnier, gestion cloud gratuite via GWN.Cloud.","new",72000,"XOF",8,"CI","Abidjan",True,False,False,None,"1 an",True),
 ("awa",None,"tp-link-cpe","tp-link","CPE210","TP-Link CPE210 occasion","CPE 2.4 GHz 9 dBi, support mural inclus. Fonctionne parfaitement.","used",12000,"XOF",3,"BF","Bobo-Dioulasso",False,True,False,None,None,False),
 ("moussa","sahelnet-distribution","tp-link-cpe","tp-link","CPE510","TP-Link CPE510 neuf","CPE 5 GHz 13 dBi extérieur, PoE passif inclus.","new",32000,"XOF",20,"ML","Bamako",True,False,False,None,"3 mois",False),
 ("fatou",None,"comfast","autre","Comfast CF-E5","Comfast CF-E5 antenne extérieure","Antenne extérieure 5 GHz Comfast, légère trace d'usure.","used",14000,"XOF",2,"SN","Dakar",True,True,False,"Rayure sur le boîtier",None,False),
 ("kofi",None,"cudy","cudy","Cudy AP1300","Cudy AP1300 point d'accès neuf","Point d'accès Wi-Fi 5 gigabit avec PoE 802.3af.","new",650,"GHS",6,"GH","Accra",True,False,False,None,"6 mois",False),
 ("aminata",None,"mikrotik-wireless","mikrotik","SXTsq 5 ac","MikroTik SXTsq 5 ac occasion","Radio CPE 5 GHz, testée, avec adaptateur PoE.","used",350000,"GNF",2,"GN","Conakry",False,True,False,None,None,False),
 ("ibrahim","faso-reseau-pro","routeurs-mikrotik","mikrotik","hAP ac2","MikroTik hAP ac2 neuf","Routeur dual-band 5 ports gigabit, RouterOS niveau 4.","new",40000,"XOF",15,"BF","Ouagadougou",True,False,False,None,"6 mois",False),
 ("awa",None,"routeurs-mikrotik","mikrotik","hEX (RB750Gr3)","MikroTik hEX RB750Gr3 occasion","Routeur 5 ports gigabit pour hotspot, configuration réinitialisée.","used",25000,"XOF",2,"BF","Bobo-Dioulasso",True,True,False,None,None,False),
 ("moussa","sahelnet-distribution","routeurs-mikrotik","mikrotik","RB951Ui-2HnD","MikroTik RB951Ui-2HnD en panne","Routeur 2.4 GHz, ne s'allume plus (alimentation HS). Vendu pour pièces ou réparation.","broken",6000,"XOF",3,"ML","Bamako",False,True,False,"Ne démarre plus, probable défaut d'alimentation",None,False),
 ("chinedu",None,"routeurs-4g-5g","huawei","B535","Routeur 4G Huawei B535 débloqué","Routeur 4G+ CPE, débloqué tout opérateur, antenne externe en option.","used",45000,"NGN",4,"NG","Lagos",True,True,False,None,None,False),
 ("seydou","abidjan-wireless-store","routeurs-wifi-6-7","tp-link","Archer AX55","TP-Link Archer AX55 Wi-Fi 6","Routeur Wi-Fi 6 AX3000, neuf sous emballage.","new",58000,"XOF",7,"CI","Abidjan",True,False,False,None,"1 an",False),
 ("fatou",None,"controleurs-hotspot","mikrotik","CCR1009","Contrôleur hotspot MikroTik CCR1009","CCR1009-7G-1C-1S+ utilisé en contrôleur hotspot, très bon état.","refurbished",180000,"XOF",1,"SN","Dakar",True,False,False,None,"1 mois",False),
 ("kofi",None,"starlink-standard","starlink","Starlink Standard","Kit Starlink Standard complet","Kit Starlink Standard (antenne, routeur, câble, alimentation), activé et fonctionnel.","used",2800,"GHS",2,"GH","Accra",True,True,False,None,None,True),
 ("seydou","abidjan-wireless-store","starlink-mini","starlink","Starlink Mini","Starlink Mini neuf","Kit Starlink Mini portable, boîte scellée.","new",240000,"XOF",3,"CI","Abidjan",True,False,False,None,None,False),
 ("kofi",None,"adaptateurs-ethernet","starlink","Adaptateur Ethernet","Adaptateur Ethernet Starlink","Adaptateur Ethernet officiel pour routeur tiers, neuf.","new",350,"GHS",10,"GH","Accra",True,False,False,None,"3 mois",False),
 ("ibrahim","faso-reseau-pro","switchs","tp-link","TL-SG1016PE","Switch PoE+ 16 ports TP-Link","Switch administrable 16 ports gigabit dont 8 PoE+, neuf.","new",98000,"XOF",4,"BF","Ouagadougou",True,False,False,None,"1 an",False),
 ("moussa","sahelnet-distribution","injecteurs-poe","ubiquiti","POE-24-12W","Injecteurs PoE 24V 0,5A (lot de 10)","Lot de 10 injecteurs PoE passifs 24V 0,5A, neufs.","new",30000,"XOF",6,"ML","Bamako",True,False,False,None,"3 mois",False),
 ("awa",None,"cables-rj45","autre","Cat6 extérieur","Câble réseau Cat6 extérieur (bobine 305 m)","Bobine de câble Cat6 UTP extérieur avec gaine UV, non entamée.","new",65000,"XOF",2,"BF","Bobo-Dioulasso",True,False,False,None,None,False),
 ("seydou","abidjan-wireless-store","modules-sfp","cisco","SFP-10G-SR","Module SFP+ 10G SR compatible","Module SFP+ 10G multimode 850 nm, compatible Cisco/MikroTik, neuf.","new",12000,"XOF",25,"CI","Abidjan",True,False,False,None,"6 mois",False),
 ("fatou",None,"baies-coffrets","autre","Coffret 6U","Coffret réseau mural 6U","Coffret mural 6U avec ventilation, légèrement rayé.","used",35000,"XOF",1,"SN","Dakar",False,True,False,"Quelques rayures",None,False),
 ("kofi",None,"testeurs-reseau","autre","Testeur RJ45","Testeur de câble réseau RJ45","Testeur LAN RJ45/RJ11 avec télécommande, neuf.","new",85,"GHS",15,"GH","Accra",True,False,False,None,None,False),
 ("aminata",None,"pinces-a-sertir","autre","Pince RJ45","Pince à sertir RJ45 professionnelle","Pince à sertir RJ45/RJ11 avec coupe-câble, peu utilisée.","used",180000,"GNF",1,"GN","Conakry",False,True,False,None,None,False),
 ("moussa","sahelnet-distribution","onduleurs","autre","Onduleur 1000VA","Onduleur 1000VA pour équipements réseau","Onduleur line-interactive 1000VA, batteries remplacées il y a 3 mois.","refurbished",75000,"XOF",2,"ML","Bamako",True,False,False,None,"3 mois",False),
 ("chinedu",None,"batteries","autre","12V 100Ah","Batterie solaire 12V 100Ah occasion","Batterie gel 12V 100Ah, capacité mesurée à 80 %, idéale pour site Wi-Fi isolé.","for_parts",35000,"NGN",1,"NG","Lagos",False,True,False,"Capacité réduite",None,False),
 ("awa",None,"alimentations","autre","24V 1A","Alimentation 24V 1A PoE","Alimentation 24V 1A pour antennes Ubiquiti, lot de 3.","used",8000,"XOF",3,"BF","Bobo-Dioulasso",False,True,False,None,None,False),
]
assert len(L) == 30, len(L)
w("-- Annonces (30)")
lid = {}
for i, (sel, shop, cat, brand, model, title, desc, cond, price, cur, qty, cc, city, deliv, nego, exch, defects, warranty, spons) in enumerate(L):
    id_ = u(f"listing{i}"); lid[i] = id_
    sp = "true" if spons else "false"
    w(f"insert into public.listings (id, seller_id, shop_id, category_id, brand_id, model_text, title, description, condition, price, currency_code, quantity, country_code, city, delivery_available, negotiable, exchange_possible, defects, warranty, status, is_sponsored, sponsored_until, is_demo, created_at) values "
      f"('{id_}','{u(sel)}',{q(u(shop)) if shop else 'null'},(select id from public.categories where slug='{cat}'),(select id from public.brands where slug='{brand}'),{q(model)},{q(title)},{q(desc)},'{cond}',{price},'{cur}',{qty},'{cc}',{q(city)},{str(deliv).lower()},{str(nego).lower()},{str(exch).lower()},{q(defects)},{q(warranty)},'active',{sp},{'now() + interval \'7 days\'' if spons else 'null'},true, now() - interval '{i*7+1} hours');")
    if cat == 'starlink-standard' or 'ubiquiti' in cat:
        w(f"insert into public.listing_attributes (listing_id, key, value) values ('{id_}','Marque',{q(brand.capitalize())}),('{id_}','Modèle',{q(model)});")

w("-- Demandes de matériel")
W = [("demo_buyer","Je recherche une antenne LiteAP AC 120 d'occasion","ubiquiti-liteap","ubiquiti","LiteAP AC 120","used",60000,"XOF","BF","Bobo-Dioulasso","Pour un hotspot de quartier à Bobo-Dioulasso. Budget : 60 000 FCFA."),
     ("awa","Recherche Starlink Mini neuf","starlink-mini","starlink","Starlink Mini","new",260000,"XOF","BF","Ouagadougou","Kit complet, facture souhaitée."),
     ("fatou","Besoin de 10 CPE210","tp-link-cpe","tp-link","CPE210","any",15000,"XOF","SN","Dakar","Prix à l'unité, lot accepté."),
     ("kofi","Switch PoE 24 ports","switchs",None,"","new",900,"GHS","GH","Accra","Administrable, 24 ports gigabit PoE+."),
     ("chinedu","Onduleur pour site isolé","onduleurs",None,"","used",60000,"NGN","NG","Lagos","Pour site Wi-Fi isolé, 1 kVA minimum.")]
for i,(req,title,cat,brand,model,cond,bud,cur,cc,city,desc) in enumerate(W):
    w(f"insert into public.wanted_requests (id, requester_id, title, category_id, brand_id, model_text, condition_wanted, budget, currency_code, country_code, city, description, is_demo) values "
      f"('{u(f'wanted{i}')}','{u(req)}',{q(title)},(select id from public.categories where slug='{cat}'),{('(select id from public.brands where slug=%s)' % q(brand)) if brand else 'null'},{q(model)},'{cond}',{bud},'{cur}','{cc}',{q(city)},{q(desc)},true);")
w(f"insert into public.wanted_offers (request_id, seller_id, listing_id, price, currency_code, condition, message) values ('{u('wanted0')}','{u('awa')}','{lid[1]}',60000,'XOF','used','Disponible à Bobo-Dioulasso, remise en main propre possible.');")

w("-- Conversations de test")
c1 = u("conv1"); c2 = u("conv2")
w(f"insert into public.conversations (id, user_a, user_b, listing_id, is_demo) values ('{c1}','{u('demo_buyer')}','{u('ibrahim')}','{lid[0]}',true),('{c2}','{u('demo_buyer')}','{u('awa')}','{lid[1]}',true);")
msgs = [(c1,'demo_buyer',"Bonjour, la LiteBeam 5AC Gen2 est-elle toujours disponible ?"),(c1,'ibrahim',"Bonjour ! Oui, il en reste 12 en stock."),
        (c1,'demo_buyer',"Livrez-vous à Bobo-Dioulasso ?"),(c2,'demo_buyer',"Bonjour, la LiteAP est-elle négociable à 55 000 FCFA ?")]
for k,(c,s,b) in enumerate(msgs):
    w(f"insert into public.messages (conversation_id, sender_id, body, created_at) values ('{c}','{u(s)}',{q(b)}, now() - interval '{30-k*5} minutes');")

w("-- Négociation de test")
w(f"insert into public.negotiations (listing_id, buyer_id, seller_id, kind, offered_price, currency_code, note) values ('{lid[1]}','{u('demo_buyer')}','{u('awa')}','offer',55000,'XOF','Offre à 55 000 FCFA, retrait sur place.');")

w("-- Règles de livraison de DÉMONSTRATION (à remplacer par les règles réelles en administration)")
w("""insert into public.shipping_rules (method, from_country, to_country, same_city, fee, currency_code, eta_days_min, eta_days_max, carrier) values
  ('local','BF','BF',true,1500,'XOF',0,1,'DEMO'),
  ('intercity','BF','BF',false,5000,'XOF',1,3,'DEMO'),
  ('international','BF','ML',null,15000,'XOF',4,8,'DEMO'),
  ('local','ML','ML',true,1500,'XOF',0,1,'DEMO');""")

w("-- Commandes de test (créées directement par le script de démo, statuts réalistes)")
w(f"""insert into public.orders (id, buyer_id, seller_id, shop_id, status, currency_code, subtotal, shipping_fee, commission_rate, commission_amount, total, delivery_method, payment_method, is_demo, created_at) values
  ('{u('order1')}','{u('demo_buyer')}','{u('ibrahim')}','{u('faso-reseau-pro')}','completed','XOF',45000,0,0.03,1350,45000,'pickup','offline',true, now() - interval '10 days'),
  ('{u('order2')}','{u('demo_buyer')}','{u('ibrahim')}','{u('faso-reseau-pro')}','shipped','XOF',80000,5000,0.03,2400,85000,'intercity','offline',true, now() - interval '2 days');
insert into public.order_items (order_id, listing_id, title, unit_price, currency_code, quantity) values
  ('{u('order1')}','{lid[0]}','Ubiquiti LiteBeam 5AC Gen2 neuf',45000,'XOF',1),
  ('{u('order2')}','{lid[11]}','MikroTik hAP ac2 neuf',40000,'XOF',2);
insert into public.shipments (order_id, method, status, carrier, tracking_number) values
  ('{u('order1')}','pickup','delivered',null,null),
  ('{u('order2')}','intercity','in_transit','DEMO','DEMO-0001');
insert into public.reviews (reviewer_id, seller_id, shop_id, order_id, rating, comment) values
  ('{u('demo_buyer')}','{u('ibrahim')}','{u('faso-reseau-pro')}','{u('order1')}',5,'Matériel conforme, vendeur sérieux (avis de démonstration).');""")

w("-- Signalement de test")
w(f"insert into public.reports (reporter_id, target_type, target_id, reason, details) values ('{u('demo_buyer')}','listing','{lid[14]}','other','Signalement de démonstration pour tester la modération.');")
open(os.path.join(os.path.dirname(__file__), "..", "seed_demo.sql"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("seed_demo.sql généré")
