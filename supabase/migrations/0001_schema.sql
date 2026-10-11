-- WiFiMarket — schéma principal (Phase 1)
-- Les prix sont toujours stockés dans leur devise d'origine (aucune conversion automatique).

create schema if not exists extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

-- ---------------------------------------------------------------------------
-- Utilitaires
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- unaccent n'est pas IMMUTABLE : enveloppe pour pouvoir l'utiliser dans les colonnes générées / index
create or replace function public.immutable_unaccent(text) returns text
language sql immutable parallel safe
set search_path = public, extensions
as $$ select extensions.unaccent($1) $$;

create or replace function public.slugify(txt text) returns text
language sql immutable
set search_path = public, extensions
as $$
  select trim(both '-' from regexp_replace(lower(extensions.unaccent(coalesce(txt,''))), '[^a-z0-9]+', '-', 'g'))
$$;

-- ---------------------------------------------------------------------------
-- Référentiels : devises, pays, villes
-- ---------------------------------------------------------------------------
create table public.currencies (
  code text primary key check (code ~ '^[A-Z]{3}$'),
  name text not null,
  symbol text not null,
  decimals smallint not null default 0 check (decimals between 0 and 3),
  enabled boolean not null default true
);

create table public.countries (
  code text primary key check (code ~ '^[A-Z]{2}$'),
  name_fr text not null,
  name_en text not null,
  currency_code text not null references public.currencies(code),
  phone_prefix text,
  enabled boolean not null default true,
  sort_order int not null default 0
);

create table public.cities (
  id bigint generated always as identity primary key,
  country_code text not null references public.countries(code) on delete cascade,
  name text not null,
  unique (country_code, name)
);

-- ---------------------------------------------------------------------------
-- Profils & rôles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 60),
  avatar_url text,
  bio text check (char_length(bio) <= 500),
  country_code text references public.countries(code),
  city text,
  show_whatsapp boolean not null default false,  -- consentement à l'affichage du bouton WhatsApp
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','rejected')),
  is_suspended boolean not null default false,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

-- Données privées : jamais lisibles par les autres utilisateurs
create table public.private_profiles (
  id uuid primary key references public.profiles(id) on delete cascade,
  whatsapp_number text check (whatsapp_number ~ '^\+?[0-9]{6,15}$'),
  phone text,
  full_name text,
  default_address jsonb,
  updated_at timestamptz not null default now()
);
create trigger trg_private_profiles_updated before update on public.private_profiles
  for each row execute function public.set_updated_at();

create table public.user_roles (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('shop_manager','moderator','country_admin','superadmin')),
  country_code text references public.countries(code),   -- obligatoire pour country_admin
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  unique (user_id, role, country_code),
  check (role <> 'country_admin' or country_code is not null)
);

-- ---------------------------------------------------------------------------
-- Catalogue : catégories, marques, modèles
-- ---------------------------------------------------------------------------
create table public.categories (
  id bigint generated always as identity primary key,
  parent_id bigint references public.categories(id) on delete cascade,
  slug text not null unique,
  name_fr text not null,
  name_en text not null,
  icon text,
  sort_order int not null default 0,
  enabled boolean not null default true
);
create index categories_parent_idx on public.categories(parent_id);

create table public.brands (
  id bigint generated always as identity primary key,
  slug text not null unique,
  name text not null unique,
  logo_url text,
  enabled boolean not null default true
);

create table public.product_models (
  id bigint generated always as identity primary key,
  brand_id bigint not null references public.brands(id) on delete cascade,
  category_id bigint references public.categories(id) on delete set null,
  name text not null,
  specs jsonb not null default '{}'::jsonb,
  unique (brand_id, name)
);
create index product_models_category_idx on public.product_models(category_id);

-- ---------------------------------------------------------------------------
-- Boutiques
-- ---------------------------------------------------------------------------
create table public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  slug text not null unique,
  name text not null check (char_length(name) between 2 and 80),
  description text check (char_length(description) <= 2000),
  logo_url text,
  banner_url text,
  country_code text references public.countries(code),
  city text,
  plan text not null default 'free' check (plan in ('free','pro','premium')),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','pending','verified','rejected')),
  is_active boolean not null default true,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_shops_updated before update on public.shops
  for each row execute function public.set_updated_at();

