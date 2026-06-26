-- Youngpro Backend Seed Data
-- Run after migrations 001-004.
-- This creates realistic dummy master data, stock, BOM, sample sales order, production batch, and task.

-- Units
insert into public.units(unit_code, unit_name) values
  ('PCS', 'Pieces'),
  ('PACK', 'Pack'),
  ('KG', 'Kilogram'),
  ('M', 'Meter'),
  ('ROLL', 'Roll'),
  ('BOX', 'Box')
on conflict (unit_code) do nothing;

-- Locations
insert into public.locations(location_code, location_name, location_type, is_default) values
  ('RAW-WH', 'Raw Material Warehouse', 'raw_material_warehouse', true),
  ('FG-WH', 'Finished Goods Warehouse', 'finished_goods_warehouse', true),
  ('WIP', 'Work In Progress Area', 'wip', true)
on conflict (location_code) do nothing;

-- Raw materials and finished goods
insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty, default_supplier, notes)
select 'RM-PP-001', 'Plastic Granule PP', 'raw_material', id, 50, 100, 'Supplier Plastik Lokal', 'Main plastic input for handles/heads'
from public.units where unit_code = 'KG'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty, default_supplier)
select 'RM-MF-001', 'Microfiber Roll', 'raw_material', id, 20, 50, 'Supplier Kain Microfiber'
from public.units where unit_code = 'ROLL'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty, default_supplier)
select 'RM-AL-001', 'Aluminum Pole', 'raw_material', id, 100, 200, 'Supplier Aluminium'
from public.units where unit_code = 'PCS'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty, default_supplier)
select 'RM-RB-001', 'Rubber Strip 45cm', 'raw_material', id, 150, 300, 'Supplier Karet'
from public.units where unit_code = 'PCS'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty, default_supplier)
select 'RM-PKG-001', 'Packaging Box Small', 'packaging', id, 100, 300, 'Supplier Packaging'
from public.units where unit_code = 'BOX'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty, default_supplier)
select 'RM-STK-001', 'Product Sticker Label', 'packaging', id, 300, 1000, 'Percetakan Label'
from public.units where unit_code = 'PCS'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty)
select 'FG-MOP-001', 'Mop Handle Set', 'finished_good', id, 30, 100
from public.units where unit_code = 'PCS'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty)
select 'FG-MFC-001', 'Microfiber Cloth Pack', 'finished_good', id, 50, 100
from public.units where unit_code = 'PACK'
on conflict (item_code) do nothing;

insert into public.item_master(item_code, item_name, item_type, unit_id, min_stock, reorder_qty)
select 'FG-SQG-001', 'Floor Squeegee 45cm', 'finished_good', id, 30, 100
from public.units where unit_code = 'PCS'
on conflict (item_code) do nothing;

-- Product catalog
insert into public.product_catalog(item_id, product_code, product_name, default_price, lead_time_days, description)
select id, 'YP-MOP-001', 'Youngpro Mop Handle Set', 45000, 3, 'Finished cleaning tool set'
from public.item_master where item_code = 'FG-MOP-001'
on conflict (product_code) do nothing;

insert into public.product_catalog(item_id, product_code, product_name, default_price, lead_time_days, description)
select id, 'YP-MFC-001', 'Youngpro Microfiber Cloth Pack', 25000, 2, 'Microfiber cloth pack for retail/wholesale'
from public.item_master where item_code = 'FG-MFC-001'
on conflict (product_code) do nothing;

insert into public.product_catalog(item_id, product_code, product_name, default_price, lead_time_days, description)
select id, 'YP-SQG-001', 'Youngpro Floor Squeegee 45cm', 38000, 3, 'Floor squeegee with rubber strip'
from public.item_master where item_code = 'FG-SQG-001'
on conflict (product_code) do nothing;

-- BOM: Mop Handle Set
insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent, notes)
select pc.id, im.id, 0.20, 3, 'Plastic component per mop set'
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-MOP-001' and im.item_code = 'RM-PP-001'
on conflict (product_id, raw_item_id) do nothing;

insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 1, 0
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-MOP-001' and im.item_code = 'RM-AL-001'
on conflict (product_id, raw_item_id) do nothing;

insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 1, 0
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-MOP-001' and im.item_code = 'RM-PKG-001'
on conflict (product_id, raw_item_id) do nothing;

insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 1, 0
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-MOP-001' and im.item_code = 'RM-STK-001'
on conflict (product_id, raw_item_id) do nothing;

-- BOM: Microfiber Cloth Pack
insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 0.05, 5
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-MFC-001' and im.item_code = 'RM-MF-001'
on conflict (product_id, raw_item_id) do nothing;

insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 1, 0
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-MFC-001' and im.item_code = 'RM-PKG-001'
on conflict (product_id, raw_item_id) do nothing;

insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 1, 0
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-MFC-001' and im.item_code = 'RM-STK-001'
on conflict (product_id, raw_item_id) do nothing;

-- BOM: Floor Squeegee
insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 0.15, 3
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-SQG-001' and im.item_code = 'RM-PP-001'
on conflict (product_id, raw_item_id) do nothing;

insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 1, 0
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-SQG-001' and im.item_code = 'RM-RB-001'
on conflict (product_id, raw_item_id) do nothing;

insert into public.product_bom(product_id, raw_item_id, qty_per_unit, scrap_percent)
select pc.id, im.id, 1, 0
from public.product_catalog pc, public.item_master im
where pc.product_code = 'YP-SQG-001' and im.item_code = 'RM-PKG-001'
on conflict (product_id, raw_item_id) do nothing;

-- Opening stock via stock movement engine.
select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 250, 'seed', null, null, 'Opening raw material stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'RM-PP-001' and l.location_code = 'RAW-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 80, 'seed', null, null, 'Opening raw material stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'RM-MF-001' and l.location_code = 'RAW-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 300, 'seed', null, null, 'Opening raw material stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'RM-AL-001' and l.location_code = 'RAW-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 200, 'seed', null, null, 'Opening raw material stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'RM-RB-001' and l.location_code = 'RAW-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 500, 'seed', null, null, 'Opening packaging stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'RM-PKG-001' and l.location_code = 'RAW-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 1000, 'seed', null, null, 'Opening label stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'RM-STK-001' and l.location_code = 'RAW-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 25, 'seed', null, null, 'Opening finished goods stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'FG-MOP-001' and l.location_code = 'FG-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 90, 'seed', null, null, 'Opening finished goods stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'FG-MFC-001' and l.location_code = 'FG-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

select public.fn_apply_stock_movement(im.id, l.id, 'opening_balance', 10, 'seed', null, null, 'Opening finished goods stock', '{}'::jsonb)
from public.item_master im, public.locations l
where im.item_code = 'FG-SQG-001' and l.location_code = 'FG-WH'
  and not exists (select 1 from public.stock_movements sm where sm.item_id = im.id and sm.location_id = l.id and sm.movement_type = 'opening_balance');

-- Sample Sales Order that will trigger shortage for Mop Handle Set and Floor Squeegee.
with so as (
  insert into public.sales_orders(order_no, customer_name, customer_phone, order_date, target_ship_date, status, notes)
  values ('', 'PT Contoh Distributor Bersih', '0812-0000-1111', current_date, current_date + interval '7 days', 'draft', 'Seed order: tests reservation + production shortage flow')
  returning id
), line1 as (
  insert into public.sales_order_items(sales_order_id, product_id, qty_ordered, unit_price, status)
  select so.id, pc.id, 60, pc.default_price, 'pending'
  from so, public.product_catalog pc
  where pc.product_code = 'YP-MOP-001'
  returning id
), line2 as (
  insert into public.sales_order_items(sales_order_id, product_id, qty_ordered, unit_price, status)
  select so.id, pc.id, 20, pc.default_price, 'pending'
  from so, public.product_catalog pc
  where pc.product_code = 'YP-SQG-001'
  returning id
)
select public.fn_reserve_sales_order(id) from so;

-- Sample task for the first auto-created production batch.
insert into public.tasks(task_no, production_batch_id, title, description, priority, status, due_at)
select '', pb.id, 'Prepare raw materials for production batch', 'Check and prepare required raw materials based on BOM.', 'high', 'open', now() + interval '1 day'
from public.production_batches pb
where pb.status = 'planned'
order by pb.created_at asc
limit 1;
