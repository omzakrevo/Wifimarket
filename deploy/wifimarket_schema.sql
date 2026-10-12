-- WiFiMarket : schéma complet (migrations 0001 à 0011), sans données de démonstration.
-- Application : docker exec -i supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -1 < wifimarket_schema.sql

-- ===== supabase/migrations/0001_schema.sql =====
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

-- ===== supabase/migrations/0002_logic.sql =====
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

-- Vide les lignes du panier d'un groupe (vendeur, devise) une fois la commande créée
create or replace function public.cart_clear_group(p_user uuid, p_seller uuid, p_currency text) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.cart_items
   where user_id = p_user
     and listing_id in (select id from public.listings where seller_id = p_seller and currency_code = p_currency);
end $$;
revoke execute on function public.cart_clear_group(uuid, uuid, text) from public, anon, authenticated;

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

    perform public.cart_clear_group(v_me, g.seller_id, g.currency_code);

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

-- ===== supabase/migrations/0003_rls.sql =====
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

-- ===== supabase/migrations/0004_storage.sql =====
-- WiFiMarket — Storage : buckets, limites de taille / types MIME (vérification des fichiers) et politiques d'accès

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('listing-media', 'listing-media', true, 52428800,
     array['image/jpeg','image/png','image/webp','image/avif','video/mp4','video/webm']),
  ('avatars', 'avatars', true, 2097152, array['image/jpeg','image/png','image/webp']),
  ('shop-assets', 'shop-assets', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('chat-images', 'chat-images', false, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Lecture publique des médias publics
create policy "public media read" on storage.objects for select
  using (bucket_id in ('listing-media','avatars','shop-assets'));

-- Annonces & avatars : dossier = identifiant de l'utilisateur
create policy "own folder insert" on storage.objects for insert to authenticated
  with check (bucket_id in ('listing-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own folder update" on storage.objects for update to authenticated
  using (bucket_id in ('listing-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy "own folder delete" on storage.objects for delete to authenticated
  using (bucket_id in ('listing-media','avatars') and (storage.foldername(name))[1] = auth.uid()::text);

-- Boutiques : dossier = identifiant de la boutique, réservé aux membres
create policy "shop assets write" on storage.objects for insert to authenticated
  with check (bucket_id = 'shop-assets' and public.is_shop_member(((storage.foldername(name))[1])::uuid));
create policy "shop assets update" on storage.objects for update to authenticated
  using (bucket_id = 'shop-assets' and public.is_shop_member(((storage.foldername(name))[1])::uuid));
create policy "shop assets delete" on storage.objects for delete to authenticated
  using (bucket_id = 'shop-assets' and public.is_shop_member(((storage.foldername(name))[1])::uuid));

-- Images de messagerie : chemin = {conversation_id}/{user_id}/{fichier}, privé aux participants
create policy "chat images read" on storage.objects for select to authenticated
  using (bucket_id = 'chat-images' and public.is_conversation_member(((storage.foldername(name))[1])::uuid));
create policy "chat images insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'chat-images'
    and public.is_conversation_member(((storage.foldername(name))[1])::uuid)
    and (storage.foldername(name))[2] = auth.uid()::text);

-- ===== supabase/migrations/0005_reference_data.sql =====
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

-- ===== supabase/migrations/0006_search.sql =====
-- WiFiMarket — moteur de recherche (Phase 3)
-- Recherche plein texte avec préfixes, insensible aux accents, filtres et tris.
-- SECURITY INVOKER : la RLS des annonces s'applique (seules les annonces actives sont renvoyées).
-- Les tris par prix n'ont de sens que dans UNE devise : sans devise précise, on trie par devise puis par prix
-- (aucune conversion monétaire n'est effectuée).

-- Construit la requête tsquery à préfixes à partir de la saisie ("lite beam 5ac" -> 'lite':* & 'beam':* & '5ac':*)
create or replace function public.search_tsquery(p_q text) returns text
language sql immutable
set search_path = public, extensions
as $$
  select string_agg(quote_literal(tok) || ':*', ' & ')
  from regexp_split_to_table(lower(public.immutable_unaccent(coalesce(p_q,''))), '[^a-z0-9]+') as tok
  where tok <> ''
$$;

-- Filtres communs (sans tri ni pagination)
create or replace function public.search_listings_base(
  p_q text default null, p_category text default null, p_brand text default null, p_country text default null,
  p_city text default null, p_min numeric default null, p_max numeric default null, p_currency text default null,
  p_condition text default null, p_in_stock boolean default false, p_delivery boolean default false,
  p_exchange boolean default false, p_since_days int default null, p_shop uuid default null, p_seller uuid default null
) returns setof public.listings
language sql stable
set search_path = public, extensions
as $$
  select l.*
  from public.listings l
  where l.status = 'active'
    and (public.search_tsquery(p_q) is null or l.search @@ to_tsquery('simple', public.search_tsquery(p_q)))
    and (p_category is null or l.category_id in (
          select c.id from public.categories c
          where c.slug = p_category or c.parent_id = (select id from public.categories where slug = p_category)))
    and (p_brand is null or l.brand_id = (select id from public.brands where slug = p_brand))
    and (p_country is null or l.country_code = p_country)
    and (p_city is null or lower(l.city) = lower(p_city))
    and (p_currency is null or l.currency_code = p_currency)
    and (p_min is null or l.price >= p_min)
    and (p_max is null or l.price <= p_max)
    and (p_condition is null or l.condition = p_condition)
    and (not p_in_stock or l.quantity > 0)
    and (not p_delivery or l.delivery_available)
    and (not p_exchange or l.exchange_possible)
    and (p_since_days is null or l.published_at >= now() - make_interval(days => p_since_days))
    and (p_shop is null or l.shop_id = p_shop)
    and (p_seller is null or l.seller_id = p_seller)
$$;

create or replace function public.search_listings(
  p_q text default null, p_category text default null, p_brand text default null, p_country text default null,
  p_city text default null, p_min numeric default null, p_max numeric default null, p_currency text default null,
  p_condition text default null, p_in_stock boolean default false, p_delivery boolean default false,
  p_exchange boolean default false, p_since_days int default null, p_shop uuid default null, p_seller uuid default null,
  p_sort text default 'relevance',    -- relevance | newest | price_asc | price_desc
  p_limit int default 24, p_offset int default 0
) returns setof public.listings
language sql stable
set search_path = public, extensions
as $$
  select l.*
  from public.search_listings_base(p_q, p_category, p_brand, p_country, p_city, p_min, p_max, p_currency,
         p_condition, p_in_stock, p_delivery, p_exchange, p_since_days, p_shop, p_seller) l
  order by
    case when p_sort in ('relevance','newest') and l.is_sponsored and coalesce(l.sponsored_until, now()) >= now() then 0 else 1 end,
    case when p_sort = 'relevance' and public.search_tsquery(p_q) is not null
         then ts_rank(l.search, to_tsquery('simple', public.search_tsquery(p_q))) end desc nulls last,
    case when p_sort in ('price_asc','price_desc') and p_currency is null then l.currency_code end asc,
    case when p_sort = 'price_asc' then l.price end asc,
    case when p_sort = 'price_desc' then l.price end desc,
    l.published_at desc nulls last,
    l.id
  limit least(greatest(p_limit, 1), 60) offset greatest(p_offset, 0)
$$;

create or replace function public.count_listings(
  p_q text default null, p_category text default null, p_brand text default null, p_country text default null,
  p_city text default null, p_min numeric default null, p_max numeric default null, p_currency text default null,
  p_condition text default null, p_in_stock boolean default false, p_delivery boolean default false,
  p_exchange boolean default false, p_since_days int default null, p_shop uuid default null, p_seller uuid default null
) returns bigint
language sql stable
set search_path = public, extensions
as $$
  select count(*) from public.search_listings_base(p_q, p_category, p_brand, p_country, p_city, p_min, p_max, p_currency,
         p_condition, p_in_stock, p_delivery, p_exchange, p_since_days, p_shop, p_seller)
$$;

grant execute on function public.search_tsquery(text), public.search_listings_base(text, text, text, text, text, numeric, numeric, text, text, boolean, boolean, boolean, int, uuid, uuid),
  public.search_listings(text, text, text, text, text, numeric, numeric, text, text, boolean, boolean, boolean, int, uuid, uuid, text, int, int),
  public.count_listings(text, text, text, text, text, numeric, numeric, text, text, boolean, boolean, boolean, int, uuid, uuid)
  to anon, authenticated;

-- ===== supabase/migrations/0007_realtime.sql =====
-- WiFiMarket — Realtime : messages (chat) et notifications.
-- La RLS reste appliquée par Supabase Realtime : un utilisateur ne reçoit que les lignes qu'il a le droit de lire.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end;
  end if;
end $$;

-- ===== supabase/migrations/0008_verification.sql =====
-- WiFiMarket — demandes de vérification (vendeur / boutique). Le statut « verified » n'est posé que par le personnel.

create or replace function public.request_verification(p_shop uuid default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  perform set_config('wm.bypass', '1', true);
  if p_shop is null then
    update public.profiles set verification_status = 'pending'
     where id = auth.uid() and verification_status in ('unverified','rejected');
  else
    if not public.is_shop_member(p_shop) then raise exception 'not_allowed'; end if;
    update public.shops set verification_status = 'pending'
     where id = p_shop and verification_status in ('unverified','rejected');
  end if;
  perform set_config('wm.bypass', '', true);
end $$;

revoke execute on function public.request_verification(uuid) from public, anon;
grant execute on function public.request_verification(uuid) to authenticated;

-- ===== supabase/migrations/0009_gdpr.sql =====
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

-- ===== supabase/migrations/0010_fix_function_search_path.sql =====
-- WiFiMarket — durcissement signalé par l'assistant de sécurité Supabase (search_path figé)
alter function public.set_updated_at() set search_path = public;
alter function public.wm_bypass() set search_path = public;
alter function public.profiles_guard() set search_path = public;
alter function public.shops_guard() set search_path = public;

-- ===== supabase/migrations/0011_purge_demo.sql =====
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