create table public.shop_members (
  shop_id uuid not null references public.shops(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'manager' check (role in ('owner','manager')),
  created_at timestamptz not null default now(),
  primary key (shop_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Annonces
-- ---------------------------------------------------------------------------
create table public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  shop_id uuid references public.shops(id) on delete set null,
  category_id bigint not null references public.categories(id),
  brand_id bigint references public.brands(id),
  model_id bigint references public.product_models(id),
  model_text text,
  title text not null check (char_length(title) between 5 and 140),
  slug text not null,
  description text not null default '' check (char_length(description) <= 5000),
  condition text not null check (condition in ('new','used','refurbished','broken','for_parts')),
  price numeric(14,2) not null check (price >= 0),
  currency_code text not null references public.currencies(code),
  quantity int not null default 1 check (quantity >= 0),
  country_code text not null references public.countries(code),
  city text,
  delivery_available boolean not null default false,
  defects text check (char_length(defects) <= 1000),
  warranty text check (char_length(warranty) <= 300),
  negotiable boolean not null default true,
  exchange_possible boolean not null default false,
  exchange_wanted text,
  status text not null default 'draft'
    check (status in ('draft','pending_review','active','paused','sold','rejected','expired','removed')),
  rejection_reason text,
  is_sponsored boolean not null default false,
  sponsored_until timestamptz,
  views_count int not null default 0,
  published_at timestamptz,
  expires_at timestamptz,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  search tsvector generated always as (
    setweight(to_tsvector('simple', public.immutable_unaccent(coalesce(title,''))), 'A') ||
    setweight(to_tsvector('simple', public.immutable_unaccent(coalesce(model_text,''))), 'B') ||
    setweight(to_tsvector('simple', public.immutable_unaccent(coalesce(description,''))), 'C')
  ) stored
);
create unique index listings_slug_idx on public.listings(slug);
create index listings_search_idx on public.listings using gin(search);
create index listings_title_trgm_idx on public.listings using gin (title extensions.gin_trgm_ops);
create index listings_status_pub_idx on public.listings(status, published_at desc);
create index listings_category_idx on public.listings(category_id) where status = 'active';
create index listings_country_city_idx on public.listings(country_code, city) where status = 'active';
create index listings_seller_idx on public.listings(seller_id);
create index listings_shop_idx on public.listings(shop_id);
create index listings_price_idx on public.listings(currency_code, price) where status = 'active';
create trigger trg_listings_updated before update on public.listings
  for each row execute function public.set_updated_at();

create table public.listing_media (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  kind text not null default 'image' check (kind in ('image','video')),
  storage_path text not null,
  position smallint not null default 0,
  created_at timestamptz not null default now()
);
create index listing_media_listing_idx on public.listing_media(listing_id, position);

create table public.listing_attributes (
  listing_id uuid not null references public.listings(id) on delete cascade,
  key text not null check (char_length(key) <= 60),
  value text not null check (char_length(value) <= 200),
  primary key (listing_id, key)
);

create table public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null check (char_length(label) <= 80),
  query text,
  category_id bigint references public.categories(id) on delete cascade,
  brand_id bigint references public.brands(id) on delete cascade,
  country_code text references public.countries(code),
  city text,
  condition text check (condition in ('new','used','refurbished','broken','for_parts')),
  min_price numeric(14,2),
  max_price numeric(14,2),
  currency_code text references public.currencies(code),
  notify boolean not null default true,
  created_at timestamptz not null default now()
);
create index saved_searches_user_idx on public.saved_searches(user_id);

-- ---------------------------------------------------------------------------
-- Demandes de matériel (« Je recherche »)
-- ---------------------------------------------------------------------------
create table public.wanted_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 5 and 140),
  category_id bigint references public.categories(id),
  brand_id bigint references public.brands(id),
  model_text text,
  condition_wanted text check (condition_wanted in ('new','used','refurbished','broken','for_parts','any')),
  budget numeric(14,2) check (budget >= 0),
  currency_code text references public.currencies(code),
  country_code text not null references public.countries(code),
  city text,
  description text not null default '' check (char_length(description) <= 3000),
  status text not null default 'open' check (status in ('open','fulfilled','closed','removed')),
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index wanted_requests_status_idx on public.wanted_requests(status, created_at desc);
create index wanted_requests_geo_idx on public.wanted_requests(country_code, city);
create trigger trg_wanted_updated before update on public.wanted_requests
  for each row execute function public.set_updated_at();

create table public.wanted_offers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.wanted_requests(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete set null,
  price numeric(14,2) not null check (price >= 0),
  currency_code text not null references public.currencies(code),
  condition text check (condition in ('new','used','refurbished','broken','for_parts')),
  message text check (char_length(message) <= 1000),
  status text not null default 'sent' check (status in ('sent','accepted','declined','withdrawn')),
  created_at timestamptz not null default now(),
  unique (request_id, seller_id)
);
create index wanted_offers_request_idx on public.wanted_offers(request_id);

