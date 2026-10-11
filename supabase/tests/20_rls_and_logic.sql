\set ON_ERROR_STOP on
set client_min_messages = notice;

-- ===================== Lecture publique / vie privée =====================
begin;
select t.anon();
select t.ok(t.n('select 1 from public.listings') = 30, 'anonyme : voit les 30 annonces actives de démo');
select t.ok(t.n('select 1 from public.private_profiles') = 0, 'anonyme : aucune donnée privée');
select t.ok(t.n('select 1 from public.messages') = 0, 'anonyme : aucun message');
select t.ok(t.n('select 1 from public.orders') = 0, 'anonyme : aucune commande');
select t.fails($$insert into public.favorites(user_id, listing_id) values (gen_random_uuid(), gen_random_uuid())$$, 'anonyme : ne peut pas écrire');
select t.fails($$select public.place_order('pickup')$$, 'anonyme : ne peut pas commander');
select t.fails($$select public.admin_stats()$$, 'anonyme : pas de stats admin');
rollback;

begin;
select t.login('demo_buyer');
select t.ok(t.n($$select 1 from public.private_profiles where id <> auth.uid()$$) = 0, 'acheteur : ne voit pas les données privées des autres');
select t.ok((select public.get_whatsapp(t.uid('awa'))) = '+22670000001', 'WhatsApp visible quand le vendeur a consenti');
select t.ok((select public.get_whatsapp(t.uid('fatou'))) is null, 'WhatsApp masqué sans consentement');
select t.blocked($$update public.profiles set display_name = 'Pirate' where id = t.uid('awa')$$, 'acheteur : ne peut pas modifier le profil d''un autre') ;
update public.profiles set verification_status = 'verified' where id = t.uid('demo_buyer');
select t.ok((select verification_status from public.profiles where id = t.uid('demo_buyer')) = 'unverified', 'acheteur : ne peut pas se vérifier lui-même');
select t.fails($$insert into public.user_roles(user_id, role) values (t.uid('demo_buyer'), 'superadmin')$$, 'acheteur : ne peut pas s''octroyer un rôle');
rollback;

-- ===================== Publication & modération =====================
begin;
select t.login('kofi');
insert into public.listings (id, seller_id, category_id, title, condition, price, currency_code, country_code, city, status)
values ('aaaaaaaa-0000-0000-0000-000000000001', t.uid('kofi'), (select id from public.categories where slug='switchs'), 'Switch Gigabit 8 ports', 'new', 15000, 'GHS', 'GH', 'Accra', 'active');
select t.ok((select status from public.listings where id='aaaaaaaa-0000-0000-0000-000000000001') = 'active', 'publication directe sans mot interdit → active');
select t.ok((select slug from public.listings where id='aaaaaaaa-0000-0000-0000-000000000001') like 'switch-gigabit-8-ports-%', 'slug lisible généré');
select t.ok((select published_at from public.listings where id='aaaaaaaa-0000-0000-0000-000000000001') is not null, 'date de publication posée');
insert into public.listings (id, seller_id, category_id, title, condition, price, currency_code, country_code, status, is_sponsored)
values ('aaaaaaaa-0000-0000-0000-000000000002', t.uid('kofi'), (select id from public.categories where slug='switchs'), 'Switch volé à bas prix', 'used', 100, 'GHS', 'GH', 'active', true);
select t.ok((select status from public.listings where id='aaaaaaaa-0000-0000-0000-000000000002') = 'pending_review', 'mot interdit → modération manuelle');
select t.ok(not (select is_sponsored from public.listings where id='aaaaaaaa-0000-0000-0000-000000000002'), 'un vendeur ne peut pas se sponsoriser');
select t.fails($$insert into public.listings (seller_id, category_id, title, condition, price, currency_code, country_code, status) values (t.uid('awa'), 1, 'Annonce usurpée', 'new', 1, 'XOF', 'BF', 'active')$$, 'impossible de publier au nom d''un autre');
select t.login('demo_buyer');
select t.ok(t.n($$select 1 from public.listings where id='aaaaaaaa-0000-0000-0000-000000000002'$$) = 0, 'annonce en modération invisible du public');
update public.listings set price = 1 where id = 'aaaaaaaa-0000-0000-0000-000000000001';
select t.ok((select price from public.listings where id='aaaaaaaa-0000-0000-0000-000000000001') = 15000, 'on ne modifie pas l''annonce d''un autre');
-- modérateur
select t.root();
insert into public.user_roles(user_id, role) values (t.uid('fatou'), 'moderator');
select t.login('fatou');
select t.ok(t.n($$select 1 from public.listings where id='aaaaaaaa-0000-0000-0000-000000000002'$$) = 1, 'modérateur : voit l''annonce en attente');
update public.listings set status = 'rejected', rejection_reason = 'Mot interdit' where id = 'aaaaaaaa-0000-0000-0000-000000000002';
select t.ok((select status from public.listings where id='aaaaaaaa-0000-0000-0000-000000000002') = 'rejected', 'modérateur : peut refuser');
select t.login('kofi');
select t.ok(t.n($$select 1 from public.notifications where type='listing_rejected'$$) = 1, 'le vendeur est notifié du refus');
update public.listings set status = 'active' where id = 'aaaaaaaa-0000-0000-0000-000000000002';
select t.ok((select status from public.listings where id='aaaaaaaa-0000-0000-0000-000000000002') = 'pending_review', 'renvoi d''une annonce refusée → retour en modération');
select t.root();
select t.ok((select count(*) from public.audit_logs where entity_type='listings' and actor_id = t.uid('fatou')) >= 1, 'action de modération journalisée');
select t.login('demo_buyer');
select t.ok(t.n('select 1 from public.audit_logs') = 0, 'journal d''audit illisible pour un utilisateur');
select t.fails($$select public.admin_stats()$$, 'stats admin refusées au simple utilisateur');
rollback;

