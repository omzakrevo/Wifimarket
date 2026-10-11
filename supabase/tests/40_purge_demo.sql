\set ON_ERROR_STOP on
set client_min_messages = notice;

-- ===================== Suppression des données de démonstration =====================
begin;
-- un superadmin réel (non démo) et un vendeur réel avec une annonce
select t.root();
insert into auth.users (id, instance_id, aud, role, email, raw_app_meta_data, raw_user_meta_data)
  values ('aaaaaaaa-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','vrai.admin@example.com','{}','{}'),
         ('aaaaaaaa-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','vrai.vendeur@example.com','{}','{}');
insert into public.user_roles (user_id, role) values ('aaaaaaaa-0000-0000-0000-000000000001','superadmin');
insert into public.listings (id, seller_id, category_id, title, condition, price, currency_code, country_code, city, status)
  select 'aaaaaaaa-0000-0000-0000-0000000000a1','aaaaaaaa-0000-0000-0000-000000000002', id, 'Annonce réelle', 'used', 1000, 'XOF', 'BF', 'Ouaga', 'active'
  from public.categories limit 1;

-- refus : acheteur simple, compte de démo
select t.login('demo_buyer');
select t.fails($$select public.purge_demo_data()$$, 'acheteur : ne peut pas purger');
select t.fails($$select public.demo_data_counts()$$, 'acheteur : ne voit pas les compteurs');
select t.login('demo_admin');
select t.fails($$select public.purge_demo_data()$$, 'superadmin de démo : ne peut pas se supprimer lui-même');
select t.anon();
select t.fails($$select public.purge_demo_data()$$, 'anonyme : ne peut pas purger');

-- succès : vrai superadmin
select t.root();
select set_config('request.jwt.claims', json_build_object('sub','aaaaaaaa-0000-0000-0000-000000000001','role','authenticated')::text, true);
set local role authenticated;
select t.ok((select (public.demo_data_counts()->>'listings')::int) = 30, 'compteurs : 30 annonces de démo');
select t.ok((select (public.purge_demo_data()->>'users')::int) = 10, 'purge : 10 comptes de démo annoncés');
reset role;
select t.ok(t.n('select 1 from public.profiles where is_demo') = 0, 'plus aucun profil de démo');
select t.ok(t.n('select 1 from public.listings where is_demo') = 0, 'plus aucune annonce de démo');
select t.ok(t.n('select 1 from public.shops where is_demo') = 0, 'plus aucune boutique de démo');
select t.ok(t.n('select 1 from public.orders') = 0, 'plus aucune commande de démo');
select t.ok(t.n($$select 1 from auth.users where email like '%@demo.wifimarket.test'$$) = 0, 'plus aucun compte de démo');
select t.ok(t.n($$select 1 from public.shipping_rules where carrier = 'DEMO'$$) = 0, 'tarif de démo supprimé');
select t.ok(t.n($$select 1 from public.listings where id = 'aaaaaaaa-0000-0000-0000-0000000000a1'$$) = 1, 'l''annonce réelle est intacte');
select t.ok(t.n($$select 1 from auth.users where email = 'vrai.vendeur@example.com'$$) = 1, 'le compte réel est intact');
rollback;
