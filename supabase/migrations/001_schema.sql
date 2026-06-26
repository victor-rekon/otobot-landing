-- Youngpro Cleaning Tools Inventory + Production + Task Management System
-- Migration 001: Core schema
-- Target: Supabase PostgreSQL

create extension if not exists pgcrypto;

-- =========================
-- ENUMS
-- =========================
do $$ begin
  create type public.app_role as enum ('owner', 'admin', 'sales', 'supervisor', 'staff', 'viewer');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.item_type as enum ('raw_material', 'finished_good', 'packaging', 'consumable', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.location_type as enum ('raw_material_warehouse', 'finished_goods_warehouse', 'wip', 'virtual', 'other');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.sales_order_status as enum (
    'draft',
    'stock_check',
    'reserved',
    'needs_production',
    'in_production',
    'ready_to_ship',
    'fulfilled',
    'cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.sales_order_item_status as enum (
    'pending',
    'reserved',
    'short_production',
    'ready_to_fulfill',
    'fulfilled',
    'cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.production_status as enum (
    'draft',
    'planned',
    'materials_reserved',
    'tasks_assigned',
    'in_progress',
    'proof_review',
    'approved',
    'confirmed',
    'cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.material_line_status as enum ('planned', 'reserved', 'deducted', 'released', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.task_status as enum (
    'open',
    'assigned',
    'in_progress',
    'submitted',
    'revision_requested',
    'approved',
    'rejected',
    'done',
    'cancelled'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.task_priority as enum ('low', 'normal', 'high', 'urgent');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.proof_status as enum ('submitted', 'approved', 'rejected');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.reservation_status as enum ('active', 'released', 'consumed', 'cancelled');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.stock_movement_type as enum (
    'opening_balance',
    'sales_issue',
    'production_material_issue',
    'production_output',
    'adjustment_in',
    'adjustment_out',
    'transfer_in',
    'transfer_out',
    'return_in',
    'damage_out'
  );
exception when duplicate_object then null; end $$;

-- =========================
-- AUTH / USERS / SETTINGS
-- =========================
create table if not exists public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role public.app_role not null default 'staff',
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null,
  description text,
  updated_by uuid references public.user_profiles(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.doc_sequences (
  doc_key text primary key,
  last_no integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.user_profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_state jsonb,
  after_state jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- =========================
-- MASTER DATA
-- =========================
create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  unit_code text not null unique,
  unit_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  location_code text not null unique,
  location_name text not null,
  location_type public.location_type not null,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.item_master (
  id uuid primary key default gen_random_uuid(),
  item_code text not null unique,
  item_name text not null,
  item_type public.item_type not null,
  unit_id uuid not null references public.units(id),
  min_stock numeric(18,4) not null default 0 check (min_stock >= 0),
  reorder_qty numeric(18,4) not null default 0 check (reorder_qty >= 0),
  default_supplier text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_item_master_type on public.item_master(item_type);
create index if not exists idx_item_master_active on public.item_master(is_active);

-- Product Catalog is only for sellable finished goods.
create table if not exists public.product_catalog (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null unique references public.item_master(id),
  product_name text not null,
  product_code text not null unique,
  default_price numeric(18,2) not null default 0 check (default_price >= 0),
  lead_time_days integer not null default 0 check (lead_time_days >= 0),
  is_make_to_stock boolean not null default true,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_bom (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.product_catalog(id) on delete cascade,
  raw_item_id uuid not null references public.item_master(id),
  qty_per_unit numeric(18,4) not null check (qty_per_unit > 0),
  scrap_percent numeric(8,4) not null default 0 check (scrap_percent >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(product_id, raw_item_id)
);

create index if not exists idx_product_bom_product on public.product_bom(product_id);
create index if not exists idx_product_bom_raw_item on public.product_bom(raw_item_id);

-- =========================
-- INVENTORY
-- =========================
create table if not exists public.stock_balances (
  item_id uuid not null references public.item_master(id),
  location_id uuid not null references public.locations(id),
  on_hand numeric(18,4) not null default 0 check (on_hand >= 0),
  reserved numeric(18,4) not null default 0 check (reserved >= 0),
  available numeric(18,4) generated always as (on_hand - reserved) stored,
  updated_at timestamptz not null default now(),
  primary key (item_id, location_id),
  constraint stock_reserved_lte_on_hand check (reserved <= on_hand)
);

create index if not exists idx_stock_balances_location on public.stock_balances(location_id);
create index if not exists idx_stock_balances_available on public.stock_balances(available);

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.item_master(id),
  location_id uuid not null references public.locations(id),
  movement_type public.stock_movement_type not null,
  quantity_delta numeric(18,4) not null check (quantity_delta <> 0),
  reference_type text,
  reference_id uuid,
  reference_line_id uuid,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.user_profiles(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_stock_movements_item_date on public.stock_movements(item_id, created_at desc);
create index if not exists idx_stock_movements_ref on public.stock_movements(reference_type, reference_id);

create table if not exists public.stock_reservations (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.item_master(id),
  location_id uuid not null references public.locations(id),
  source_type text not null, -- sales_order / production_batch
  source_id uuid not null,
  source_line_id uuid,
  qty numeric(18,4) not null check (qty > 0),
  status public.reservation_status not null default 'active',
  created_by uuid references public.user_profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_stock_reservations_source on public.stock_reservations(source_type, source_id, status);
create index if not exists idx_stock_reservations_item on public.stock_reservations(item_id, location_id, status);

-- =========================
-- SALES ORDER
-- =========================
create table if not exists public.sales_orders (
  id uuid primary key default gen_random_uuid(),
  order_no text not null unique,
  customer_name text not null,
  customer_phone text,
  order_date date not null default current_date,
  target_ship_date date,
  status public.sales_order_status not null default 'draft',
  notes text,
  created_by uuid references public.user_profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references public.user_profiles(id),
  cancel_reason text
);

create index if not exists idx_sales_orders_status on public.sales_orders(status);
create index if not exists idx_sales_orders_order_date on public.sales_orders(order_date desc);

create table if not exists public.sales_order_items (
  id uuid primary key default gen_random_uuid(),
  sales_order_id uuid not null references public.sales_orders(id) on delete cascade,
  product_id uuid not null references public.product_catalog(id),
  qty_ordered numeric(18,4) not null check (qty_ordered > 0),
  qty_reserved numeric(18,4) not null default 0 check (qty_reserved >= 0),
  qty_fulfilled numeric(18,4) not null default 0 check (qty_fulfilled >= 0),
  unit_price numeric(18,2) not null default 0 check (unit_price >= 0),
  line_total numeric(18,2) generated always as (qty_ordered * unit_price) stored,
  status public.sales_order_item_status not null default 'pending',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint soi_reserved_lte_ordered check (qty_reserved <= qty_ordered),
  constraint soi_fulfilled_lte_ordered check (qty_fulfilled <= qty_ordered)
);

create index if not exists idx_sales_order_items_order on public.sales_order_items(sales_order_id);
create index if not exists idx_sales_order_items_product on public.sales_order_items(product_id);

-- =========================
-- PRODUCTION
-- =========================
create table if not exists public.production_batches (
  id uuid primary key default gen_random_uuid(),
  batch_no text not null unique,
  product_id uuid not null references public.product_catalog(id),
  sales_order_id uuid references public.sales_orders(id),
  sales_order_item_id uuid references public.sales_order_items(id),
  qty_planned numeric(18,4) not null check (qty_planned > 0),
  qty_output_actual numeric(18,4) not null default 0 check (qty_output_actual >= 0),
  status public.production_status not null default 'planned',
  planned_start_date date,
  planned_finish_date date,
  confirmed_at timestamptz,
  confirmed_by uuid references public.user_profiles(id),
  notes text,
  created_by uuid references public.user_profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references public.user_profiles(id),
  cancel_reason text
);

create index if not exists idx_production_batches_status on public.production_batches(status);
create index if not exists idx_production_batches_product on public.production_batches(product_id);
create index if not exists idx_production_batches_sales_order on public.production_batches(sales_order_id);

create table if not exists public.production_batch_materials (
  id uuid primary key default gen_random_uuid(),
  production_batch_id uuid not null references public.production_batches(id) on delete cascade,
  raw_item_id uuid not null references public.item_master(id),
  location_id uuid references public.locations(id),
  planned_qty numeric(18,4) not null check (planned_qty > 0),
  reserved_qty numeric(18,4) not null default 0 check (reserved_qty >= 0),
  actual_qty numeric(18,4) check (actual_qty is null or actual_qty >= 0),
  status public.material_line_status not null default 'planned',
  deducted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(production_batch_id, raw_item_id)
);

create index if not exists idx_batch_materials_batch on public.production_batch_materials(production_batch_id);
create index if not exists idx_batch_materials_raw_item on public.production_batch_materials(raw_item_id);

-- =========================
-- TASK DELEGATION + PROOF OF WORK
-- =========================
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  task_no text not null unique,
  production_batch_id uuid references public.production_batches(id) on delete set null,
  title text not null,
  description text,
  priority public.task_priority not null default 'normal',
  status public.task_status not null default 'open',
  assigned_to uuid references public.user_profiles(id),
  assigned_by uuid references public.user_profiles(id),
  due_at timestamptz,
  started_at timestamptz,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reviewed_by uuid references public.user_profiles(id),
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancel_reason text
);

create index if not exists idx_tasks_assigned_to on public.tasks(assigned_to, status);
create index if not exists idx_tasks_batch on public.tasks(production_batch_id);
create index if not exists idx_tasks_status on public.tasks(status);

create table if not exists public.proof_of_work (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  submitted_by uuid not null references public.user_profiles(id),
  file_url text not null,
  file_path text,
  file_name text,
  mime_type text,
  file_size_bytes bigint,
  notes text,
  status public.proof_status not null default 'submitted',
  reviewed_by uuid references public.user_profiles(id),
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_proof_task on public.proof_of_work(task_id);
create index if not exists idx_proof_status on public.proof_of_work(status);