-- ===================== Alertes de recherche enregistrée =====================
begin;
select t.login('demo_buyer');
insert into public.saved_searches (user_id, label, query, country_code) values (t.uid('demo_buyer'), 'LiteBeam au Burkina', 'litebeam', 'BF');
select t.login('ibrahim');
insert into public.listings (seller_id, category_id, title, condition, price, currency_code, country_code, city, status)
values (t.uid('ibrahim'), (select id from public.categories where slug='ubiquiti-litebeam'), 'LiteBeam 5AC Gen2 lot promo', 'new', 44000, 'XOF', 'BF', 'Ouagadougou', 'active');
select t.login('demo_buyer');
select t.ok(t.n($$select 1 from public.notifications where type='saved_search'$$) = 1, 'recherche enregistrée : notification à la publication');
rollback;

-- ===================== Messagerie =====================
begin;
select t.login('kofi');
select t.ok(t.n('select 1 from public.messages') = 0, 'tiers : ne lit aucun message de démo');
select t.ok(t.n('select 1 from public.conversations') = 0, 'tiers : ne voit aucune conversation');
select t.fails($$insert into public.messages(conversation_id, sender_id, body) values (t.conv_bi(), auth.uid(), 'intrusion')$$, 'tiers : insertion impossible') ;
select t.login('demo_buyer');
select t.ok(t.n('select 1 from public.messages') = 4, 'participant : lit ses 4 messages');
select public.mark_conversation_read((select id from public.conversations where listing_id = (select id from public.listings where title like 'Ubiquiti LiteBeam 5AC Gen2 neuf')));
select t.login('ibrahim');
select t.ok(t.n($$select 1 from public.messages where read_at is null and sender_id <> auth.uid()$$) = 2, 'vendeur : 2 messages non lus de l''acheteur');
select public.mark_conversation_read((select id from public.conversations where user_b = auth.uid()));
select t.ok(t.n($$select 1 from public.messages where read_at is null and sender_id <> auth.uid()$$) = 0, 'messages marqués comme lus');
select t.login('demo_buyer');
select t.ok(t.n($$select 1 from public.messages where read_at is not null and sender_id = auth.uid()$$) = 2, 'l''expéditeur voit l''accusé de lecture');
-- usurpation d'expéditeur
insert into public.messages(conversation_id, sender_id, body) values (t.conv_bi(), t.uid('ibrahim'), 'je suis lui');
select t.ok((select sender_id from public.messages where body='je suis lui') = t.uid('demo_buyer'), 'usurpation d''expéditeur neutralisée (expéditeur forcé = utilisateur connecté)');
-- start_conversation idempotent
select public.start_conversation(t.uid('moussa'), (select id from public.listings limit 1)) into temp c1;
select t.ok((select public.start_conversation(t.uid('moussa'), (select id from public.listings limit 1))) = (select start_conversation from c1), 'start_conversation idempotent');
-- blocage
select t.login('ibrahim');
insert into public.user_blocks(blocker_id, blocked_id) values (t.uid('ibrahim'), t.uid('demo_buyer'));
select t.fails($$insert into public.messages(conversation_id, sender_id, body) values (t.conv_bi(), auth.uid(), 'test')$$, 'message impossible vers un utilisateur qui a bloqué');
select t.login('demo_buyer');
select t.fails($$select public.start_conversation(t.uid('ibrahim'))$$, 'nouvelle conversation refusée après blocage');
rollback;

