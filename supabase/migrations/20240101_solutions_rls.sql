-- Drop existing policies
drop policy if exists "Users can read solutions" on solutions;
drop policy if exists "Users can create solutions if they own the target" on solutions;
drop policy if exists "Users can update solutions if they own the target" on solutions;
drop policy if exists "Users can delete solutions if they own the target" on solutions;
drop policy if exists "solutions_select_policy" on solutions;
drop policy if exists "solutions_insert_policy" on solutions;
drop policy if exists "solutions_update_policy" on solutions;
drop policy if exists "solutions_delete_policy" on solutions;

-- Disable and re-enable RLS
alter table solutions disable row level security;
alter table solutions enable row level security;

-- Create simple policies
create policy "solutions_select_policy"
  on solutions for select
  using (true);

create policy "solutions_insert_policy"
  on solutions for insert
  with check (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = (
          select action_id from obstacles where id = solutions.obstacle_id
        )
      )
      and user_id = auth.uid()
    )
  );

create policy "solutions_update_policy"
  on solutions for update
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = (
          select action_id from obstacles where id = solutions.obstacle_id
        )
      )
      and user_id = auth.uid()
    )
  );

create policy "solutions_delete_policy"
  on solutions for delete
  using (
    exists (
      select 1 from targets
      where id = (
        select target_id from actions where id = (
          select action_id from obstacles where id = solutions.obstacle_id
        )
      )
      and user_id = auth.uid()
    )
  );
