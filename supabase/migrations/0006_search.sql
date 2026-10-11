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