-- ===================== Négociation, échange, avis =====================
begin;
select t.login('demo_buyer');
select t.fails($$insert into public.negotiations(listing_id, kind, offered_price) values ((select id from public.listings where title = 'Ubiquiti LiteBeam 5AC Gen2 neuf'), 'offer', 1)$$, 'offre refusée si l''annonce n''est pas négociable');
insert into public.negotiations(id, listing_id, kind, offered_price, note)
values ('bbbbbbbb-0000-0000-0000-000000000001', (select id from public.listings where title = 'NanoStation M5 occasion lot de 4'), 'offer', 40000, 'Offre');
select t.ok((select seller_id from public.negotiations where id='bbbbbbbb-0000-0000-0000-000000000001') = t.uid('moussa'), 'le vendeur est déduit de l''annonce (non falsifiable)');
select t.ok((select currency_code from public.negotiations where id='bbbbbbbb-0000-0000-0000-000000000001') = 'XOF', 'devise = devise de l''annonce');
select t.blocked($$update public.negotiations set status = 'accepted' where id='bbbbbbbb-0000-0000-0000-000000000001'$$, 'acheteur : ne peut pas s''auto-accepter');
select t.fails($$select public.negotiation_respond('bbbbbbbb-0000-0000-0000-000000000001', 'accept')$$, 'acheteur : ne peut pas accepter sa propre offre');
select t.login('kofi');
select t.ok(t.n('select 1 from public.negotiations') = 0, 'tiers : ne voit pas la négociation');
select t.fails($$select public.negotiation_respond('bbbbbbbb-0000-0000-0000-000000000001', 'accept')$$, 'tiers : ne peut pas répondre');
select t.login('moussa');
select public.negotiation_respond('bbbbbbbb-0000-0000-0000-000000000001', 'counter', 43000, 'Dernier prix');
select t.login('demo_buyer');
select public.negotiation_respond('bbbbbbbb-0000-0000-0000-000000000001', 'accept');
select public.negotiation_confirm('bbbbbbbb-0000-0000-0000-000000000001');
select t.ok((select status from public.negotiations where id='bbbbbbbb-0000-0000-0000-000000000001') = 'accepted', 'une seule confirmation → reste « accepted »');
select t.login('moussa');
select public.negotiation_confirm('bbbbbbbb-0000-0000-0000-000000000001');
select t.ok((select status from public.negotiations where id='bbbbbbbb-0000-0000-0000-000000000001') = 'completed', 'double confirmation → « completed »');
select t.ok(t.n($$select 1 from public.negotiation_events where negotiation_id='bbbbbbbb-0000-0000-0000-000000000001'$$) >= 5, 'historique de l''accord conservé');
-- échange
select t.login('awa');
insert into public.listings(id, seller_id, category_id, title, condition, price, currency_code, country_code, status, exchange_possible)
values ('aaaaaaaa-0000-0000-0000-0000000000e1', t.uid('awa'), (select id from public.categories where slug='ubiquiti-nanostation'), 'NanoStation M5 à échanger', 'used', 25000, 'XOF', 'BF', 'active', true);
select t.login('moussa');
insert into public.negotiations(listing_id, kind, exchange_listing_id, cash_top_up)
select 'aaaaaaaa-0000-0000-0000-0000000000e1', 'exchange', l.id, 5000 from public.listings l where l.seller_id = t.uid('moussa') and l.status='active' limit 1;
select t.ok(t.n($$select 1 from public.negotiations where kind='exchange'$$) = 1, 'proposition d''échange avec complément financier');
select t.fails($$insert into public.negotiations(listing_id, kind, exchange_listing_id) select (select id from public.listings where title='MikroTik hAP ac2 neuf'), 'exchange', l.id from public.listings l where l.seller_id = t.uid('moussa') limit 1$$, 'échange refusé si l''annonce ne l''accepte pas');
-- avis : seulement après transaction conclue
select t.login('demo_buyer');
insert into public.reviews(seller_id, rating, comment) values (t.uid('moussa'), 4, 'Bonne négociation');
select t.ok(t.n($$select 1 from public.reviews where reviewer_id = auth.uid() and comment='Bonne négociation'$$) = 1, 'avis autorisé après négociation conclue');
select t.fails($$insert into public.reviews(seller_id, rating) values (t.uid('awa'), 1)$$, 'avis refusé sans transaction');
rollback;

