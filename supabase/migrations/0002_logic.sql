-- WiFiMarket — logique métier côté base : rôles, modération, messagerie, négociations, commandes, audit

-- ---------------------------------------------------------------------------
-- Rôles (vérifiés côté serveur : fonctions SECURITY DEFINER utilisées par RLS)
-- ---------------------------------------------------------------------------
create or replace function public.has_role(r text, c text default null) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role = r
      and (c is null or ur.country_code is null or ur.country_code = c)
  )
$$;

create or replace function public.is_superadmin() returns boolean
language sql stable security definer set search_path = public as $$
  select public.has_role('superadmin')
$$;

create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role in ('moderator','country_admin','superadmin')
  )
$$;

-- Peut modérer le contenu d'un pays donné
create or replace function public.can_moderate(c text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid()
      and (ur.role = 'superadmin'
        or (ur.role in ('moderator','country_admin') and (ur.country_code is null or ur.country_code = c)))
  )
$$;

create or replace function public.is_shop_member(p_shop uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.shop_members sm where sm.shop_id = p_shop and sm.user_id = auth.uid())
$$;

create or replace function public.is_conversation_member(p_conv uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.conversations c
    where c.id = p_conv and auth.uid() in (c.user_a, c.user_b)
  )
$$;

create or replace function public.setting_num(p_key text, p_default numeric) returns numeric
language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::numeric from public.platform_settings where key = p_key), p_default)
$$;

create or replace function public.setting_bool(p_key text, p_default boolean) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select (value #>> '{}')::boolean from public.platform_settings where key = p_key), p_default)
$$;

-- Drapeau transactionnel : les RPC internes peuvent contourner les verrous anti-triche des triggers
create or replace function public.wm_bypass() returns boolean
language sql stable as $$ select coalesce(current_setting('wm.bypass', true), '') = '1' $$;

-- ---------------------------------------------------------------------------
-- Création automatique du profil à l'inscription
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_country text;
begin
  v_name := nullif(trim(coalesce(new.raw_user_meta_data->>'display_name', new.raw_user_meta_data->>'full_name', split_part(coalesce(new.email,''),'@',1), '')), '');
  if v_name is null or char_length(v_name) < 2 then v_name := 'Utilisateur ' || substr(new.id::text, 1, 6); end if;
  v_name := left(v_name, 60);
  v_country := upper(nullif(new.raw_user_meta_data->>'country_code',''));
  if v_country is not null and not exists (select 1 from public.countries where code = v_country) then v_country := null; end if;
  insert into public.profiles (id, display_name, avatar_url, country_code, city)
  values (new.id, v_name, new.raw_user_meta_data->>'avatar_url', v_country, nullif(new.raw_user_meta_data->>'city',''));
  insert into public.private_profiles (id, phone) values (new.id, new.phone);
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Les utilisateurs ne peuvent pas modifier leurs champs de confiance
create or replace function public.profiles_guard() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_staff() and not public.wm_bypass() then
    new.verification_status := old.verification_status;
    new.is_suspended := old.is_suspended;
    new.is_demo := old.is_demo;
  end if;
  return new;
end $$;
create trigger trg_profiles_guard before update on public.profiles
  for each row execute function public.profiles_guard();

-- ---------------------------------------------------------------------------
-- Annonces : slug, modération, anti-fraude, limitation de spam
-- ---------------------------------------------------------------------------
create or replace function public.text_has_banned_keyword(p_text text) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1 from public.banned_keywords k
    where position(lower(extensions.unaccent(k.keyword)) in lower(extensions.unaccent(coalesce(p_text,'')))) > 0
  )
$$;

create or replace function public.listings_before_write() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_user uuid := auth.uid();
  v_end_user boolean := v_user is not null and not public.is_staff() and not public.wm_bypass();
  v_suspended boolean;
  v_recent int;
  v_flagged boolean;
  v_duration int;
