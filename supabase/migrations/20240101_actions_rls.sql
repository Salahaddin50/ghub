-- Drop all policies
drop policy if exists "Everyone can view actions" on actions;
drop policy if exists "Users can read actions" on actions;
drop policy if exists "Users can insert actions for their own targets" on actions;
drop policy if exists "Users can update actions of their own targets" on actions;
drop policy if exists "Users can delete actions of their own targets" on actions;
drop policy if exists "actions_select_policy" on actions;
drop policy if exists "actions_insert_policy" on actions;
drop policy if exists "actions_update_policy" on actions;
drop policy if exists "actions_delete_policy" on actions;

-- Disable and re-enable RLS
alter table actions disable row level security;
alter table actions enable row level security;

-- Create simple policies
create policy "actions_select_policy"
  on actions for select
  using (true);

create policy "actions_insert_policy"
  on actions for insert
  with check (
    exists (
      select 1 from targets
      where id = target_id
      and user_id = auth.uid()
    )
  );

create policy "actions_update_policy"
  on actions for update
  using (
    exists (
      select 1 from targets
      where id = target_id
      and user_id = auth.uid()
    )
  );

create policy "actions_delete_policy"
  on actions for delete
  using (
    exists (
      select 1 from targets
      where id = target_id
      and user_id = auth.uid()
    )
  );