-- ===================== Demandes de matériel =====================
begin;
select t.login('kofi');
insert into public.wanted_offers(request_id, seller_id, price, currency_code, message)
select id, t.uid('chinedu'), 1, 'XOF', 'x' from public.wanted_requests where title like 'Je recherche une antenne LiteAP%';
select t.ok((select seller_id from public.wanted_offers where message='x') = t.uid('kofi'), 'offre : vendeur = utilisateur connecté (anti-usurpation)');
select t.login('demo_buyer');
update public.wanted_offers set status = 'accepted', price = 1 where message = 'x';
select t.ok((select price from public.wanted_offers where message='x') = 1, 'sanity');
select t.ok((select status from public.wanted_offers where message='x') = 'accepted', 'demandeur : accepte une offre');
select t.login('kofi');
select t.fails($$update public.wanted_offers set status = 'withdrawn' where message='x'$$, 'offre déjà traitée : verrouillée');
rollback;

-- ===================== Panier, commandes, livraison =====================
begin;
select t.login('demo_buyer');
select t.fails($$select public.place_order('pickup')$$, 'panier vide refusé');
select public.cart_set((select id from public.listings where title='MikroTik hAP ac2 neuf'), 2);
select t.fails($$select public.cart_set((select id from public.listings where title='MikroTik hAP ac2 neuf'), 999)$$, 'stock insuffisant refusé');
select t.fails($$insert into public.cart_items(user_id, listing_id, quantity) values (auth.uid(), (select id from public.listings limit 1), 1)$$, 'écriture directe du panier interdite');
select t.fails($$select public.place_order('international', '{"country":"TG","city":"Lomé","line1":"rue 1"}'::jsonb)$$, 'livraison sans règle configurée refusée (frais jamais inventés)');
select t.fails($$select public.place_order('local', '{"country":"BF","city":"Bobo-Dioulasso","line1":"rue 1"}'::jsonb)$$, 'méthode locale incohérente avec les villes refusée');
select public.place_order('intercity', '{"country":"BF","city":"Bobo-Dioulasso","line1":"Secteur 4"}'::jsonb, 'offline', 'Merci') into temp o;
select t.ok((select count(*) from o) = 1, 'commande créée');
select t.ok((select shipping_fee from public.orders where id = (select place_order from o)) = 5000, 'frais de livraison issus de la règle configurée');
select t.ok((select total from public.orders where id = (select place_order from o)) = 85000, 'total = sous-total + frais');
select t.ok((select commission_amount from public.orders where id = (select place_order from o)) = 2400, 'commission 3 % calculée');
select t.ok((select quantity from public.listings where title='MikroTik hAP ac2 neuf') = 13, 'stock décrémenté');
select t.ok(t.n('select 1 from public.cart_items') = 0, 'panier vidé');
select t.blocked($$update public.orders set status = 'completed' where id = (select place_order from o)$$, 'acheteur : ne peut pas modifier une commande directement');
select t.fails($$select public.advance_order((select place_order from o), 'processing')$$, 'acheteur : ne peut pas confirmer à la place du vendeur');
select t.login('kofi');
select t.ok(t.n('select 1 from public.orders') = 0, 'tiers : ne voit pas la commande');
select t.login('ibrahim');
select public.advance_order((select place_order from o), 'processing');
select public.advance_order((select place_order from o), 'shipped', 'TRK-1', 'Transporteur X');
select t.ok((select tracking_number from public.shipments where order_id = (select place_order from o)) = 'TRK-1', 'numéro de suivi enregistré');
select t.fails($$select public.cancel_order((select place_order from o))$$, 'annulation impossible une fois expédiée');
select public.advance_order((select place_order from o), 'delivered');
select t.login('demo_buyer');
select public.advance_order((select place_order from o), 'completed');
select t.ok((select status from public.orders where id = (select place_order from o)) = 'completed', 'cycle complet jusqu''à la confirmation de réception');
select t.ok((select buyer_confirmed_at from public.shipments where order_id = (select place_order from o)) is not null, 'confirmation de réception tracée');
select t.fails($$insert into public.payments(order_id, provider, amount, currency_code) values ((select place_order from o), 'offline', 1, 'XOF')$$, 'paiement : écriture client interdite');
rollback;