begin
  if tg_op = 'INSERT' then
    if new.slug is null or new.slug = '' then
      new.slug := left(public.slugify(new.title), 80) || '-' || substr(replace(new.id::text,'-',''),1,8);
    end if;
  else
    new.slug := old.slug;
    new.seller_id := old.seller_id;
  end if;

  if v_end_user then
    select is_suspended into v_suspended from public.profiles where id = new.seller_id;
    if coalesce(v_suspended, false) then raise exception 'account_suspended'; end if;

    if tg_op = 'INSERT' then
      select count(*) into v_recent from public.listings
        where seller_id = new.seller_id and created_at > now() - interval '24 hours';
      if v_recent >= public.setting_num('max_listings_per_day', 30) then raise exception 'rate_limit_listings'; end if;
      new.is_sponsored := false; new.sponsored_until := null; new.views_count := 0;
      new.rejection_reason := null; new.published_at := null; new.expires_at := null; new.is_demo := false;
    else
      -- champs réservés au système / à la modération
      new.is_sponsored := old.is_sponsored; new.sponsored_until := old.sponsored_until;
      new.views_count := old.views_count; new.published_at := old.published_at;
      new.expires_at := old.expires_at; new.rejection_reason := old.rejection_reason; new.is_demo := old.is_demo;
      if old.status = 'removed' and new.status <> 'removed' then raise exception 'listing_removed_by_moderation'; end if;
      if new.status in ('pending_review','rejected','expired','removed') and new.status <> old.status then
        -- ces statuts sont posés par le système : on conserve le statut courant
        new.status := old.status;
      end if;
    end if;

    -- Demande de publication : contrôle automatique
    if new.status = 'active' and (tg_op = 'INSERT' or old.status <> 'active'
        or new.title is distinct from old.title or new.description is distinct from old.description) then
      v_flagged := public.text_has_banned_keyword(new.title || ' ' || coalesce(new.description,'') || ' ' || coalesce(new.defects,''));
      if v_flagged or not public.setting_bool('auto_approve_listings', true)
         or (tg_op = 'UPDATE' and old.status in ('rejected','pending_review')) then
        new.status := 'pending_review';
      else
        new.published_at := coalesce(new.published_at, now());
        v_duration := public.setting_num('listing_duration_days', 60)::int;
        new.expires_at := coalesce(new.expires_at, now() + make_interval(days => v_duration));
      end if;
    end if;
  else
    if new.status = 'active' then
      new.published_at := coalesce(new.published_at, now());
      new.expires_at := coalesce(new.expires_at, now() + make_interval(days => public.setting_num('listing_duration_days', 60)::int));
    end if;
  end if;
  return new;
end $$;
create trigger trg_listings_before before insert or update on public.listings
  for each row execute function public.listings_before_write();

-- Alertes de recherche enregistrée lors de la publication
create or replace function public.listings_notify_saved_searches() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status <> 'active') then
    insert into public.notifications (user_id, type, title, body, link)
    select ss.user_id, 'saved_search',
           'Nouvelle annonce : ' || new.title,
           ss.label, '/annonces/' || new.slug
    from public.saved_searches ss
    where ss.notify and ss.user_id <> new.seller_id
      and (ss.query is null or ss.query = '' or new.search @@ plainto_tsquery('simple', public.immutable_unaccent(ss.query)))
      and (ss.category_id is null or ss.category_id = new.category_id
           or exists (select 1 from public.categories c where c.id = new.category_id and c.parent_id = ss.category_id))
      and (ss.brand_id is null or ss.brand_id = new.brand_id)
      and (ss.country_code is null or ss.country_code = new.country_code)
      and (ss.city is null or lower(ss.city) = lower(coalesce(new.city,'')))
      and (ss.condition is null or ss.condition = new.condition)
      and (ss.currency_code is null or ss.currency_code = new.currency_code)
      and (ss.min_price is null or new.price >= ss.min_price)
      and (ss.max_price is null or new.price <= ss.max_price);
  end if;
  return null;
end $$;
create trigger trg_listings_saved_search after insert or update of status on public.listings
  for each row execute function public.listings_notify_saved_searches();

-- Notification au vendeur quand une annonce passe en revue / est refusée
create or replace function public.listings_notify_owner() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'rejected' then
      insert into public.notifications (user_id, type, title, body, link)
      values (new.seller_id, 'listing_rejected', 'Annonce refusée : ' || new.title, new.rejection_reason, '/compte/annonces');
    elsif new.status = 'active' and old.status = 'pending_review' then
      insert into public.notifications (user_id, type, title, body, link)
      values (new.seller_id, 'listing_approved', 'Annonce publiée : ' || new.title, null, '/annonces/' || new.slug);
    elsif new.status = 'removed' then
      insert into public.notifications (user_id, type, title, body, link)
      values (new.seller_id, 'listing_removed', 'Annonce retirée : ' || new.title, new.rejection_reason, '/compte/annonces');
    end if;
  end if;
  return null;
end $$;
create trigger trg_listings_notify_owner after update of status on public.listings
  for each row execute function public.listings_notify_owner();

