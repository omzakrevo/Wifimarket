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
