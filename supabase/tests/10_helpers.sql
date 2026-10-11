create schema t;
grant usage on schema t to public;
create function t.uid(k text) returns uuid language sql stable security definer as $$ select id from auth.users where email = k || '@demo.wifimarket.test' $$;
create function t.login(k text) returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', t.uid(k), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function t.anon() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role anon';
end $$;
create function t.root() returns void language plpgsql as $$
begin execute 'reset role'; perform set_config('request.jwt.claims', '', true); end $$;
create function t.ok(cond boolean, msg text) returns void language plpgsql as $$
begin if cond is not true then raise exception 'ÉCHEC: %', msg; end if; raise notice 'ok - %', msg; end $$;
create function t.fails(stmt text, msg text) returns void language plpgsql as $$
declare failed boolean := false;
begin
  begin execute stmt; exception when others then failed := true; end;
  if not failed then raise exception 'ÉCHEC (aucune erreur levée): %', msg; end if;
  raise notice 'ok - % (refusé)', msg;
end $$;
create function t.n(stmt text) returns bigint language plpgsql as $$
declare r bigint; begin execute 'select count(*) from (' || stmt || ') s' into r; return r; end $$;
grant execute on all functions in schema t to public;
-- Succès si l'instruction est refusée OU n'affecte aucune ligne (RLS filtre silencieusement)
create function t.blocked(stmt text, msg text) returns void language plpgsql as $$
declare n bigint := 0;
begin
  begin execute stmt; get diagnostics n = row_count;
  exception when others then n := 0; end;
  if n > 0 then raise exception 'ÉCHEC (% ligne(s) modifiée(s)): %', n, msg; end if;
  raise notice 'ok - % (bloqué)', msg;
end $$;
grant execute on function t.blocked(text, text) to public;
create function t.conv_bi() returns uuid language sql stable security definer
as $$ select id from public.conversations where user_a = t.uid('demo_buyer') and user_b = t.uid('ibrahim') $$;
grant execute on function t.conv_bi() to public;
