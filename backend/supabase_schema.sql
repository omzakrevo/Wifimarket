-- =====================================================================
-- ZoneHub — schéma Supabase (Postgres) pour la marketplace SaaS
-- Boutiques multi-vendeurs + annonces d'occasion + comptes par pays
-- À exécuter dans Supabase > SQL Editor.
-- =====================================================================

-- ---------- Pays ----------
create table public.countries (
  code          char(2) primary key,
  name          text not null,
  currency      text not null,           -- XOF, XAF, GHS, NGN
  symbol        text not null,
  rate_per_xof  numeric(12,6) not null default 1,
  phone_prefix  text not null,
  is_active     boolean not null default true
);

insert into public.countries (code, name, currency, symbol, rate_per_xof, phone_prefix) values
  ('BF','Burkina Faso','XOF','FCFA',1,'+226'),
  ('CI','Côte d''Ivoire','XOF','FCFA',1,'+225'),
  ('ML','Mali','XOF','FCFA',1,'+223'),
  ('SN','Sénégal','XOF','FCFA',1,'+221'),
  ('NE','Niger','XOF','FCFA',1,'+227'),
  ('TG','Togo','XOF','FCFA',1,'+228'),
  ('BJ','Bénin','XOF','FCFA',1,'+229'),
  ('CM','Cameroun','XAF','FCFA',1,'+237'),
  ('GH','Ghana','GHS','GH₵',0.025,'+233'),
  ('NG','Nigeria','NGN','₦',2.6,'+234');

-- ---------- Profils ----------
-- Chaque visiteur obtient un compte anonyme Supabase (signInAnonymously)
-- rattaché à un pays. Un même appareil peut avoir un compte par pays.
create type public.user_role as enum ('visitor', 'seller', 'admin');

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null,
  country_code  char(2) not null references public.countries (code),
  role          public.user_role not null default 'visitor',
  phone         text,
  created_at    timestamptz not null default now()
);
create index on public.profiles (country_code);

-- ---------- Boutiques (tenants SaaS) ----------
create type public.shop_status as enum ('pending', 'active', 'suspended');
create type public.plan_tier   as enum ('starter', 'pro', 'business');

create table public.plans (
  tier            public.plan_tier primary key,
  monthly_xof     integer not null,
  product_limit   integer not null,
  commission_pct  numeric(4,2) not null,
  featured        boolean not null default false
);
insert into public.plans values
  ('starter', 0,     10,     8, false),
  ('pro',     15000, 200,    5, false),
  ('business',35000, 100000, 3, true);

create table public.shops (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references public.profiles (id),
  name          text not null,
  slug          text unique,
  phone         text not null,
  city          text not null,
  country_code  char(2) not null references public.countries (code),
  description   text,
  logo_url      text,
  status        public.shop_status not null default 'pending',
  plan          public.plan_tier not null default 'starter',
  verified      boolean not null default false,
  plan_expires_at timestamptz,
  created_at    timestamptz not null default now()
);
create index on public.shops (country_code, status);

-- ---------- Catalogue ----------
create table public.categories (
  id    text primary key,
  name  text not null,
  icon  text,
  sort  int not null default 0
);
insert into public.categories (id, name, sort) values
  ('routers','Routeurs & Hotspot',1), ('ap','Antennes & AP',2),
  ('ptp','Point-à-point',3), ('switch','Switch & PoE',4),
  ('cables','Câbles & Connectique',5), ('power','Énergie & Solaire',6),
  ('sat','Starlink & Satellite',7), ('vouchers','Tickets & Gestion',8);

create table public.products (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references public.shops (id) on delete cascade,
  category_id   text not null references public.categories (id),
  name          text not null,
  brand         text,
  description   text,
  specs         text[] not null default '{}',
  price_xof     integer not null check (price_xof >= 0),
  old_price_xof integer,
  stock         integer not null default 0,
  image_urls    text[] not null default '{}',
  badge         text,
  rating        numeric(2,1) not null default 0,
  reviews       integer not null default 0,
  is_published  boolean not null default true,
  created_at    timestamptz not null default now()
);
create index on public.products (shop_id);
create index on public.products (category_id);

-- Limite de produits selon l'abonnement de la boutique.
create or replace function public.enforce_product_limit() returns trigger
language plpgsql as $$
declare lim int; cnt int;
begin
  select p.product_limit into lim
    from public.shops s join public.plans p on p.tier = s.plan
   where s.id = new.shop_id;
  select count(*) into cnt from public.products where shop_id = new.shop_id;
  if cnt >= lim then
    raise exception 'Limite de % produits atteinte pour ce plan', lim;
  end if;
  return new;
end $$;
create trigger trg_product_limit before insert on public.products
  for each row execute function public.enforce_product_limit();

-- ---------- Annonces d'occasion ----------
create type public.listing_condition as enum ('like_new', 'good', 'fair', 'for_parts');
create type public.listing_status    as enum ('pending', 'published', 'rejected', 'sold');

