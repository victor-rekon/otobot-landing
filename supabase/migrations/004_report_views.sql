-- Youngpro Backend
-- Migration 004: Dashboard and report views

create or replace view public.v_stock_position as
select
  im.id as item_id,
  im.item_code,
  im.item_name,
  im.item_type,
  u.unit_code,
  l.id as location_id,
  l.location_code,
  l.location_name,
  sb.on_hand,
  sb.reserved,
  sb.available,
  im.min_stock,
  case
    when sb.available <= im.min_stock then true
    else false
  end as is_low_stock,
  sb.updated_at
from public.stock_balances sb
join public.item_master im on im.id = sb.item_id
join public.units u on u.id = im.unit_id
join public.locations l on l.id = sb.location_id;

create or replace view public.v_low_stock_items as
select *
from public.v_stock_position
where is_low_stock = true;

create or replace view public.v_sales_order_fulfillment as
select
  so.id as sales_order_id,
  so.order_no,
  so.customer_name,
  so.order_date,
  so.target_ship_date,
  so.status as order_status,
  count(soi.id) as line_count,
  sum(soi.qty_ordered) as total_qty_ordered,
  sum(soi.qty_reserved) as total_qty_reserved,
  sum(soi.qty_fulfilled) as total_qty_fulfilled,
  sum(soi.line_total) as order_amount,
  round((sum(soi.qty_reserved) / nullif(sum(soi.qty_ordered), 0) * 100)::numeric, 2) as reservation_percent,
  round((sum(soi.qty_fulfilled) / nullif(sum(soi.qty_ordered), 0) * 100)::numeric, 2) as fulfillment_percent
from public.sales_orders so
join public.sales_order_items soi on soi.sales_order_id = so.id
where so.status <> 'cancelled'
group by so.id, so.order_no, so.customer_name, so.order_date, so.target_ship_date, so.status;

create or replace view public.v_open_order_shortage as
select
  x.sales_order_item_id,
  so.id as sales_order_id,
  so.order_no,
  so.customer_name,
  pc.product_code,
  pc.product_name,
  x.qty_ordered,
  x.qty_reserved,
  x.qty_remaining,
  x.on_hand,
  x.already_reserved,
  x.available,
  x.shortage
from public.sales_orders so
join lateral public.fn_check_sales_order_stock(so.id) x on true
join public.product_catalog pc on pc.id = x.product_id
where so.status not in ('fulfilled', 'cancelled')
  and x.shortage > 0;

create or replace view public.v_production_batch_progress as
select
  pb.id as production_batch_id,
  pb.batch_no,
  pc.product_code,
  pc.product_name,
  pb.qty_planned,
  pb.qty_output_actual,
  pb.status,
  pb.planned_start_date,
  pb.planned_finish_date,
  pb.sales_order_id,
  so.order_no,
  count(t.id) filter (where t.status <> 'cancelled') as total_tasks,
  count(t.id) filter (where t.status in ('approved', 'done')) as approved_tasks,
  count(t.id) filter (where t.status = 'revision_requested') as revision_tasks,
  count(t.id) filter (where t.status in ('submitted')) as submitted_tasks,
  round((count(t.id) filter (where t.status in ('approved', 'done'))::numeric / nullif(count(t.id) filter (where t.status <> 'cancelled'), 0) * 100), 2) as task_approval_percent
from public.production_batches pb
join public.product_catalog pc on pc.id = pb.product_id
left join public.sales_orders so on so.id = pb.sales_order_id
left join public.tasks t on t.production_batch_id = pb.id
group by pb.id, pb.batch_no, pc.product_code, pc.product_name, pb.qty_planned, pb.qty_output_actual, pb.status, pb.planned_start_date, pb.planned_finish_date, pb.sales_order_id, so.order_no;

create or replace view public.v_task_board as
select
  t.id as task_id,
  t.task_no,
  t.title,
  t.priority,
  t.status,
  t.due_at,
  t.production_batch_id,
  pb.batch_no,
  pc.product_name,
  assignee.full_name as assigned_to_name,
  assigner.full_name as assigned_by_name,
  t.started_at,
  t.submitted_at,
  t.reviewed_at,
  t.review_note,
  case
    when t.due_at is not null and t.due_at < now() and t.status not in ('approved', 'done', 'cancelled') then true
    else false
  end as is_overdue
from public.tasks t
left join public.production_batches pb on pb.id = t.production_batch_id
left join public.product_catalog pc on pc.id = pb.product_id
left join public.user_profiles assignee on assignee.id = t.assigned_to
left join public.user_profiles assigner on assigner.id = t.assigned_by;

create or replace view public.v_stock_card as
select
  sm.id as movement_id,
  sm.created_at,
  im.item_code,
  im.item_name,
  im.item_type,
  l.location_code,
  sm.movement_type,
  sm.quantity_delta,
  sum(sm.quantity_delta) over (
    partition by sm.item_id, sm.location_id
    order by sm.created_at asc, sm.id asc
    rows between unbounded preceding and current row
  ) as running_on_hand,
  sm.reference_type,
  sm.reference_id,
  sm.reference_line_id,
  sm.reason,
  up.full_name as created_by_name
from public.stock_movements sm
join public.item_master im on im.id = sm.item_id
join public.locations l on l.id = sm.location_id
left join public.user_profiles up on up.id = sm.created_by;

create or replace view public.v_dashboard_summary as
select
  (select count(*) from public.sales_orders where status in ('draft', 'stock_check', 'reserved', 'needs_production', 'in_production', 'ready_to_ship')) as open_sales_orders,
  (select count(*) from public.sales_orders where status = 'needs_production') as orders_needing_production,
  (select count(*) from public.production_batches where status in ('planned', 'materials_reserved', 'tasks_assigned', 'in_progress', 'proof_review', 'approved')) as open_production_batches,
  (select count(*) from public.tasks where status not in ('approved', 'done', 'cancelled')) as open_tasks,
  (select count(*) from public.v_task_board where is_overdue = true) as overdue_tasks,
  (select count(*) from public.v_low_stock_items) as low_stock_items,
  (select coalesce(sum(order_amount), 0) from public.v_sales_order_fulfillment where order_date >= current_date - interval '30 days') as sales_amount_last_30_days;
