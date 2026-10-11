-- WiFiMarket — Row Level Security (Phase 1)
-- Principe : tout est fermé par défaut ; on ouvre explicitement. Les écritures sensibles
-- (commandes, paiements, conversations, notifications) passent par des fonctions SECURITY DEFINER
-- ou par le rôle service (webhooks serveur).

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role in ('country_admin','superadmin'))
$$;

-- Active RLS partout
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;
end $$;

-- Les anonymes ne font que lire
revoke insert, update, delete on all tables in schema public from anon;
revoke all on public.payments, public.payment_events, public.audit_logs from anon;
-- Écritures interdites en direct aux clients connectés (passent par RPC / service role)
revoke insert, update, delete on public.order_items, public.payments, public.payment_events,
  public.audit_logs, public.carts, public.cart_items, public.conversations, public.notifications
  from authenticated;
revoke insert, delete on public.orders, public.shipments from authenticated;
-- Les notifications restent modifiables (marquer comme lue / supprimer) par leur propriétaire
grant update (read_at), delete on public.notifications to authenticated;

-- ---------------------------------------------------------------- Référentiels (lecture publique)
create policy ref_read on public.currencies for select using (true);
create policy ref_read on public.countries for select using (true);
create policy ref_read on public.cities for select using (true);
create policy ref_read on public.categories for select using (true);
create policy ref_read on public.brands for select using (true);
create policy ref_read on public.product_models for select using (true);
create policy ref_read on public.platform_settings for select using (true);

create policy ref_write on public.currencies for all using (public.is_superadmin()) with check (public.is_superadmin());
create policy ref_write on public.countries for all using (public.is_superadmin()) with check (public.is_superadmin());
create policy ref_write on public.cities for all using (public.is_admin()) with check (public.is_admin());
create policy ref_write on public.categories for all using (public.is_admin()) with check (public.is_admin());
create policy ref_write on public.brands for all using (public.is_admin()) with check (public.is_admin());
create policy ref_write on public.product_models for all using (public.is_admin()) with check (public.is_admin());
create policy ref_write on public.platform_settings for all using (public.is_superadmin()) with check (public.is_superadmin());

create policy plans_read on public.plans for select using (enabled or public.is_admin());
create policy plans_write on public.plans for all using (public.is_superadmin()) with check (public.is_superadmin());

create policy providers_read on public.payment_providers for select using (enabled or public.is_admin());
create policy providers_write on public.payment_providers for all using (public.is_superadmin()) with check (public.is_superadmin());

create policy shiprules_read on public.shipping_rules for select using (enabled or public.is_admin());
create policy shiprules_write on public.shipping_rules for all using (public.is_admin()) with check (public.is_admin());

create policy kw_all on public.banned_keywords for all using (public.is_staff()) with check (public.is_admin());

-- ---------------------------------------------------------------- Profils
create policy profiles_read on public.profiles for select using (true);
create policy profiles_update on public.profiles for update
  using (id = auth.uid() or public.is_staff()) with check (id = auth.uid() or public.is_staff());

create policy private_select on public.private_profiles for select using (id = auth.uid());
create policy private_insert on public.private_profiles for insert with check (id = auth.uid());
create policy private_update on public.private_profiles for update using (id = auth.uid()) with check (id = auth.uid());

create policy roles_read on public.user_roles for select using (user_id = auth.uid() or public.is_superadmin());
create policy roles_write on public.user_roles for all using (public.is_superadmin()) with check (public.is_superadmin());

-- ---------------------------------------------------------------- Boutiques
create policy shops_read on public.shops for select
  using (is_active or public.is_shop_member(id) or public.is_staff());
create policy shops_insert on public.shops for insert with check (owner_id = auth.uid());
create policy shops_update on public.shops for update
  using (public.is_shop_member(id) or public.is_staff()) with check (public.is_shop_member(id) or public.is_staff());
create policy shops_delete on public.shops for delete using (owner_id = auth.uid() or public.is_superadmin());

create policy members_read on public.shop_members for select
  using (user_id = auth.uid() or public.is_shop_member(shop_id) or public.is_staff());
create policy members_insert on public.shop_members for insert
  with check (exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid()));
create policy members_delete on public.shop_members for delete
  using (exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid()) and role <> 'owner');

-- ---------------------------------------------------------------- Annonces
create policy listings_read on public.listings for select using (
  status in ('active','sold')
  or seller_id = auth.uid()
  or public.is_shop_member(shop_id)
  or public.can_moderate(country_code)
);
create policy listings_insert on public.listings for insert with check (
  seller_id = auth.uid() and status in ('draft','active','paused','pending_review')
  and (shop_id is null or public.is_shop_member(shop_id))
);
create policy listings_update on public.listings for update
  using (seller_id = auth.uid() or public.is_shop_member(shop_id) or public.can_moderate(country_code))
  with check (seller_id = auth.uid() or public.is_shop_member(shop_id) or public.can_moderate(country_code));
