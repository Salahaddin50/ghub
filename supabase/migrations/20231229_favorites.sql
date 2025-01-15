-- Create favorites table
create table public.favorites (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) on delete cascade not null,
    target_id uuid references public.targets(id) on delete cascade not null,
    is_favorite boolean default true not null,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    unique(user_id, target_id)
);

-- Set up RLS policies
alter table public.favorites enable row level security;

-- Allow users to view their own favorites
create policy "Users can view their own favorites"
on public.favorites for select
to authenticated
using (auth.uid() = user_id);

-- Allow users to manage their own favorites
create policy "Users can manage their own favorites"
on public.favorites for all
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
