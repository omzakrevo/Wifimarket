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