-- ---------------------------------------------------------------------------
-- Messagerie
-- ---------------------------------------------------------------------------
create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references public.profiles(id) on delete cascade,
  user_b uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete set null,
  request_id uuid references public.wanted_requests(id) on delete set null,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  is_demo boolean not null default false,
  check (user_a <> user_b)
);
-- une conversation par couple d'utilisateurs et par objet (annonce ou demande)
create unique index conversations_unique_idx on public.conversations (
  least(user_a, user_b), greatest(user_a, user_b),
  coalesce(listing_id, '00000000-0000-0000-0000-000000000000'::uuid),
  coalesce(request_id, '00000000-0000-0000-0000-000000000000'::uuid)
);
create index conversations_a_idx on public.conversations(user_a, last_message_at desc);
create index conversations_b_idx on public.conversations(user_b, last_message_at desc);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 4000),
  image_path text,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  check (char_length(body) > 0 or image_path is not null)
);
create index messages_conv_idx on public.messages(conversation_id, created_at);

create table public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- Négociations et échanges (avec historique de l'accord)
create table public.negotiations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null default 'offer' check (kind in ('offer','exchange')),
  offered_price numeric(14,2) check (offered_price >= 0),
  currency_code text references public.currencies(code),
  exchange_listing_id uuid references public.listings(id) on delete set null,
  cash_top_up numeric(14,2) check (cash_top_up >= 0),   -- complément financier éventuel (en devise ci-dessus)
  note text check (char_length(note) <= 1000),
  status text not null default 'pending'
    check (status in ('pending','countered','accepted','declined','cancelled','completed')),
  buyer_confirmed boolean not null default false,
  seller_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (buyer_id <> seller_id),
  check (kind <> 'exchange' or exchange_listing_id is not null),
  check (kind <> 'offer' or offered_price is not null)
);
create index negotiations_listing_idx on public.negotiations(listing_id);
create index negotiations_buyer_idx on public.negotiations(buyer_id);
create index negotiations_seller_idx on public.negotiations(seller_id);
create trigger trg_negotiations_updated before update on public.negotiations
  for each row execute function public.set_updated_at();

