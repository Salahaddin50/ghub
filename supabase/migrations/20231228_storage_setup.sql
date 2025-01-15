-- Create storage bucket for profile photos
insert into storage.buckets (id, name, public, avif_autodetection, file_size_limit, allowed_mime_types)
values ('profile-photos', 'profile-photos', true, false, 5242880, array['image/jpeg', 'image/png', 'image/gif', 'image/webp']);

-- Create policy to allow authenticated users to upload their own photos
create policy "Users can upload their own photos"
on storage.objects for insert
to authenticated
with check (
    bucket_id = 'profile-photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Create policy to allow authenticated users to update their own photos
create policy "Users can update their own photos"
on storage.objects for update
to authenticated
using (
    bucket_id = 'profile-photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Create policy to allow authenticated users to delete their own photos
create policy "Users can delete their own photos"
on storage.objects for delete
to authenticated
using (
    bucket_id = 'profile-photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
);

-- Create policy to allow public access to view photos
create policy "Anyone can view photos"
on storage.objects for select
to public
using (bucket_id = 'profile-photos');
