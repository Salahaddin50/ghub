-- Drop all policies
drop policy if exists "Users can read steps" on steps;
drop policy if exists "Users can create steps if they own the target" on steps;
drop policy if exists "Users can update steps if they own the target" on steps;
drop policy if exists "Users can delete steps if they own the target" on steps;
drop policy if exists "steps_select_policy" on steps;
drop policy if exists "steps_insert_policy" on steps;
drop policy if exists "steps_update_policy" on steps;
drop policy if exists "steps_delete_policy" on steps;

-- Disable and re-enable RLS
alter table steps disable row level security;
alter table steps enable row level security;

-- Create simple policies
create policy "steps_select_policy"
  on steps for select
  using (true);

create policy "steps_insert_policy"
  on steps for insert
  with check (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = steps.action_id
      )
      and user_id = auth.uid()
    )
  );

create policy "steps_update_policy"
  on steps for update
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = steps.action_id
      )
      and user_id = auth.uid()
    )
  );

create policy "steps_delete_policy"
  on steps for delete
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = steps.action_id
      )
      and user_id = auth.uid()
    )
  );