create policy listings_delete on public.listings for delete using (seller_id = auth.uid() or public.is_superadmin());

create policy media_read on public.listing_media for select
  using (exists (select 1 from public.listings l where l.id = listing_id));
create policy media_write on public.listing_media for all
  using (exists (select 1 from public.listings l where l.id = listing_id and (l.seller_id = auth.uid() or public.is_shop_member(l.shop_id) or public.is_staff())))
  with check (exists (select 1 from public.listings l where l.id = listing_id and (l.seller_id = auth.uid() or public.is_shop_member(l.shop_id) or public.is_staff())));

create policy attrs_read on public.listing_attributes for select
  using (exists (select 1 from public.listings l where l.id = listing_id));
create policy attrs_write on public.listing_attributes for all
  using (exists (select 1 from public.listings l where l.id = listing_id and (l.seller_id = auth.uid() or public.is_shop_member(l.shop_id) or public.is_staff())))
  with check (exists (select 1 from public.listings l where l.id = listing_id and (l.seller_id = auth.uid() or public.is_shop_member(l.shop_id) or public.is_staff())));

create policy favorites_own on public.favorites for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy saved_searches_own on public.saved_searches for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------- Demandes de matériel
create policy wanted_read on public.wanted_requests for select
  using (status <> 'removed' or requester_id = auth.uid() or public.is_staff());
create policy wanted_insert on public.wanted_requests for insert with check (requester_id = auth.uid() and status = 'open');
create policy wanted_update on public.wanted_requests for update
  using (requester_id = auth.uid() or public.is_staff()) with check (requester_id = auth.uid() or public.is_staff());
create policy wanted_delete on public.wanted_requests for delete using (requester_id = auth.uid() or public.is_superadmin());

create policy offers_read on public.wanted_offers for select using (
  seller_id = auth.uid() or public.is_staff()
  or exists (select 1 from public.wanted_requests r where r.id = request_id and r.requester_id = auth.uid()));
create policy offers_insert on public.wanted_offers for insert with check (seller_id = auth.uid());
create policy offers_update on public.wanted_offers for update using (
  seller_id = auth.uid()
  or exists (select 1 from public.wanted_requests r where r.id = request_id and r.requester_id = auth.uid()));

create or replace function public.wanted_offers_before_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_req uuid; v_status text := new.status;
begin
  select requester_id into v_req from public.wanted_requests where id = old.request_id;
  if auth.uid() is null then return new; end if;
  if auth.uid() = v_req then
    -- le demandeur ne peut qu'accepter ou refuser
    if v_status not in ('accepted','declined') then raise exception 'invalid_status'; end if;
    new.price := old.price; new.currency_code := old.currency_code; new.message := old.message;
    new.condition := old.condition; new.listing_id := old.listing_id; new.request_id := old.request_id;
    new.seller_id := old.seller_id;
  else
    -- le vendeur peut modifier son offre ou la retirer tant qu'elle n'est pas traitée
    if old.status <> 'sent' then raise exception 'offer_locked'; end if;
    if v_status not in ('sent','withdrawn') then raise exception 'invalid_status'; end if;
    new.request_id := old.request_id; new.seller_id := old.seller_id;
  end if;
  return new;
end $$;
create trigger trg_wanted_offers_update before update on public.wanted_offers
  for each row execute function public.wanted_offers_before_update();

-- ---------------------------------------------------------------- Messagerie & négociations
create policy conv_read on public.conversations for select using (auth.uid() in (user_a, user_b));
create policy msg_read on public.messages for select using (public.is_conversation_member(conversation_id));
create policy msg_insert on public.messages for insert
  with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id));
create policy blocks_own on public.user_blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy nego_read on public.negotiations for select using (auth.uid() in (buyer_id, seller_id));
create policy nego_insert on public.negotiations for insert with check (buyer_id = auth.uid());
create policy nego_events_read on public.negotiation_events for select
  using (exists (select 1 from public.negotiations n where n.id = negotiation_id and auth.uid() in (n.buyer_id, n.seller_id)));

-- ---------------------------------------------------------------- Panier / commandes / paiements / livraisons
create policy carts_read on public.carts for select using (user_id = auth.uid());
create policy cart_items_read on public.cart_items for select using (user_id = auth.uid());

create policy orders_read on public.orders for select using (auth.uid() in (buyer_id, seller_id) or public.is_staff());
create policy orders_admin_update on public.orders for update using (public.is_admin()) with check (public.is_admin());
create policy order_items_read on public.order_items for select
  using (exists (select 1 from public.orders o where o.id = order_id and (auth.uid() in (o.buyer_id, o.seller_id) or public.is_staff())));
create policy payments_read on public.payments for select
  using (exists (select 1 from public.orders o where o.id = order_id and (auth.uid() in (o.buyer_id, o.seller_id) or public.is_staff())));
