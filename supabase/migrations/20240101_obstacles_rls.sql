-- Drop all policies
drop policy if exists "Users can read obstacles" on obstacles;
drop policy if exists "Users can create obstacles if they own the target" on obstacles;
drop policy if exists "Users can update obstacles if they own the target" on obstacles;
drop policy if exists "Users can delete obstacles if they own the target" on obstacles;
drop policy if exists "obstacles_select_policy" on obstacles;
drop policy if exists "obstacles_insert_policy" on obstacles;
drop policy if exists "obstacles_update_policy" on obstacles;
drop policy if exists "obstacles_delete_policy" on obstacles;

-- Disable and re-enable RLS
alter table obstacles disable row level security;
alter table obstacles enable row level security;

-- Create simple policies
create policy "obstacles_select_policy"
  on obstacles for select
  using (true);

create policy "obstacles_insert_policy"
  on obstacles for insert
  with check (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = obstacles.action_id
      )
      and user_id = auth.uid()
    )
  );

create policy "obstacles_update_policy"
  on obstacles for update
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = obstacles.action_id
      )
      and user_id = auth.uid()
    )
  );

create policy "obstacles_delete_policy"
  on obstacles for delete
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = obstacles.action_id
      )
      and user_id = auth.uid()
    )
  );
