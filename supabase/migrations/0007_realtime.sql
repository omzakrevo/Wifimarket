-- WiFiMarket — Realtime : messages (chat) et notifications.
-- La RLS reste appliquée par Supabase Realtime : un utilisateur ne reçoit que les lignes qu'il a le droit de lire.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end;
  end if;
end $$;
