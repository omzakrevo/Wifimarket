-- WiFiMarket — durcissement signalé par l'assistant de sécurité Supabase (search_path figé)
alter function public.set_updated_at() set search_path = public;
alter function public.wm_bypass() set search_path = public;
alter function public.profiles_guard() set search_path = public;
alter function public.shops_guard() set search_path = public;
