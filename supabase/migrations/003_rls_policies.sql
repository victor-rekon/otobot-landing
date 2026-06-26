-- Youngpro Backend
-- Migration 003: Row Level Security baseline
-- This is a practical internal-app baseline. Tighten further after real staff structure is known.

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.user_profiles
  where id = auth.uid()
    and is_active = true
  limit 1;
$$;

create or replace function public.is_admin_like()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_app_role() in ('owner', 'admin'), false);
$$;

create or replace function public.is_supervisor_like()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_app_role() in ('owner', 'admin', 'supervisor'), false);
$$;

create or replace function public.is_sales_like()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_app_role() in ('owner', 'admin', 'sales', 'supervisor'), false);
$$;

-- Enable RLS on all public operational tables.
do $$
declare
  t text;
begin
  foreach t in array array[
    'user_profiles', 'app_settings', 'doc_sequences', 'activity_logs',
    'units', 'locations', 'item_master', 'product_catalog', 'product_bom',
    'stock_balances', 'stock_movements', 'stock_reservations',
    'sales_orders', 'sales_order_items',
    'production_batches', 'production_batch_materials',
    'tasks', 'proof_of_work'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Clean old policies if rerun during development.
do $$
declare
  r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- User profiles
create policy "profiles_select_self_or_admin" on public.user_profiles
for select using (id = auth.uid() or public.is_admin_like());

create policy "profiles_admin_insert" on public.user_profiles
for insert with check (public.is_admin_like());

create policy "profiles_admin_update" on public.user_profiles
for update using (public.is_admin_like()) with check (public.is_admin_like());

-- Master data: everyone authenticated can read, admin owns mutation.
do $$
declare
  t text;
begin
  foreach t in array array['units', 'locations', 'item_master', 'product_catalog', 'product_bom'] loop
    execute format('create policy %I on public.%I for select using (auth.uid() is not null)', t || '_read_all_authenticated', t);
    execute format('create policy %I on public.%I for insert with check (public.is_admin_like())', t || '_admin_insert', t);
    execute format('create policy %I on public.%I for update using (public.is_admin_like()) with check (public.is_admin_like())', t || '_admin_update', t);
    execute format('create policy %I on public.%I for delete using (public.is_admin_like())', t || '_admin_delete', t);
  end loop;
end $$;

-- Settings and sequences: admin only.
do $$
declare
  t text;
begin
  foreach t in array array['app_settings', 'doc_sequences'] loop
    execute format('create policy %I on public.%I for select using (public.is_admin_like())', t || '_admin_select', t);
    execute format('create policy %I on public.%I for insert with check (public.is_admin_like())', t || '_admin_insert', t);
    execute format('create policy %I on public.%I for update using (public.is_admin_like()) with check (public.is_admin_like())', t || '_admin_update', t);
  end loop;
end $$;

-- Inventory visibility: authenticated users can read stock.
-- Direct mutation is intentionally blocked by absence of insert/update/delete policies.
-- All stock changes must go through RPC functions, otherwise stock_balances and stock_movements can drift.
do $$
declare
  t text;
begin
  foreach t in array array['stock_balances', 'stock_movements', 'stock_reservations'] loop
    execute format('create policy %I on public.%I for select using (auth.uid() is not null)', t || '_read_all_authenticated', t);
  end loop;
end $$;

-- Sales order: sales/supervisor/admin can create and update; authenticated can read for internal visibility.
do $$
declare
  t text;
begin
  foreach t in array array['sales_orders', 'sales_order_items'] loop
    execute format('create policy %I on public.%I for select using (auth.uid() is not null)', t || '_read_all_authenticated', t);
    execute format('create policy %I on public.%I for insert with check (public.is_sales_like())', t || '_sales_insert', t);
    execute format('create policy %I on public.%I for update using (public.is_sales_like()) with check (public.is_sales_like())', t || '_sales_update', t);
    execute format('create policy %I on public.%I for delete using (public.is_admin_like())', t || '_admin_delete', t);
  end loop;
end $$;

-- Production: supervisors/admin mutate, staff can read assigned batch context.
create policy "production_batches_select_internal" on public.production_batches
for select using (
  auth.uid() is not null
);

create policy "production_batches_supervisor_insert" on public.production_batches
for insert with check (public.is_supervisor_like());

create policy "production_batches_supervisor_update" on public.production_batches
for update using (public.is_supervisor_like()) with check (public.is_supervisor_like());

create policy "production_batches_admin_delete" on public.production_batches
for delete using (public.is_admin_like());

create policy "batch_materials_select_internal" on public.production_batch_materials
for select using (auth.uid() is not null);

create policy "batch_materials_supervisor_insert" on public.production_batch_materials
for insert with check (public.is_supervisor_like());

create policy "batch_materials_supervisor_update" on public.production_batch_materials
for update using (public.is_supervisor_like()) with check (public.is_supervisor_like());

create policy "batch_materials_admin_delete" on public.production_batch_materials
for delete using (public.is_admin_like());

-- Tasks: supervisor/admin can manage all; staff can read and update their assigned task status.
create policy "tasks_select_related" on public.tasks
for select using (
  public.is_supervisor_like()
  or assigned_to = auth.uid()
  or assigned_by = auth.uid()
);

create policy "tasks_supervisor_insert" on public.tasks
for insert with check (public.is_supervisor_like());

create policy "tasks_supervisor_update_all" on public.tasks
for update using (public.is_supervisor_like()) with check (public.is_supervisor_like());

create policy "tasks_staff_update_own_progress" on public.tasks
for update using (
  assigned_to = auth.uid()
  and status in ('assigned', 'in_progress', 'revision_requested')
) with check (
  assigned_to = auth.uid()
);

create policy "tasks_admin_delete" on public.tasks
for delete using (public.is_admin_like());

-- Proof: assigned staff can submit/read own proof; supervisor/admin can review all.
create policy "proof_select_related" on public.proof_of_work
for select using (
  public.is_supervisor_like()
  or submitted_by = auth.uid()
  or exists (
    select 1 from public.tasks t
    where t.id = proof_of_work.task_id
      and t.assigned_to = auth.uid()
  )
);

create policy "proof_staff_insert_own_task" on public.proof_of_work
for insert with check (
  submitted_by = auth.uid()
  and exists (
    select 1 from public.tasks t
    where t.id = proof_of_work.task_id
      and t.assigned_to = auth.uid()
  )
);

create policy "proof_supervisor_update" on public.proof_of_work
for update using (public.is_supervisor_like()) with check (public.is_supervisor_like());

create policy "proof_admin_delete" on public.proof_of_work
for delete using (public.is_admin_like());

-- Activity logs: internal read, system/admin write.
create policy "activity_logs_select_internal" on public.activity_logs
for select using (auth.uid() is not null);

create policy "activity_logs_insert_internal" on public.activity_logs
for insert with check (auth.uid() is not null);

-- NOTE: Supabase Storage policy recommendation for proof files:
-- Bucket: proof-of-work
-- Path convention: proof-of-work/{task_id}/{filename}
-- Staff may upload only when they are assigned to the task.
-- Supervisors/admin can read/review all proof files.