begin;
select t.login('demo_buyer');
select public.cart_set((select id from public.listings where title='MikroTik hAP ac2 neuf'), 1);
select public.place_order('pickup') into temp o2;
select t.ok((select quantity from public.listings where title='MikroTik hAP ac2 neuf') = 14, 'stock décrémenté (retrait)');
select public.cancel_order((select place_order from o2), 'Changement d''avis');
select t.ok((select quantity from public.listings where title='MikroTik hAP ac2 neuf') = 15, 'annulation : stock restitué');
select t.ok((select status from public.orders where id=(select place_order from o2)) = 'cancelled', 'commande annulée');
rollback;

-- ===================== Administration =====================
begin;
select t.login('demo_admin');
select t.ok((select (public.admin_stats()->>'users')::int) >= 10, 'superadmin : statistiques');
insert into public.categories(slug, name_fr, name_en) values ('test-cat', 'Test', 'Test');
select t.ok(t.n($$select 1 from public.categories where slug='test-cat'$$) = 1, 'superadmin : crée une catégorie');
insert into public.user_roles(user_id, role, country_code) values (t.uid('moussa'), 'country_admin', 'ML');
select t.ok((select count(*) from public.audit_logs where entity_type = 'user_roles') >= 1, 'attribution de rôle journalisée');
select t.login('demo_buyer');
select t.fails($$insert into public.categories(slug, name_fr, name_en) values ('hack', 'x', 'x')$$, 'simple utilisateur : ne crée pas de catégorie');
select t.blocked($$update public.plans set price = 0$$, 'simple utilisateur : ne change pas les tarifs');
select t.ok((select price from public.plans where code='shop_pro') = 3000, 'tarifs inchangés');
rollback;

-- ===================== Signalements =====================
begin;
select t.login('kofi');
insert into public.reports(reporter_id, target_type, target_id, reason) values (t.uid('kofi'), 'user', t.uid('awa')::text, 'spam');
select t.ok(t.n('select 1 from public.reports') = 1, 'un utilisateur ne voit que ses signalements');
select t.login('demo_admin');
select t.ok(t.n('select 1 from public.reports') = 2, 'staff : voit tous les signalements');
rollback;

-- ===================== Storage =====================
begin;
select t.login('kofi');
insert into storage.objects(bucket_id, name) values ('listing-media', t.uid('kofi')::text || '/a.jpg');
select t.fails($$insert into storage.objects(bucket_id, name) values ('listing-media', t.uid('awa')::text || '/a.jpg')$$, 'upload dans le dossier d''un autre refusé');
select t.fails($$insert into storage.objects(bucket_id, name) values ('chat-images', 'x/y/z.jpg')$$, 'image de chat hors conversation refusée');
rollback;

-- ===================== RGPD : anonymisation =====================
begin;
select t.login('demo_buyer');
select t.fails($$select public.anonymize_user(t.uid('awa'))$$, 'un utilisateur ne peut pas anonymiser un autre compte');
select t.login('demo_admin');
select public.anonymize_user(t.uid('awa'));
select t.root();
select t.ok((select display_name from public.profiles where id = t.uid('awa')) = 'Compte supprimé', 'profil anonymisé');
select t.ok((select count(*) from public.private_profiles where id = t.uid('awa')) = 0, 'données privées supprimées');
select t.ok(not exists (select 1 from public.listings where seller_id = t.uid('awa') and status = 'active'), 'annonces retirées');
select t.ok(public.user_has_orders(t.uid('ibrahim')), 'compte avec commandes détecté (anonymisation plutôt que suppression)');
rollback;
