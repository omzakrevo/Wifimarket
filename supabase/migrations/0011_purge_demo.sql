-- WiFiMarket — suppression des données de démonstration (bouton « Supprimer les données de test » en administration).
-- Ne touche que les lignes marquées is_demo (comptes @demo.wifimarket.test, leurs annonces, boutiques, demandes,
-- conversations, commandes…) et le tarif de livraison « DEMO ». Les données réelles ne sont jamais concernées.
-- Réservée aux superadmins ; un compte de démonstration ne peut pas lancer la suppression (il se supprimerait lui-même).

create or replace function public.demo_data_counts() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_superadmin() then raise exception 'not_allowed'; end if;
  return jsonb_build_object(
    'users',    (select count(*) from public.profiles where is_demo),
    'shops',    (select count(*) from public.shops where is_demo),
    'listings', (select count(*) from public.listings where is_demo),
    'wanted',   (select count(*) from public.wanted_requests where is_demo),
    'orders',   (select count(*) from public.orders where is_demo));
end $$;

create or replace function public.purge_demo_data() returns jsonb
language plpgsql security definer set search_path = public, auth as $$
declare r jsonb;
begin
  if not public.is_superadmin() then raise exception 'not_allowed'; end if;
  if exists (select 1 from public.profiles where id = auth.uid() and is_demo) then
    raise exception 'demo_account_cannot_purge';
  end if;
  r := public.demo_data_counts();
  perform set_config('wm.bypass', '1', true);
  delete from public.orders where is_demo;
  delete from public.conversations where is_demo;
  delete from public.wanted_requests where is_demo;
  delete from public.listings where is_demo;
  delete from public.shops where is_demo;
  delete from public.shipping_rules where carrier = 'DEMO';
  -- la suppression des utilisateurs d'authentification emporte profils, rôles, favoris, avis, signalements… (cascade)
  delete from auth.users where id in (select id from public.profiles where is_demo);
  perform set_config('wm.bypass', '', true);
  return r;
end $$;

revoke execute on function public.demo_data_counts(), public.purge_demo_data() from public, anon;
grant execute on function public.demo_data_counts(), public.purge_demo_data() to authenticated, service_role;