create table public.listings (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id),
  country_code  char(2) not null references public.countries (code),
  city          text not null,
  category_id   text not null references public.categories (id),
  title         text not null,
  description   text,
  price_xof     integer not null,
  negotiable    boolean not null default true,
  condition     public.listing_condition not null,
  status        public.listing_status not null default 'pending',
  seller_name   text not null,
  seller_phone  text not null,
  image_urls    text[] not null default '{}',
  views         integer not null default 0,
  created_at    timestamptz not null default now()
);
create index on public.listings (country_code, status, created_at desc);

-- ---------- Commandes ----------
create table public.orders (
  id            uuid primary key default gen_random_uuid(),
  buyer_id      uuid not null references public.profiles (id),
  shop_id       uuid not null references public.shops (id),
  country_code  char(2) not null references public.countries (code),
  total_xof     integer not null,
  payment_method text not null,            -- orange_money, moov_money, wave, cod
  status        text not null default 'new',
  created_at    timestamptz not null default now()
);
create table public.order_items (
  order_id   uuid references public.orders (id) on delete cascade,
  product_id uuid references public.products (id),
  qty        integer not null,
  price_xof  integer not null,
  primary key (order_id, product_id)
);

-- =====================================================================
-- Sécurité (Row Level Security)
-- =====================================================================
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

alter table public.profiles    enable row level security;
alter table public.shops       enable row level security;
alter table public.products    enable row level security;
alter table public.listings    enable row level security;
alter table public.orders      enable row level security;
alter table public.order_items enable row level security;
alter table public.countries   enable row level security;
alter table public.categories  enable row level security;
alter table public.plans       enable row level security;

create policy "lecture publique" on public.countries  for select using (true);
create policy "lecture publique" on public.categories for select using (true);
create policy "lecture publique" on public.plans      for select using (true);

-- Profils : chacun lit/modifie le sien ; l'admin voit tout.
create policy "mon profil" on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "créer mon profil" on public.profiles for insert with check (id = auth.uid() and role = 'visitor');
create policy "modifier mon profil" on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid() and role = (select role from public.profiles where id = auth.uid()));
create policy "admin gère profils" on public.profiles for update using (public.is_admin());

-- Boutiques : actives visibles par tous ; le propriétaire voit la sienne ;
-- la création est toujours « pending / starter / non vérifiée » ;
-- seul l'admin change statut, plan payant et badge.
create policy "boutiques visibles" on public.shops for select
  using (status = 'active' or owner_id = auth.uid() or public.is_admin());
create policy "demande de boutique" on public.shops for insert
  with check (owner_id = auth.uid() and status = 'pending' and verified = false);
create policy "propriétaire modifie infos" on public.shops for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid()
              and status = (select status from public.shops s where s.id = shops.id)
              and verified = (select verified from public.shops s where s.id = shops.id)
              and plan = (select plan from public.shops s where s.id = shops.id));
create policy "admin gère boutiques" on public.shops for all using (public.is_admin());

-- Produits : visibles si la boutique est active ; gérés par le propriétaire de boutique active.
create policy "produits visibles" on public.products for select using (
  exists (select 1 from public.shops s where s.id = shop_id and (s.status = 'active' or s.owner_id = auth.uid()))
  or public.is_admin());
create policy "vendeur gère ses produits" on public.products for all using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid() and s.status = 'active'))
  with check (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid() and s.status = 'active'));
create policy "admin gère produits" on public.products for all using (public.is_admin());

-- Annonces : publiées visibles ; l'auteur voit les siennes ; création en « pending ».
create policy "annonces visibles" on public.listings for select
  using (status = 'published' or user_id = auth.uid() or public.is_admin());
create policy "publier une annonce" on public.listings for insert
  with check (user_id = auth.uid() and status = 'pending');
create policy "auteur marque vendu" on public.listings for update
  using (user_id = auth.uid()) with check (user_id = auth.uid() and status in ('pending','sold'));
create policy "admin modère" on public.listings for all using (public.is_admin());

-- Commandes : l'acheteur et la boutique concernée.
create policy "mes commandes" on public.orders for select using (
  buyer_id = auth.uid()
  or exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = auth.uid())
  or public.is_admin());
create policy "passer commande" on public.orders for insert with check (buyer_id = auth.uid());
create policy "lignes de commande" on public.order_items for select using (
  exists (select 1 from public.orders o where o.id = order_id and (
    o.buyer_id = auth.uid()
    or exists (select 1 from public.shops s where s.id = o.shop_id and s.owner_id = auth.uid())
    or public.is_admin())));
create policy "ajouter lignes" on public.order_items for insert with check (
  exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid()));

-- ---------- Statistiques admin ----------
create or replace view public.admin_country_stats with (security_invoker = true) as
select c.code, c.name,
  (select count(*) from public.profiles p where p.country_code = c.code) as accounts,
  (select count(*) from public.shops s where s.country_code = c.code and s.status = 'active') as active_shops,
  (select count(*) from public.listings l where l.country_code = c.code and l.status = 'published') as listings,
  (select coalesce(sum(pl.monthly_xof),0) from public.shops s join public.plans pl on pl.tier = s.plan
     where s.country_code = c.code and s.status = 'active') as mrr_xof
from public.countries c;

-- Pour créer le premier admin (remplacez l'UUID) :
-- update public.profiles set role = 'admin' where id = '00000000-0000-0000-0000-000000000000';
