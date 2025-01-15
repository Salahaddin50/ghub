-- Drop existing policies
drop policy if exists "Users can read tasks" on tasks;
drop policy if exists "Users can create tasks if they own the target" on tasks;
drop policy if exists "Users can update tasks if they own the target" on tasks;
drop policy if exists "Users can delete tasks if they own the target" on tasks;

-- Disable and re-enable RLS
alter table tasks disable row level security;
alter table tasks enable row level security;

-- Create policies
create policy "tasks_select_policy"
  on tasks for select
  using (true);

create policy "tasks_insert_policy"
  on tasks for insert
  with check (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = (
          select action_id from steps where id = tasks.step_id
        )
      )
      and user_id = auth.uid()
    )
  );

create policy "tasks_update_policy"
  on tasks for update
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = (
          select action_id from steps where id = tasks.step_id
        )
      )
      and user_id = auth.uid()
    )
  );

create policy "tasks_delete_policy"
  on tasks for delete
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = (
          select action_id from steps where id = tasks.step_id
        )
      )
      and user_id = auth.uid()
    )
  );
