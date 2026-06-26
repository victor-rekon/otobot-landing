-- Youngpro Backend
-- Migration 002: Functions, triggers, stock reservation, production confirmation

-- =========================
-- GENERIC HELPERS
-- =========================
create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.fn_generate_doc_no(p_doc_key text, p_prefix text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next integer;
  v_period text;
begin
  v_period := to_char(now(), 'YYYYMM');

  insert into public.doc_sequences(doc_key, last_no)
  values (p_doc_key || '-' || v_period, 0)
  on conflict (doc_key) do nothing;

  update public.doc_sequences
  set last_no = last_no + 1,
      updated_at = now()
  where doc_key = p_doc_key || '-' || v_period
  returning last_no into v_next;

  return p_prefix || '-' || v_period || '-' || lpad(v_next::text, 5, '0');
end;
$$;

create or replace function public.fn_default_location(p_location_type public.location_type)
returns uuid
language plpgsql
stable
set search_path = public
as $$
declare
  v_location_id uuid;
begin
  select id into v_location_id
  from public.locations
  where location_type = p_location_type
    and is_active = true
  order by is_default desc, created_at asc
  limit 1;

  if v_location_id is null then
    raise exception 'No active location found for type %', p_location_type;
  end if;

  return v_location_id;
end;
$$;

create or replace function public.tg_generate_sales_order_no()
returns trigger
language plpgsql
as $$
begin
  if new.order_no is null or trim(new.order_no) = '' then
    new.order_no := public.fn_generate_doc_no('sales_order', 'SO');
  end if;
  return new;
end;
$$;

create or replace function public.tg_generate_production_batch_no()
returns trigger
language plpgsql
as $$
begin
  if new.batch_no is null or trim(new.batch_no) = '' then
    new.batch_no := public.fn_generate_doc_no('production_batch', 'PB');
  end if;
  return new;
end;
$$;

create or replace function public.tg_generate_task_no()
returns trigger
language plpgsql
as $$
begin
  if new.task_no is null or trim(new.task_no) = '' then
    new.task_no := public.fn_generate_doc_no('task', 'TASK');
  end if;
  return new;
end;
$$;

-- =========================
-- STOCK MOVEMENT ENGINE
-- =========================
create or replace function public.fn_apply_stock_movement(
  p_item_id uuid,
  p_location_id uuid,
  p_movement_type public.stock_movement_type,
  p_quantity_delta numeric,
  p_reference_type text default null,
  p_reference_id uuid default null,
  p_reference_line_id uuid default null,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_movement_id uuid;
  v_new_on_hand numeric(18,4);
begin
  if p_quantity_delta = 0 then
    raise exception 'Stock movement quantity_delta cannot be zero';
  end if;

  insert into public.stock_balances(item_id, location_id, on_hand, reserved)
  values (p_item_id, p_location_id, 0, 0)
  on conflict (item_id, location_id) do nothing;

  update public.stock_balances
  set on_hand = on_hand + p_quantity_delta,
      updated_at = now()
  where item_id = p_item_id
    and location_id = p_location_id
  returning on_hand into v_new_on_hand;

  if v_new_on_hand < 0 then
    raise exception 'Insufficient stock. item_id %, location_id %, attempted delta %, resulting stock %',
      p_item_id, p_location_id, p_quantity_delta, v_new_on_hand;
  end if;

  insert into public.stock_movements(
    item_id, location_id, movement_type, quantity_delta,
    reference_type, reference_id, reference_line_id,
    reason, metadata, created_by
  ) values (
    p_item_id, p_location_id, p_movement_type, p_quantity_delta,
    p_reference_type, p_reference_id, p_reference_line_id,
    p_reason, coalesce(p_metadata, '{}'::jsonb), auth.uid()
  ) returning id into v_movement_id;

  return v_movement_id;
end;
$$;

-- =========================
-- SALES STOCK CHECK + RESERVATION
-- =========================
create or replace function public.fn_check_sales_order_stock(p_sales_order_id uuid)
returns table (
  sales_order_item_id uuid,
  product_id uuid,
  finished_item_id uuid,
  qty_ordered numeric,
  qty_reserved numeric,
  qty_remaining numeric,
  on_hand numeric,
  already_reserved numeric,
  available numeric,
  shortage numeric
)
language sql
stable
set search_path = public
as $$
  with default_fg as (
    select public.fn_default_location('finished_goods_warehouse'::public.location_type) as location_id
  )
  select
    soi.id as sales_order_item_id,
    soi.product_id,
    pc.item_id as finished_item_id,
    soi.qty_ordered,
    soi.qty_reserved,
    greatest(soi.qty_ordered - soi.qty_reserved, 0) as qty_remaining,
    coalesce(sb.on_hand, 0) as on_hand,
    coalesce(sb.reserved, 0) as already_reserved,
    greatest(coalesce(sb.available, 0), 0) as available,
    greatest((soi.qty_ordered - soi.qty_reserved) - greatest(coalesce(sb.available, 0), 0), 0) as shortage
  from public.sales_order_items soi
  join public.product_catalog pc on pc.id = soi.product_id
  cross join default_fg dfg
  left join public.stock_balances sb
    on sb.item_id = pc.item_id
   and sb.location_id = dfg.location_id
  where soi.sales_order_id = p_sales_order_id
    and soi.status <> 'cancelled';
$$;

create or replace function public.fn_create_production_batch(
  p_product_id uuid,
  p_qty_planned numeric,
  p_sales_order_id uuid default null,
  p_sales_order_item_id uuid default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch_id uuid;
  v_raw_location_id uuid;
begin
  if p_qty_planned <= 0 then
    raise exception 'Production qty must be greater than zero';
  end if;

  v_raw_location_id := public.fn_default_location('raw_material_warehouse'::public.location_type);

  insert into public.production_batches(
    batch_no, product_id, sales_order_id, sales_order_item_id,
    qty_planned, status, notes, created_by
  ) values (
    '', p_product_id, p_sales_order_id, p_sales_order_item_id,
    p_qty_planned, 'planned', p_notes, auth.uid()
  ) returning id into v_batch_id;

  insert into public.production_batch_materials(
    production_batch_id, raw_item_id, location_id, planned_qty, status
  )
  select
    v_batch_id,
    bom.raw_item_id,
    v_raw_location_id,
    round((bom.qty_per_unit * p_qty_planned * (1 + (bom.scrap_percent / 100.0)))::numeric, 4),
    'planned'
  from public.product_bom bom
  where bom.product_id = p_product_id;

  if not exists (select 1 from public.production_batch_materials where production_batch_id = v_batch_id) then
    raise exception 'Product % has no BOM. Cannot create production batch.', p_product_id;
  end if;

  return v_batch_id;
end;
$$;

create or replace function public.fn_reserve_sales_order(p_sales_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_fg_location_id uuid;
  v_reserve_qty numeric(18,4);
  v_shortage numeric(18,4);
  v_current_available numeric(18,4);
  v_created_batches integer := 0;
  v_reserved_lines integer := 0;
  v_has_shortage boolean := false;
begin
  v_fg_location_id := public.fn_default_location('finished_goods_warehouse'::public.location_type);

  update public.sales_orders
  set status = 'stock_check', updated_at = now()
  where id = p_sales_order_id
    and status not in ('fulfilled', 'cancelled');

  for r in select * from public.fn_check_sales_order_stock(p_sales_order_id) where qty_remaining > 0 loop
    insert into public.stock_balances(item_id, location_id, on_hand, reserved)
    values (r.finished_item_id, v_fg_location_id, 0, 0)
    on conflict (item_id, location_id) do nothing;

    perform 1 from public.stock_balances
    where item_id = r.finished_item_id and location_id = v_fg_location_id
    for update;

    select greatest(available, 0) into v_current_available
    from public.stock_balances
    where item_id = r.finished_item_id and location_id = v_fg_location_id;

    v_reserve_qty := least(r.qty_remaining, coalesce(v_current_available, 0));
    v_shortage := greatest(r.qty_remaining - v_reserve_qty, 0);

    if v_reserve_qty > 0 then
      update public.stock_balances
      set reserved = reserved + v_reserve_qty, updated_at = now()
      where item_id = r.finished_item_id and location_id = v_fg_location_id;

      insert into public.stock_reservations(
        item_id, location_id, source_type, source_id, source_line_id,
        qty, status, created_by
      ) values (
        r.finished_item_id, v_fg_location_id, 'sales_order', p_sales_order_id,
        r.sales_order_item_id, v_reserve_qty, 'active', auth.uid()
      );

      update public.sales_order_items
      set qty_reserved = qty_reserved + v_reserve_qty,
          status = case when qty_reserved + v_reserve_qty >= qty_ordered then 'reserved' else 'short_production' end,
          updated_at = now()
      where id = r.sales_order_item_id;

      v_reserved_lines := v_reserved_lines + 1;
    end if;

    if v_shortage > 0 then
      v_has_shortage := true;
      if not exists (
        select 1 from public.production_batches
        where sales_order_item_id = r.sales_order_item_id
          and status not in ('confirmed', 'cancelled')
      ) then
        perform public.fn_create_production_batch(
          r.product_id,
          v_shortage,
          p_sales_order_id,
          r.sales_order_item_id,
          'Auto-created from sales order shortage'
        );
        v_created_batches := v_created_batches + 1;
      end if;

      update public.sales_order_items
      set status = 'short_production', updated_at = now()
      where id = r.sales_order_item_id;
    end if;
  end loop;

  update public.sales_orders
  set status = case when v_has_shortage then 'needs_production' else 'reserved' end,
      updated_at = now()
  where id = p_sales_order_id
    and status not in ('fulfilled', 'cancelled');

  return jsonb_build_object(
    'sales_order_id', p_sales_order_id,
    'reserved_lines', v_reserved_lines,
    'created_production_batches', v_created_batches,
    'has_shortage', v_has_shortage
  );
end;
$$;

create or replace function public.fn_release_sales_order_reservation(
  p_sales_order_id uuid,
  p_reason text default 'Reservation released'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_released_count integer := 0;
begin
  for r in
    select * from public.stock_reservations
    where source_type = 'sales_order'
      and source_id = p_sales_order_id
      and status = 'active'
    for update
  loop
    update public.stock_balances
    set reserved = reserved - r.qty, updated_at = now()
    where item_id = r.item_id and location_id = r.location_id;

    update public.stock_reservations
    set status = 'released', updated_at = now()
    where id = r.id;

    update public.sales_order_items
    set qty_reserved = greatest(qty_reserved - r.qty, 0),
        status = 'pending',
        updated_at = now()
    where id = r.source_line_id;

    v_released_count := v_released_count + 1;
  end loop;

  update public.sales_orders
  set status = 'draft', notes = coalesce(notes, '') || E'\nReservation released: ' || p_reason,
      updated_at = now()
  where id = p_sales_order_id and status not in ('fulfilled', 'cancelled');

  return jsonb_build_object('sales_order_id', p_sales_order_id, 'released_reservations', v_released_count);
end;
$$;

create or replace function public.fn_fulfill_sales_order(
  p_sales_order_id uuid,
  p_reason text default 'Sales order fulfilled'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_fulfilled_lines integer := 0;
begin
  if exists (
    select 1 from public.sales_order_items
    where sales_order_id = p_sales_order_id
      and status <> 'cancelled'
      and qty_reserved < qty_ordered
  ) then
    raise exception 'Cannot fulfill sales order %. Some lines are not fully reserved.', p_sales_order_id;
  end if;

  for r in
    select sr.*, pc.item_id as finished_item_id
    from public.stock_reservations sr
    join public.sales_order_items soi on soi.id = sr.source_line_id
    join public.product_catalog pc on pc.id = soi.product_id
    where sr.source_type = 'sales_order'
      and sr.source_id = p_sales_order_id
      and sr.status = 'active'
    for update
  loop
    update public.stock_balances
    set reserved = reserved - r.qty, updated_at = now()
    where item_id = r.item_id and location_id = r.location_id;

    perform public.fn_apply_stock_movement(
      r.item_id, r.location_id, 'sales_issue', -r.qty,
      'sales_order', p_sales_order_id, r.source_line_id,
      p_reason, '{}'::jsonb
    );

    update public.stock_reservations
    set status = 'consumed', updated_at = now()
    where id = r.id;

    update public.sales_order_items
    set qty_fulfilled = qty_fulfilled + r.qty,
        status = 'fulfilled',
        updated_at = now()
    where id = r.source_line_id;

    v_fulfilled_lines := v_fulfilled_lines + 1;
  end loop;

  update public.sales_orders
  set status = 'fulfilled', updated_at = now()
  where id = p_sales_order_id;

  return jsonb_build_object('sales_order_id', p_sales_order_id, 'fulfilled_lines', v_fulfilled_lines);
end;
$$;

-- =========================
-- PRODUCTION MATERIALS + PROOF
-- =========================
create or replace function public.fn_reserve_production_materials(p_production_batch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_available numeric(18,4);
  v_reserved_lines integer := 0;
begin
  for r in
    select * from public.production_batch_materials
    where production_batch_id = p_production_batch_id
      and status = 'planned'
    for update
  loop
    insert into public.stock_balances(item_id, location_id, on_hand, reserved)
    values (r.raw_item_id, r.location_id, 0, 0)
    on conflict (item_id, location_id) do nothing;

    perform 1 from public.stock_balances
    where item_id = r.raw_item_id and location_id = r.location_id
    for update;

    select greatest(available, 0) into v_available
    from public.stock_balances
    where item_id = r.raw_item_id and location_id = r.location_id;

    if coalesce(v_available, 0) < r.planned_qty then
      raise exception 'Insufficient raw material for batch %. raw_item %, required %, available %',
        p_production_batch_id, r.raw_item_id, r.planned_qty, coalesce(v_available, 0);
    end if;

    update public.stock_balances
    set reserved = reserved + r.planned_qty, updated_at = now()
    where item_id = r.raw_item_id and location_id = r.location_id;

    insert into public.stock_reservations(
      item_id, location_id, source_type, source_id, source_line_id,
      qty, status, created_by
    ) values (
      r.raw_item_id, r.location_id, 'production_batch', p_production_batch_id, r.id,
      r.planned_qty, 'active', auth.uid()
    );

    update public.production_batch_materials
    set reserved_qty = planned_qty, status = 'reserved', updated_at = now()
    where id = r.id;

    v_reserved_lines := v_reserved_lines + 1;
  end loop;

  update public.production_batches
  set status = 'materials_reserved', updated_at = now()
  where id = p_production_batch_id and status not in ('confirmed', 'cancelled');

  return jsonb_build_object('production_batch_id', p_production_batch_id, 'reserved_material_lines', v_reserved_lines);
end;
$$;

create or replace function public.fn_submit_proof_of_work(
  p_task_id uuid,
  p_file_url text,
  p_file_path text default null,
  p_file_name text default null,
  p_mime_type text default null,
  p_file_size_bytes bigint default null,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_proof_id uuid;
begin
  insert into public.proof_of_work(
    task_id, submitted_by, file_url, file_path, file_name,
    mime_type, file_size_bytes, notes, status
  ) values (
    p_task_id, auth.uid(), p_file_url, p_file_path, p_file_name,
    p_mime_type, p_file_size_bytes, p_notes, 'submitted'
  ) returning id into v_proof_id;

  update public.tasks
  set status = 'submitted', submitted_at = now(), updated_at = now()
  where id = p_task_id;

  update public.production_batches pb
  set status = 'proof_review', updated_at = now()
  from public.tasks t
  where t.id = p_task_id
    and t.production_batch_id = pb.id
    and pb.status not in ('confirmed', 'cancelled');

  return v_proof_id;
end;
$$;

create or replace function public.fn_review_proof_of_work(
  p_proof_id uuid,
  p_approved boolean,
  p_review_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_task_id uuid;
  v_batch_id uuid;
begin
  update public.proof_of_work
  set status = case when p_approved then 'approved'::public.proof_status else 'rejected'::public.proof_status end,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_note = p_review_note,
      updated_at = now()
  where id = p_proof_id
  returning task_id into v_task_id;

  if v_task_id is null then
    raise exception 'Proof % not found', p_proof_id;
  end if;

  update public.tasks
  set status = case when p_approved then 'approved'::public.task_status else 'revision_requested'::public.task_status end,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_note = p_review_note,
      updated_at = now()
  where id = v_task_id
  returning production_batch_id into v_batch_id;

  if p_approved and v_batch_id is not null and not exists (
    select 1 from public.tasks
    where production_batch_id = v_batch_id
      and status not in ('approved', 'done', 'cancelled')
  ) then
    update public.production_batches
    set status = 'approved', updated_at = now()
    where id = v_batch_id and status not in ('confirmed', 'cancelled');
  end if;

  return jsonb_build_object('proof_id', p_proof_id, 'task_id', v_task_id, 'approved', p_approved);
end;
$$;

create or replace function public.fn_confirm_production_batch(
  p_production_batch_id uuid,
  p_actual_output numeric default null,
  p_reason text default 'Production confirmed'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch record;
  v_fg_item_id uuid;
  v_fg_location_id uuid;
  r record;
  v_actual_output numeric(18,4);
  v_material_actual numeric(18,4);
  v_deducted_lines integer := 0;
begin
  select * into v_batch
  from public.production_batches
  where id = p_production_batch_id
  for update;

  if not found then
    raise exception 'Production batch % not found', p_production_batch_id;
  end if;

  if v_batch.status in ('confirmed', 'cancelled') then
    raise exception 'Production batch % cannot be confirmed from status %', p_production_batch_id, v_batch.status;
  end if;

  if exists (
    select 1 from public.tasks
    where production_batch_id = p_production_batch_id
      and status not in ('approved', 'done', 'cancelled')
  ) then
    raise exception 'Cannot confirm production batch %. Some tasks are not approved.', p_production_batch_id;
  end if;

  if exists (
    select 1 from public.production_batch_materials
    where production_batch_id = p_production_batch_id
      and status <> 'reserved'
  ) then
    raise exception 'Cannot confirm production batch %. Materials are not fully reserved.', p_production_batch_id;
  end if;

  v_actual_output := coalesce(p_actual_output, v_batch.qty_planned);
  if v_actual_output <= 0 then
    raise exception 'Actual production output must be greater than zero';
  end if;

  select pc.item_id into v_fg_item_id
  from public.product_catalog pc
  where pc.id = v_batch.product_id;

  v_fg_location_id := public.fn_default_location('finished_goods_warehouse'::public.location_type);

  for r in
    select * from public.production_batch_materials
    where production_batch_id = p_production_batch_id
    for update
  loop
    v_material_actual := coalesce(r.actual_qty, r.planned_qty);

    if v_material_actual > r.reserved_qty then
      raise exception 'Actual raw material usage cannot exceed reserved qty. material_line %, actual %, reserved %',
        r.id, v_material_actual, r.reserved_qty;
    end if;

    update public.stock_balances
    set reserved = reserved - r.reserved_qty, updated_at = now()
    where item_id = r.raw_item_id and location_id = r.location_id;

    perform public.fn_apply_stock_movement(
      r.raw_item_id, r.location_id, 'production_material_issue', -v_material_actual,
      'production_batch', p_production_batch_id, r.id,
      p_reason, jsonb_build_object('planned_qty', r.planned_qty, 'actual_qty', v_material_actual)
    );

    update public.stock_reservations
    set status = 'consumed', updated_at = now()
    where source_type = 'production_batch'
      and source_id = p_production_batch_id
      and source_line_id = r.id
      and status = 'active';

    update public.production_batch_materials
    set actual_qty = v_material_actual,
        status = 'deducted',
        deducted_at = now(),
        updated_at = now()
    where id = r.id;

    v_deducted_lines := v_deducted_lines + 1;
  end loop;

  perform public.fn_apply_stock_movement(
    v_fg_item_id, v_fg_location_id, 'production_output', v_actual_output,
    'production_batch', p_production_batch_id, null,
    p_reason, jsonb_build_object('product_id', v_batch.product_id)
  );

  update public.production_batches
  set qty_output_actual = v_actual_output,
      status = 'confirmed',
      confirmed_at = now(),
      confirmed_by = auth.uid(),
      updated_at = now()
  where id = p_production_batch_id;

  if v_batch.sales_order_id is not null then
    perform public.fn_reserve_sales_order(v_batch.sales_order_id);
  end if;

  return jsonb_build_object(
    'production_batch_id', p_production_batch_id,
    'actual_output', v_actual_output,
    'deducted_material_lines', v_deducted_lines
  );
end;
$$;

-- =========================
-- ACTIVITY LOG + TRIGGERS
-- =========================
create or replace function public.tg_log_status_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    if row_to_json(old)::jsonb <> row_to_json(new)::jsonb then
      insert into public.activity_logs(actor_id, action, entity_type, entity_id, before_state, after_state)
      values (auth.uid(), lower(tg_table_name) || '_updated', tg_table_name, new.id, row_to_json(old)::jsonb, row_to_json(new)::jsonb);
    end if;
  elsif tg_op = 'INSERT' then
    insert into public.activity_logs(actor_id, action, entity_type, entity_id, after_state)
    values (auth.uid(), lower(tg_table_name) || '_created', tg_table_name, new.id, row_to_json(new)::jsonb);
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'user_profiles', 'app_settings', 'units', 'locations', 'item_master', 'product_catalog', 'product_bom',
    'stock_reservations', 'sales_orders', 'sales_order_items', 'production_batches',
    'production_batch_materials', 'tasks', 'proof_of_work'
  ] loop
    execute format('drop trigger if exists trg_%s_updated_at on public.%I', t, t);
    execute format('create trigger trg_%s_updated_at before update on public.%I for each row execute function public.tg_set_updated_at()', t, t);
  end loop;
end $$;

drop trigger if exists trg_sales_order_no on public.sales_orders;
create trigger trg_sales_order_no
before insert on public.sales_orders
for each row execute function public.tg_generate_sales_order_no();

drop trigger if exists trg_production_batch_no on public.production_batches;
create trigger trg_production_batch_no
before insert on public.production_batches
for each row execute function public.tg_generate_production_batch_no();

drop trigger if exists trg_task_no on public.tasks;
create trigger trg_task_no
before insert on public.tasks
for each row execute function public.tg_generate_task_no();

do $$
declare
  t text;
begin
  foreach t in array array[
    'sales_orders', 'sales_order_items', 'production_batches', 'production_batch_materials', 'tasks', 'proof_of_work'
  ] loop
    execute format('drop trigger if exists trg_%s_activity on public.%I', t, t);
    execute format('create trigger trg_%s_activity after insert or update on public.%I for each row execute function public.tg_log_status_change()', t, t);
  end loop;
end $$;