create table public.negotiation_events (
  id bigint generated always as identity primary key,
  negotiation_id uuid not null references public.negotiations(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index negotiation_events_idx on public.negotiation_events(negotiation_id, created_at);

-- ---------------------------------------------------------------------------
-- Livraison : règles configurées (les frais ne sont jamais inventés)
-- ---------------------------------------------------------------------------
create table public.shipping_rules (
  id bigint generated always as identity primary key,
  method text not null check (method in ('local','intercity','international')),
  from_country text not null references public.countries(code),
  to_country text not null references public.countries(code),
  same_city boolean,            -- null = indifférent
  fee numeric(14,2) not null check (fee >= 0),
  currency_code text not null references public.currencies(code),
  eta_days_min smallint,
  eta_days_max smallint,
  carrier text,
  enabled boolean not null default true
);
create index shipping_rules_lookup_idx on public.shipping_rules(method, from_country, to_country) where enabled;

-- ---------------------------------------------------------------------------
-- Panier, commandes, paiements, livraisons
-- ---------------------------------------------------------------------------
create table public.carts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  updated_at timestamptz not null default now()
);

create table public.cart_items (
  user_id uuid not null references public.carts(user_id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  quantity int not null default 1 check (quantity > 0),
  added_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table public.platform_settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('WM-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  buyer_id uuid not null references public.profiles(id),
  seller_id uuid not null references public.profiles(id),
  shop_id uuid references public.shops(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending','awaiting_payment','paid','processing','shipped','delivered','completed','cancelled','refunded','disputed')),
  currency_code text not null references public.currencies(code),
  subtotal numeric(14,2) not null check (subtotal >= 0),
  shipping_fee numeric(14,2) not null default 0 check (shipping_fee >= 0),
  commission_rate numeric(5,4) not null default 0 check (commission_rate between 0 and 1),
  commission_amount numeric(14,2) not null default 0,
  total numeric(14,2) not null check (total >= 0),
  delivery_method text not null check (delivery_method in ('pickup','local','intercity','international')),
  shipping_address jsonb,
  payment_method text,
  buyer_note text,
  cancelled_reason text,
  is_demo boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index orders_buyer_idx on public.orders(buyer_id, created_at desc);
create index orders_seller_idx on public.orders(seller_id, created_at desc);
create index orders_status_idx on public.orders(status);
create trigger trg_orders_updated before update on public.orders
  for each row execute function public.set_updated_at();

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  listing_id uuid references public.listings(id) on delete set null,
  title text not null,               -- instantané au moment de la commande
  unit_price numeric(14,2) not null check (unit_price >= 0),
  currency_code text not null references public.currencies(code),
  quantity int not null check (quantity > 0)
);
create index order_items_order_idx on public.order_items(order_id);

create table public.payment_providers (
  code text primary key,                       -- 'cinetpay', 'paystack', 'cod' ...
  name text not null,
  countries text[] not null default '{}',      -- pays supportés (à vérifier avec le prestataire)
  currencies text[] not null default '{}',
  methods text[] not null default '{}',        -- orange_money, moov_money, wave, card ...
  enabled boolean not null default false,
  sandbox boolean not null default true,       -- sandbox uniquement tant que les identifiants marchands ne sont pas fournis
  eligibility_verified boolean not null default false,
  notes text
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null references public.payment_providers(code),
  provider_reference text,
  status text not null default 'initiated'
    check (status in ('initiated','pending','succeeded','failed','refunded','cancelled')),
  amount numeric(14,2) not null check (amount >= 0),
  currency_code text not null references public.currencies(code),
  method text,
  is_sandbox boolean not null default true,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index payments_provider_ref_idx on public.payments(provider, provider_reference) where provider_reference is not null;
create index payments_order_idx on public.payments(order_id);
create trigger trg_payments_updated before update on public.payments
  for each row execute function public.set_updated_at();

create table public.payment_events (
  id bigint generated always as identity primary key,
  payment_id uuid references public.payments(id) on delete cascade,
  provider text not null,
  event_type text not null,
  signature_valid boolean,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index payment_events_payment_idx on public.payment_events(payment_id);

create table public.shipments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  method text not null check (method in ('pickup','local','intercity','international')),
  carrier text,
  tracking_number text,
  status text not null default 'preparing'
    check (status in ('preparing','ready','in_transit','delivered','returned','failed')),
  shipped_at timestamptz,
  delivered_at timestamptz,
  buyer_confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index shipments_order_idx on public.shipments(order_id);
create trigger trg_shipments_updated before update on public.shipments
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Avis, signalements, litiges
-- ---------------------------------------------------------------------------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid references public.profiles(id) on delete cascade,
  shop_id uuid references public.shops(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  listing_id uuid references public.listings(id) on delete set null,
  rating smallint not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 1500),
  created_at timestamptz not null default now(),
  check (seller_id is not null or shop_id is not null),
  check (reviewer_id <> seller_id)
);
create unique index reviews_unique_order_idx on public.reviews(reviewer_id, order_id) where order_id is not null;
create unique index reviews_unique_nonorder_idx on public.reviews(reviewer_id, seller_id) where order_id is null and seller_id is not null;
create index reviews_seller_idx on public.reviews(seller_id);
create index reviews_shop_idx on public.reviews(shop_id);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('listing','user','conversation','shop','wanted_request','message')),
  target_id text not null,
  reason text not null check (reason in ('fraud','stolen','prohibited','counterfeit','spam','harassment','wrong_category','other')),
  details text check (char_length(details) <= 2000),
  status text not null default 'open' check (status in ('open','reviewing','actioned','dismissed')),
  handled_by uuid references public.profiles(id),
  resolution_note text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index reports_status_idx on public.reports(status, created_at desc);
create index reports_target_idx on public.reports(target_type, target_id);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  opened_by uuid not null references public.profiles(id),
  reason text not null check (char_length(reason) between 5 and 2000),
  status text not null default 'open' check (status in ('open','investigating','resolved_buyer','resolved_seller','closed')),
  resolution text,
  handled_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
create index disputes_order_idx on public.disputes(order_id);

-- ---------------------------------------------------------------------------
-- Modèle économique : abonnements, promotions, tarifs
-- ---------------------------------------------------------------------------
create table public.plans (
  code text primary key,                      -- 'sponsored_7d', 'shop_pro', 'shop_premium'
  name text not null,
  kind text not null check (kind in ('sponsorship','shop_subscription')),
  price numeric(14,2) not null check (price >= 0),
  currency_code text not null references public.currencies(code),
  duration_days int not null check (duration_days > 0),
  enabled boolean not null default true,
  is_demo_price boolean not null default true  -- tarif de démonstration, modifiable en administration
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  plan_code text not null references public.plans(code),
  status text not null default 'pending' check (status in ('pending','active','expired','cancelled')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);
create index subscriptions_shop_idx on public.subscriptions(shop_id);

create table public.promotions (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  requested_by uuid not null references public.profiles(id) on delete cascade,
  plan_code text not null references public.plans(code),
  status text not null default 'pending' check (status in ('pending','active','expired','rejected')),
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now()
);
create index promotions_listing_idx on public.promotions(listing_id);

-- ---------------------------------------------------------------------------
-- Notifications, audit, conformité
-- ---------------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications(user_id, created_at desc);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id text,
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_idx on public.audit_logs(created_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);

create table public.data_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','processing','done','rejected')),
  reason text,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  processed_by uuid references public.profiles(id)
);

create table public.banned_keywords (
  id bigint generated always as identity primary key,
  keyword text not null unique,
  reason text
);