create policy payment_events_admin on public.payment_events for select using (public.is_admin());
create policy shipments_read on public.shipments for select
  using (exists (select 1 from public.orders o where o.id = order_id and (auth.uid() in (o.buyer_id, o.seller_id) or public.is_staff())));
create policy shipments_admin_update on public.shipments for update using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------- Avis, signalements, litiges
create policy reviews_read on public.reviews for select using (true);
create policy reviews_insert on public.reviews for insert with check (reviewer_id = auth.uid());
create policy reviews_delete on public.reviews for delete using (reviewer_id = auth.uid() or public.is_staff());

create policy reports_insert on public.reports for insert with check (reporter_id = auth.uid());
create policy reports_read on public.reports for select using (reporter_id = auth.uid() or public.is_staff());
create policy reports_update on public.reports for update using (public.is_staff()) with check (public.is_staff());

create policy disputes_read on public.disputes for select using (
  public.is_staff() or exists (select 1 from public.orders o where o.id = order_id and auth.uid() in (o.buyer_id, o.seller_id)));
create policy disputes_update on public.disputes for update using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------- Monétisation
create policy subs_read on public.subscriptions for select using (public.is_shop_member(shop_id) or public.is_staff());
create policy subs_insert on public.subscriptions for insert
  with check (public.is_shop_member(shop_id) and status = 'pending');
create policy subs_admin on public.subscriptions for update using (public.is_admin()) with check (public.is_admin());

create policy promos_read on public.promotions for select using (requested_by = auth.uid() or public.is_staff());
create policy promos_insert on public.promotions for insert with check (
  requested_by = auth.uid() and status = 'pending'
  and exists (select 1 from public.listings l where l.id = listing_id and l.seller_id = auth.uid()));
create policy promos_admin on public.promotions for update using (public.is_admin()) with check (public.is_admin());

-- Activation d'une promotion : met l'annonce en avant (uniquement par un admin, après paiement vérifié)
create or replace function public.promotions_apply() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_days int;
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status <> 'active') then
    select duration_days into v_days from public.plans where code = new.plan_code;
    new.starts_at := coalesce(new.starts_at, now());
    new.ends_at := coalesce(new.ends_at, new.starts_at + make_interval(days => v_days));
    perform set_config('wm.bypass', '1', true);
    update public.listings set is_sponsored = true, sponsored_until = new.ends_at where id = new.listing_id;
    perform set_config('wm.bypass', '', true);
  end if;
  return new;
end $$;
create trigger trg_promotions_apply before insert or update on public.promotions
  for each row execute function public.promotions_apply();

create or replace function public.subscriptions_apply() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_days int; v_plan text;
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status <> 'active') then
    select duration_days into v_days from public.plans where code = new.plan_code;
    new.starts_at := coalesce(new.starts_at, now());
    new.ends_at := coalesce(new.ends_at, new.starts_at + make_interval(days => v_days));
    v_plan := case new.plan_code when 'shop_premium' then 'premium' when 'shop_pro' then 'pro' else 'free' end;
    perform set_config('wm.bypass', '1', true);
    update public.shops set plan = v_plan where id = new.shop_id;
    perform set_config('wm.bypass', '', true);
  end if;
  return new;
end $$;
create trigger trg_subscriptions_apply before insert or update on public.subscriptions
  for each row execute function public.subscriptions_apply();

-- ---------------------------------------------------------------- Notifications, audit, RGPD
create policy notif_read on public.notifications for select using (user_id = auth.uid());
create policy notif_update on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notif_delete on public.notifications for delete using (user_id = auth.uid());

create policy audit_read on public.audit_logs for select using (public.is_admin());

create policy deletion_insert on public.data_deletion_requests for insert with check (user_id = auth.uid() and status = 'pending');
create policy deletion_read on public.data_deletion_requests for select using (user_id = auth.uid() or public.is_admin());
create policy deletion_update on public.data_deletion_requests for update using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------- Droits d'exécution des fonctions
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.has_role(text, text), public.is_superadmin(), public.is_staff(), public.is_admin(),
  public.can_moderate(text), public.is_shop_member(uuid), public.is_conversation_member(uuid), public.are_blocked(uuid, uuid),
  public.increment_listing_views(uuid), public.slugify(text), public.immutable_unaccent(text),
  public.setting_num(text, numeric), public.setting_bool(text, boolean), public.wm_bypass(), public.text_has_banned_keyword(text)
  to anon, authenticated;
grant execute on function public.renew_listing(uuid), public.start_conversation(uuid, uuid, uuid),
  public.mark_conversation_read(uuid), public.get_whatsapp(uuid), public.negotiation_respond(uuid, text, numeric, text),
  public.negotiation_confirm(uuid), public.cart_set(uuid, int), public.place_order(text, jsonb, text, text),
  public.cancel_order(uuid, text), public.advance_order(uuid, text, text, text), public.open_dispute(uuid, text),
  public.admin_stats(), public.shop_stats(uuid) to authenticated;
grant execute on function public.expire_listings(), public.restock_order(uuid) to service_role;