create or replace function public.renew_listing(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_l public.listings;
begin
  select * into v_l from public.listings where id = p_id;
  if not found or v_l.seller_id <> auth.uid() then raise exception 'not_allowed'; end if;
  if v_l.status not in ('active','expired','paused') then raise exception 'invalid_status'; end if;
  perform set_config('wm.bypass', '1', true);
  update public.listings
     set status = 'active', published_at = coalesce(published_at, now()),
         expires_at = now() + make_interval(days => public.setting_num('listing_duration_days', 60)::int)
   where id = p_id;
  perform set_config('wm.bypass', '', true);
end $$;

create or replace function public.increment_listing_views(p_id uuid) returns void
language sql security definer set search_path = public as $$
  update public.listings set views_count = views_count + 1 where id = p_id and status = 'active'
$$;

-- À planifier (pg_cron, Edge Function planifiée ou tâche Netlify) : expire les annonces échues
create or replace function public.expire_listings() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform set_config('wm.bypass', '1', true);
  update public.listings set status = 'expired' where status = 'active' and expires_at is not null and expires_at < now();
  get diagnostics n = row_count;
  update public.listings set is_sponsored = false where is_sponsored and sponsored_until is not null and sponsored_until < now();
  perform set_config('wm.bypass', '', true);
  return n;
end $$;
revoke execute on function public.expire_listings() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Boutiques : le créateur devient propriétaire
-- ---------------------------------------------------------------------------
create or replace function public.shops_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.shop_members (shop_id, user_id, role) values (new.id, new.owner_id, 'owner');
  return null;
end $$;
create trigger trg_shops_after_insert after insert on public.shops
  for each row execute function public.shops_after_insert();

create or replace function public.shops_guard() returns trigger
language plpgsql as $$
begin
  if auth.uid() is not null and not public.is_staff() and not public.wm_bypass() then
    if tg_op = 'INSERT' then
      new.plan := 'free'; new.verification_status := 'unverified'; new.is_active := true; new.is_demo := false;
    else
      new.plan := old.plan; new.verification_status := old.verification_status;
      new.is_active := old.is_active; new.owner_id := old.owner_id; new.is_demo := old.is_demo;
    end if;
  end if;
  return new;
end $$;
create trigger trg_shops_guard before insert or update on public.shops
  for each row execute function public.shops_guard();

-- Statistiques de boutique (réservées aux membres)
create or replace function public.shop_stats(p_shop uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.is_shop_member(p_shop) or public.is_staff()) then raise exception 'not_allowed'; end if;
  return jsonb_build_object(
    'listings_active', (select count(*) from public.listings where shop_id = p_shop and status = 'active'),
    'listings_total', (select count(*) from public.listings where shop_id = p_shop),
    'views_total', (select coalesce(sum(views_count),0) from public.listings where shop_id = p_shop),
    'favorites_total', (select count(*) from public.favorites f join public.listings l on l.id = f.listing_id where l.shop_id = p_shop),
    'orders_total', (select count(*) from public.orders where shop_id = p_shop),
    'rating_avg', (select round(avg(rating)::numeric, 2) from public.reviews where shop_id = p_shop),
    'rating_count', (select count(*) from public.reviews where shop_id = p_shop)
  );
end $$;

-- ---------------------------------------------------------------------------
-- Messagerie
-- ---------------------------------------------------------------------------
create or replace function public.are_blocked(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

create or replace function public.start_conversation(p_other uuid, p_listing uuid default null, p_request uuid default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_id uuid; v_susp boolean;
begin
  if v_me is null then raise exception 'not_authenticated'; end if;
  if p_other is null or p_other = v_me then raise exception 'invalid_recipient'; end if;
  if not exists (select 1 from public.profiles where id = p_other) then raise exception 'invalid_recipient'; end if;
  select is_suspended into v_susp from public.profiles where id = v_me;
  if v_susp then raise exception 'account_suspended'; end if;
  if public.are_blocked(v_me, p_other) then raise exception 'blocked'; end if;
  select id into v_id from public.conversations c
   where least(c.user_a, c.user_b) = least(v_me, p_other) and greatest(c.user_a, c.user_b) = greatest(v_me, p_other)
     and coalesce(c.listing_id, '00000000-0000-0000-0000-000000000000') = coalesce(p_listing, '00000000-0000-0000-0000-000000000000')
     and coalesce(c.request_id, '00000000-0000-0000-0000-000000000000') = coalesce(p_request, '00000000-0000-0000-0000-000000000000');
  if v_id is null then
    insert into public.conversations (user_a, user_b, listing_id, request_id) values (v_me, p_other, p_listing, p_request)
    returning id into v_id;
  end if;
  return v_id;
end $$;

create or replace function public.messages_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_conv public.conversations; v_other uuid; v_recent int; v_susp boolean;
begin
  select * into v_conv from public.conversations where id = new.conversation_id;
  if not found then raise exception 'conversation_not_found'; end if;
  if auth.uid() is not null then
    new.sender_id := auth.uid();
    new.read_at := null;
  end if;
  if new.sender_id not in (v_conv.user_a, v_conv.user_b) then raise exception 'not_a_participant'; end if;
  v_other := case when new.sender_id = v_conv.user_a then v_conv.user_b else v_conv.user_a end;
  if public.are_blocked(new.sender_id, v_other) then raise exception 'blocked'; end if;
  select is_suspended into v_susp from public.profiles where id = new.sender_id;
  if v_susp then raise exception 'account_suspended'; end if;
  select count(*) into v_recent from public.messages
    where sender_id = new.sender_id and created_at > now() - interval '1 minute';
  if v_recent >= public.setting_num('max_messages_per_minute', 20) then raise exception 'rate_limit_messages'; end if;
  return new;
end $$;
create trigger trg_messages_before before insert on public.messages
  for each row execute function public.messages_before_insert();

create or replace function public.messages_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_conv public.conversations; v_other uuid; v_name text;
begin
  select * into v_conv from public.conversations where id = new.conversation_id;
  update public.conversations set last_message_at = new.created_at where id = new.conversation_id;
  v_other := case when new.sender_id = v_conv.user_a then v_conv.user_b else v_conv.user_a end;
  select display_name into v_name from public.profiles where id = new.sender_id;
  if not exists (select 1 from public.notifications
      where user_id = v_other and type = 'message' and link = '/messages/' || new.conversation_id and read_at is null) then
    insert into public.notifications (user_id, type, title, body, link)
    values (v_other, 'message', 'Nouveau message de ' || coalesce(v_name,'un utilisateur'),
            left(coalesce(nullif(new.body,''), 'Image'), 120), '/messages/' || new.conversation_id);
  end if;
  return null;
end $$;
create trigger trg_messages_after after insert on public.messages
  for each row execute function public.messages_after_insert();

create or replace function public.mark_conversation_read(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_conversation_member(p_conv) then raise exception 'not_allowed'; end if;
  update public.messages set read_at = now()
   where conversation_id = p_conv and sender_id <> auth.uid() and read_at is null;
  update public.notifications set read_at = now()
   where user_id = auth.uid() and type = 'message' and link = '/messages/' || p_conv and read_at is null;
end $$;

-- Numéro WhatsApp : exposé uniquement si le vendeur a donné son consentement
create or replace function public.get_whatsapp(p_user uuid) returns text
language sql stable security definer set search_path = public as $$
  select pp.whatsapp_number from public.private_profiles pp
  join public.profiles p on p.id = pp.id
  where pp.id = p_user and p.show_whatsapp and pp.whatsapp_number is not null
$$;

-- ---------------------------------------------------------------------------
-- Négociations et échanges
-- ---------------------------------------------------------------------------
create or replace function public.negotiations_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_l public.listings; v_x public.listings;
begin
  new.buyer_id := coalesce(auth.uid(), new.buyer_id);
  select * into v_l from public.listings where id = new.listing_id;
  if not found or v_l.status <> 'active' then raise exception 'listing_unavailable'; end if;
  if v_l.seller_id = new.buyer_id then raise exception 'own_listing'; end if;
  if public.are_blocked(new.buyer_id, v_l.seller_id) then raise exception 'blocked'; end if;
  new.seller_id := v_l.seller_id;
  new.status := 'pending'; new.buyer_confirmed := false; new.seller_confirmed := false;
  if new.kind = 'offer' then
    if not v_l.negotiable then raise exception 'not_negotiable'; end if;
    new.currency_code := v_l.currency_code;
    new.exchange_listing_id := null; new.cash_top_up := null;
  else
    if not v_l.exchange_possible then raise exception 'exchange_not_accepted'; end if;
    select * into v_x from public.listings where id = new.exchange_listing_id;
    if not found or v_x.seller_id <> new.buyer_id or v_x.status <> 'active' then raise exception 'invalid_exchange_listing'; end if;
    new.currency_code := v_l.currency_code;
    new.offered_price := null;
  end if;
  return new;
end $$;
create trigger trg_negotiations_before_insert before insert on public.negotiations
  for each row execute function public.negotiations_before_insert();

create or replace function public.negotiations_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_title text; v_name text;
begin
  select title into v_title from public.listings where id = new.listing_id;
  select display_name into v_name from public.profiles where id = new.buyer_id;
  insert into public.negotiation_events (negotiation_id, actor_id, action, detail)
  values (new.id, new.buyer_id, 'created',
          jsonb_build_object('kind', new.kind, 'offered_price', new.offered_price, 'currency', new.currency_code,
                             'exchange_listing_id', new.exchange_listing_id, 'cash_top_up', new.cash_top_up, 'note', new.note));
  insert into public.notifications (user_id, type, title, body, link)
  values (new.seller_id, 'negotiation',
          case when new.kind = 'exchange' then 'Proposition d''échange de ' else 'Offre de ' end || coalesce(v_name,'un acheteur'),
          v_title, '/compte/negociations');
  return null;
end $$;
create trigger trg_negotiations_after_insert after insert on public.negotiations
  for each row execute function public.negotiations_after_insert();

create or replace function public.negotiation_respond(p_id uuid, p_action text, p_price numeric default null, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_n public.negotiations; v_me uuid := auth.uid(); v_new text; v_other uuid;
begin
  select * into v_n from public.negotiations where id = p_id for update;
  if not found or v_me not in (v_n.buyer_id, v_n.seller_id) then raise exception 'not_allowed'; end if;
  v_other := case when v_me = v_n.buyer_id then v_n.seller_id else v_n.buyer_id end;

  if p_action = 'cancel' then
    if v_n.status not in ('pending','countered') then raise exception 'invalid_state'; end if;
    v_new := 'cancelled';
  elsif v_n.status = 'pending' and v_me = v_n.seller_id then
    if p_action = 'accept' then v_new := 'accepted';
    elsif p_action = 'decline' then v_new := 'declined';
    elsif p_action = 'counter' then
      if v_n.kind = 'offer' and (p_price is null or p_price < 0) then raise exception 'price_required'; end if;
      v_new := 'countered';
      if v_n.kind = 'offer' then v_n.offered_price := p_price; else v_n.cash_top_up := coalesce(p_price, v_n.cash_top_up); end if;
    else raise exception 'invalid_action'; end if;
  elsif v_n.status = 'countered' and v_me = v_n.buyer_id then
    if p_action = 'accept' then v_new := 'accepted';
    elsif p_action = 'decline' then v_new := 'declined';
    else raise exception 'invalid_action'; end if;
  else
    raise exception 'invalid_state';
  end if;

  update public.negotiations
     set status = v_new, offered_price = v_n.offered_price, cash_top_up = v_n.cash_top_up
   where id = p_id;
  insert into public.negotiation_events (negotiation_id, actor_id, action, detail)
  values (p_id, v_me, p_action, jsonb_build_object('price', p_price, 'note', p_note, 'status', v_new));
  insert into public.notifications (user_id, type, title, body, link)
  values (v_other, 'negotiation', 'Négociation : ' || v_new, p_note, '/compte/negociations');
end $$;

create or replace function public.negotiation_confirm(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_n public.negotiations; v_me uuid := auth.uid();
begin
  select * into v_n from public.negotiations where id = p_id for update;
  if not found or v_me not in (v_n.buyer_id, v_n.seller_id) then raise exception 'not_allowed'; end if;
  if v_n.status <> 'accepted' then raise exception 'invalid_state'; end if;
  if v_me = v_n.buyer_id then v_n.buyer_confirmed := true; else v_n.seller_confirmed := true; end if;
  update public.negotiations
     set buyer_confirmed = v_n.buyer_confirmed, seller_confirmed = v_n.seller_confirmed,
         status = case when v_n.buyer_confirmed and v_n.seller_confirmed then 'completed' else status end
   where id = p_id;
  insert into public.negotiation_events (negotiation_id, actor_id, action, detail)
  values (p_id, v_me, 'confirm', jsonb_build_object('buyer', v_n.buyer_confirmed, 'seller', v_n.seller_confirmed));
end $$;

-- ---------------------------------------------------------------------------
-- Offres sur demandes de matériel
-- ---------------------------------------------------------------------------
create or replace function public.wanted_offers_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_req public.wanted_requests;
begin
  new.seller_id := coalesce(auth.uid(), new.seller_id);
  select * into v_req from public.wanted_requests where id = new.request_id;
  if not found or v_req.status <> 'open' then raise exception 'request_closed'; end if;
  if v_req.requester_id = new.seller_id then raise exception 'own_request'; end if;
  if public.are_blocked(new.seller_id, v_req.requester_id) then raise exception 'blocked'; end if;
  new.status := 'sent';
  if new.listing_id is not null and not exists (
      select 1 from public.listings where id = new.listing_id and seller_id = new.seller_id) then
    raise exception 'invalid_listing';
  end if;
  return new;
end $$;
create trigger trg_wanted_offers_before before insert on public.wanted_offers
  for each row execute function public.wanted_offers_before_insert();

create or replace function public.wanted_offers_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_req public.wanted_requests; v_name text;
begin
  select * into v_req from public.wanted_requests where id = new.request_id;
  select display_name into v_name from public.profiles where id = new.seller_id;
  insert into public.notifications (user_id, type, title, body, link)
  values (v_req.requester_id, 'wanted_offer', 'Nouvelle offre de ' || coalesce(v_name,'un vendeur'), v_req.title, '/demandes/' || v_req.id);
  return null;
end $$;
create trigger trg_wanted_offers_after after insert on public.wanted_offers
  for each row execute function public.wanted_offers_after_insert();

-- ---------------------------------------------------------------------------
-- Avis : réservés aux transactions réellement conclues
-- ---------------------------------------------------------------------------
create or replace function public.reviews_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_seller uuid;
begin
  new.reviewer_id := coalesce(auth.uid(), new.reviewer_id);
  if new.shop_id is not null and new.seller_id is null then
    select owner_id into new.seller_id from public.shops where id = new.shop_id;
  end if;
  v_seller := new.seller_id;
  if new.order_id is not null then
    if not exists (select 1 from public.orders o where o.id = new.order_id and o.buyer_id = new.reviewer_id
                   and o.seller_id = v_seller and o.status in ('delivered','completed')) then
      raise exception 'review_not_allowed';
    end if;
  elsif not exists (select 1 from public.negotiations n where n.status = 'completed'
                    and n.buyer_id = new.reviewer_id and n.seller_id = v_seller) then
    raise exception 'review_not_allowed';
  end if;
  return new;
end $$;
create trigger trg_reviews_before before insert on public.reviews
  for each row execute function public.reviews_before_insert();

create view public.seller_ratings with (security_invoker = true) as
  select seller_id, round(avg(rating)::numeric, 2) as rating_avg, count(*)::int as rating_count
  from public.reviews where seller_id is not null group by seller_id;

create view public.shop_ratings with (security_invoker = true) as
  select shop_id, round(avg(rating)::numeric, 2) as rating_avg, count(*)::int as rating_count
  from public.reviews where shop_id is not null group by shop_id;

-- ---------------------------------------------------------------------------
-- Signalements : limitation du spam
-- ---------------------------------------------------------------------------
create or replace function public.reports_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_recent int;
begin
  new.reporter_id := coalesce(auth.uid(), new.reporter_id);
  new.status := 'open'; new.handled_by := null; new.resolution_note := null; new.resolved_at := null;
  select count(*) into v_recent from public.reports where reporter_id = new.reporter_id and created_at > now() - interval '24 hours';
  if v_recent >= 20 then raise exception 'rate_limit_reports'; end if;
  return new;
end $$;
create trigger trg_reports_before before insert on public.reports
  for each row execute function public.reports_before_insert();

-- ---------------------------------------------------------------------------
-- Commandes (toute écriture passe par ces fonctions : jamais d'écriture directe côté client)
-- ---------------------------------------------------------------------------
create or replace function public.cart_set(p_listing uuid, p_qty int) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_l public.listings;
begin
  if v_me is null then raise exception 'not_authenticated'; end if;
  if p_qty <= 0 then
    delete from public.cart_items where user_id = v_me and listing_id = p_listing;
    return;
  end if;
  select * into v_l from public.listings where id = p_listing;
  if not found or v_l.status <> 'active' then raise exception 'listing_unavailable'; end if;
  if v_l.seller_id = v_me then raise exception 'own_listing'; end if;
  if p_qty > v_l.quantity then raise exception 'insufficient_stock'; end if;
  insert into public.carts (user_id) values (v_me) on conflict (user_id) do update set updated_at = now();
  insert into public.cart_items (user_id, listing_id, quantity) values (v_me, p_listing, p_qty)
  on conflict (user_id, listing_id) do update set quantity = excluded.quantity;
end $$;

create or replace function public.place_order(p_delivery_method text, p_address jsonb default null,
                                              p_payment_method text default null, p_note text default null)
returns setof uuid language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := auth.uid();
  g record; it record; v_order uuid; v_sub numeric; v_fee numeric; v_rate numeric;
  v_rule public.shipping_rules; v_same_city boolean; v_to_country text; v_to_city text;
  v_from_country text; v_from_city text; v_method text; v_susp boolean; v_shop uuid;
begin
  if v_me is null then raise exception 'not_authenticated'; end if;
  select is_suspended into v_susp from public.profiles where id = v_me;
  if v_susp then raise exception 'account_suspended'; end if;
  if p_delivery_method not in ('pickup','local','intercity','international') then raise exception 'invalid_delivery_method'; end if;
  if not exists (select 1 from public.cart_items where user_id = v_me) then raise exception 'empty_cart'; end if;
  if p_delivery_method <> 'pickup' and (p_address is null or coalesce(p_address->>'country','') = '' or coalesce(p_address->>'city','') = '' or coalesce(p_address->>'line1','') = '') then
    raise exception 'address_required';
  end if;
  v_rate := public.setting_num('commission_rate', 0.03);
  perform set_config('wm.bypass', '1', true);

  for g in
    select l.seller_id, l.currency_code, min(l.country_code) as country_code, min(l.city) as city, min(l.shop_id::text)::uuid as shop_id
    from public.cart_items ci join public.listings l on l.id = ci.listing_id
    where ci.user_id = v_me group by l.seller_id, l.currency_code
  loop
    -- verrouille les annonces concernées puis valide les lignes
    perform 1 from public.cart_items ci join public.listings l on l.id = ci.listing_id
      where ci.user_id = v_me and l.seller_id = g.seller_id and l.currency_code = g.currency_code for update of l;
    v_sub := 0;
    for it in
      select ci.quantity as qty, l.id, l.quantity as stock, l.status, l.price, l.title, l.delivery_available
      from public.cart_items ci join public.listings l on l.id = ci.listing_id
      where ci.user_id = v_me and l.seller_id = g.seller_id and l.currency_code = g.currency_code
    loop
      if it.status <> 'active' then raise exception 'listing_unavailable'; end if;
      if it.qty > it.stock then raise exception 'insufficient_stock'; end if;
      if p_delivery_method <> 'pickup' and not it.delivery_available then raise exception 'delivery_not_available'; end if;
      v_sub := v_sub + it.price * it.qty;
    end loop;

    -- frais de livraison : uniquement à partir de règles configurées
    v_fee := 0;
    v_method := p_delivery_method;
    if v_method <> 'pickup' then
      v_from_country := g.country_code; v_from_city := g.city;
      v_to_country := upper(p_address->>'country'); v_to_city := p_address->>'city';
      v_same_city := lower(coalesce(v_from_city,'')) = lower(coalesce(v_to_city,''));
      if v_method = 'local' and not (v_from_country = v_to_country and v_same_city) then raise exception 'delivery_method_mismatch'; end if;
      if v_method = 'intercity' and not (v_from_country = v_to_country and not v_same_city) then raise exception 'delivery_method_mismatch'; end if;
      if v_method = 'international' and v_from_country = v_to_country then raise exception 'delivery_method_mismatch'; end if;
      select * into v_rule from public.shipping_rules r
       where r.enabled and r.method = v_method and r.from_country = v_from_country and r.to_country = v_to_country
         and r.currency_code = g.currency_code and (r.same_city is null or r.same_city = v_same_city)
       order by (r.same_city is not null) desc, r.fee asc limit 1;
      if not found then raise exception 'no_shipping_rule'; end if;
      v_fee := v_rule.fee;
    end if;

    insert into public.orders (buyer_id, seller_id, shop_id, status, currency_code, subtotal, shipping_fee,
                               commission_rate, commission_amount, total, delivery_method, shipping_address,
                               payment_method, buyer_note)
    values (v_me, g.seller_id, g.shop_id, 'pending', g.currency_code, v_sub, v_fee, v_rate,
            round(v_sub * v_rate, 2), v_sub + v_fee, v_method, p_address, p_payment_method, p_note)
    returning id into v_order;

    insert into public.order_items (order_id, listing_id, title, unit_price, currency_code, quantity)
    select v_order, l.id, l.title, l.price, l.currency_code, ci.quantity
    from public.cart_items ci join public.listings l on l.id = ci.listing_id
    where ci.user_id = v_me and l.seller_id = g.seller_id and l.currency_code = g.currency_code;

    update public.listings l set quantity = l.quantity - ci.quantity,
           status = case when l.quantity - ci.quantity = 0 then 'sold' else l.status end
      from public.cart_items ci
     where ci.user_id = v_me and ci.listing_id = l.id and l.seller_id = g.seller_id and l.currency_code = g.currency_code;

    insert into public.shipments (order_id, method, status) values (v_order, v_method, 'preparing');

    insert into public.notifications (user_id, type, title, body, link)
    values (g.seller_id, 'order', 'Nouvelle commande', 'Une commande attend votre confirmation.', '/compte/commandes');

    delete from public.cart_items ci using public.listings l
     where ci.user_id = v_me and ci.listing_id = l.id and l.seller_id = g.seller_id and l.currency_code = g.currency_code;

    return next v_order;
  end loop;
  perform set_config('wm.bypass', '', true);
  return;
end $$;

create or replace function public.restock_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform set_config('wm.bypass', '1', true);
  update public.listings l set quantity = l.quantity + oi.quantity,
         status = case when l.status = 'sold' then 'active' else l.status end
    from public.order_items oi where oi.order_id = p_order and oi.listing_id = l.id;
  perform set_config('wm.bypass', '', true);
end $$;
revoke execute on function public.restock_order(uuid) from public, anon, authenticated;

create or replace function public.cancel_order(p_order uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_me uuid := auth.uid(); v_paid boolean;
begin
  select * into v_o from public.orders where id = p_order for update;
  if not found or v_me not in (v_o.buyer_id, v_o.seller_id) then raise exception 'not_allowed'; end if;
  if v_o.status not in ('pending','awaiting_payment','processing','paid') then raise exception 'invalid_state'; end if;
  select exists (select 1 from public.payments where order_id = p_order and status = 'succeeded') into v_paid;
  if v_paid then raise exception 'refund_required'; end if;   -- remboursement via le prestataire de paiement
  if v_me = v_o.buyer_id and v_o.status in ('processing','paid') then raise exception 'seller_approval_required'; end if;
  update public.orders set status = 'cancelled', cancelled_reason = p_reason where id = p_order;
  update public.shipments set status = 'failed' where order_id = p_order and status in ('preparing','ready');
  perform public.restock_order(p_order);
  insert into public.notifications (user_id, type, title, body, link)
  values (case when v_me = v_o.buyer_id then v_o.seller_id else v_o.buyer_id end, 'order', 'Commande annulée ' || v_o.order_number, p_reason, '/compte/commandes');
end $$;

create or replace function public.advance_order(p_order uuid, p_status text, p_tracking text default null, p_carrier text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_me uuid := auth.uid(); v_ok boolean := false;
begin
  select * into v_o from public.orders where id = p_order for update;
  if not found or v_me not in (v_o.buyer_id, v_o.seller_id) then raise exception 'not_allowed'; end if;
  if v_me = v_o.seller_id then
    v_ok := (v_o.status in ('pending','paid') and p_status = 'processing')
         or (v_o.status = 'processing' and p_status = 'shipped' and v_o.delivery_method <> 'pickup')
         or (v_o.status in ('processing','shipped') and p_status = 'delivered');
  end if;
  if v_me = v_o.buyer_id then
    v_ok := v_o.status = 'delivered' and p_status = 'completed';
  end if;
  if not v_ok then raise exception 'invalid_transition'; end if;
  update public.orders set status = p_status where id = p_order;
  update public.shipments set
      status = case p_status when 'processing' then 'ready' when 'shipped' then 'in_transit' when 'delivered' then 'delivered' else status end,
      tracking_number = coalesce(p_tracking, tracking_number), carrier = coalesce(p_carrier, carrier),
      shipped_at = case when p_status = 'shipped' then now() else shipped_at end,
      delivered_at = case when p_status = 'delivered' then now() else delivered_at end,
      buyer_confirmed_at = case when p_status = 'completed' then now() else buyer_confirmed_at end
   where order_id = p_order;
  insert into public.notifications (user_id, type, title, body, link)
  values (case when v_me = v_o.buyer_id then v_o.seller_id else v_o.buyer_id end, 'order',
          'Commande ' || v_o.order_number || ' : ' || p_status, p_tracking, '/compte/commandes');
end $$;

create or replace function public.open_dispute(p_order uuid, p_reason text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_o public.orders; v_id uuid;
begin
  select * into v_o from public.orders where id = p_order;
  if not found or auth.uid() not in (v_o.buyer_id, v_o.seller_id) then raise exception 'not_allowed'; end if;
  insert into public.disputes (order_id, opened_by, reason) values (p_order, auth.uid(), p_reason) returning id into v_id;
  perform set_config('wm.bypass', '1', true);
  update public.orders set status = 'disputed' where id = p_order and status not in ('cancelled','refunded');
  perform set_config('wm.bypass', '', true);
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- Statistiques d'administration
-- ---------------------------------------------------------------------------
create or replace function public.admin_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_staff() then raise exception 'not_allowed'; end if;
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'shops', (select count(*) from public.shops),
    'listings', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb) from (select status, count(*) n from public.listings group by status) s),
    'orders', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb) from (select status, count(*) n from public.orders group by status) s),
    'sales_by_currency', (select coalesce(jsonb_object_agg(currency_code, total), '{}'::jsonb) from (
        select currency_code, sum(total) total from public.orders where status in ('paid','processing','shipped','delivered','completed') group by currency_code) s),
    'commission_by_currency', (select coalesce(jsonb_object_agg(currency_code, c), '{}'::jsonb) from (
        select currency_code, sum(commission_amount) c from public.orders where status in ('delivered','completed') group by currency_code) s),
    'open_reports', (select count(*) from public.reports where status = 'open'),
    'open_disputes', (select count(*) from public.disputes where status in ('open','investigating')),
    'pending_listings', (select count(*) from public.listings where status = 'pending_review'),
    'pending_shops', (select count(*) from public.shops where verification_status = 'pending'),
    'pending_deletions', (select count(*) from public.data_deletion_requests where status = 'pending')
  );
end $$;

-- ---------------------------------------------------------------------------
-- Journal des actions administratives
-- ---------------------------------------------------------------------------
create or replace function public.audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_id text; v_old jsonb; v_new jsonb;
begin
  -- tables « utilisateur » : on ne journalise que les actions du personnel
  if tg_table_name in ('listings','profiles','shops','reports','disputes','subscriptions','promotions','data_deletion_requests') then
    if not public.is_staff() then return null; end if;
  end if;
  v_old := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  v_new := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  v_id := coalesce(v_new->>'id', v_old->>'id', v_new->>'code', v_old->>'code', v_new->>'key', v_old->>'key');
  if tg_op = 'UPDATE' and tg_table_name = 'listings' then
    -- éviter le bruit (compteur de vues, etc.)
    if v_old->>'status' = v_new->>'status' and v_old->>'is_sponsored' = v_new->>'is_sponsored' then return null; end if;
  end if;
  insert into public.audit_logs (actor_id, action, entity_type, entity_id, detail)
  values (auth.uid(), lower(tg_op), tg_table_name, v_id,
          jsonb_build_object('old', v_old, 'new', v_new));
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['user_roles','categories','brands','product_models','countries','currencies','cities','plans',
    'platform_settings','shipping_rules','payment_providers','banned_keywords','listings','profiles','shops','reports',
    'disputes','subscriptions','promotions','data_deletion_requests']
  loop
    execute format('create trigger trg_audit_%1$s after insert or update or delete on public.%1$I for each row execute function public.audit_row_change()', t);
  end loop;
end $$;
