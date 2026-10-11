-- WiFiMarket — conformité : suppression / anonymisation de compte (demandes de suppression de données)
-- Les commandes sont conservées (obligations comptables et litiges) : un compte ayant des commandes est anonymisé,
-- un compte sans commande peut être supprimé complètement (suppression de l'utilisateur d'authentification en cascade).

create or replace function public.user_has_orders(p_user uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.orders where buyer_id = p_user or seller_id = p_user)
$$;

create or replace function public.anonymize_user(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (auth.uid() is null or public.is_superadmin()) then raise exception 'not_allowed'; end if;
  perform set_config('wm.bypass', '1', true);
  delete from public.private_profiles where id = p_user;
  delete from public.favorites where user_id = p_user;
  delete from public.saved_searches where user_id = p_user;
  delete from public.notifications where user_id = p_user;
  delete from public.cart_items where user_id = p_user;
  delete from public.shop_members where user_id = p_user;
  delete from public.wanted_requests where requester_id = p_user and status <> 'fulfilled';
  update public.messages set body = '[message supprimé]', image_path = null where sender_id = p_user;
  update public.listings set status = 'removed', rejection_reason = 'Compte supprimé' where seller_id = p_user;
  update public.profiles
     set display_name = 'Compte supprimé', avatar_url = null, bio = null, city = null, show_whatsapp = false, is_suspended = true
   where id = p_user;
  perform set_config('wm.bypass', '', true);
end $$;

revoke execute on function public.anonymize_user(uuid), public.user_has_orders(uuid) from public, anon;
grant execute on function public.anonymize_user(uuid), public.user_has_orders(uuid) to authenticated, service_role;
