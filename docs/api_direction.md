# API Direction — Supabase + Frontend

This is the backend API direction for a Next.js/Supabase web app.

Use direct table CRUD for simple master data. Use RPC functions for stock, reservation, production confirmation, and proof review because those operations must be transactional.

## 1. Authentication

Use Supabase Auth.

After a user is created in Supabase Auth, insert one row into:

```txt
public.user_profiles
```

Required fields:

```txt
id = auth.users.id
full_name
role
is_active
```

## 2. Dashboard API

### Read summary

```ts
supabase.from('v_dashboard_summary').select('*').single()
```

### Read task board

```ts
supabase.from('v_task_board').select('*').order('due_at')
```

### Read low stock

```ts
supabase.from('v_low_stock_items').select('*').order('available')
```

## 3. Product Catalog API

### List products

```ts
supabase
  .from('product_catalog')
  .select('*, item_master(*, units(*)), product_bom(*, item_master(*))')
  .eq('is_active', true)
```

### Create product

1. Create finished-good item in `item_master`.
2. Create product in `product_catalog`.
3. Create BOM rows in `product_bom`.

Use one frontend transaction flow or create an Edge Function later if product creation becomes complex.

## 4. Master Barang API

### List all items

```ts
supabase
  .from('item_master')
  .select('*, units(*)')
  .order('item_code')
```

### Filter raw materials

```ts
supabase
  .from('item_master')
  .select('*, units(*)')
  .eq('item_type', 'raw_material')
```

### Filter finished goods

```ts
supabase
  .from('item_master')
  .select('*, units(*)')
  .eq('item_type', 'finished_good')
```

## 5. Stock API

### Read current stock

```ts
supabase
  .from('v_stock_position')
  .select('*')
  .order('item_code')
```

### Read stock card

```ts
supabase
  .from('v_stock_card')
  .select('*')
  .eq('item_code', itemCode)
  .order('created_at')
```

### Manual stock adjustment

Use RPC. Do not update `stock_balances` directly.

```ts
supabase.rpc('fn_apply_stock_movement', {
  p_item_id: itemId,
  p_location_id: locationId,
  p_movement_type: 'adjustment_in',
  p_quantity_delta: 10,
  p_reference_type: 'manual_adjustment',
  p_reference_id: null,
  p_reference_line_id: null,
  p_reason: 'Stock opname correction',
  p_metadata: {}
})
```

Use negative quantity for adjustment out:

```txt
p_movement_type = adjustment_out
p_quantity_delta = -5
```

## 6. Sales Order API

### Create order draft

```ts
const { data: order } = await supabase
  .from('sales_orders')
  .insert({
    order_no: '',
    customer_name: 'Customer Name',
    customer_phone: '08...',
    target_ship_date: '2026-07-01',
    status: 'draft',
    notes: 'Optional'
  })
  .select('*')
  .single()
```

Then insert lines:

```ts
await supabase.from('sales_order_items').insert([
  {
    sales_order_id: order.id,
    product_id: productId,
    qty_ordered: 60,
    unit_price: 45000,
    status: 'pending'
  }
])
```

### Check stock without reservation

```ts
supabase.rpc('fn_check_sales_order_stock', {
  p_sales_order_id: orderId
})
```

### Reserve stock / create production shortage

```ts
supabase.rpc('fn_reserve_sales_order', {
  p_sales_order_id: orderId
})
```

Backend result:

```json
{
  "sales_order_id": "...",
  "reserved_lines": 2,
  "created_production_batches": 1,
  "has_shortage": true
}
```

### Release reservation

```ts
supabase.rpc('fn_release_sales_order_reservation', {
  p_sales_order_id: orderId,
  p_reason: 'Customer changed order'
})
```

### Fulfill order

```ts
supabase.rpc('fn_fulfill_sales_order', {
  p_sales_order_id: orderId,
  p_reason: 'Shipment processed'
})
```

## 7. Production Batch API

### List production batches

```ts
supabase
  .from('v_production_batch_progress')
  .select('*')
  .order('planned_finish_date')
```

### Create manual production batch

```ts
supabase.rpc('fn_create_production_batch', {
  p_product_id: productId,
  p_qty_planned: 100,
  p_sales_order_id: null,
  p_sales_order_item_id: null,
  p_notes: 'Manual production planning'
})
```

### Reserve raw materials

```ts
supabase.rpc('fn_reserve_production_materials', {
  p_production_batch_id: batchId
})
```

### Confirm production

```ts
supabase.rpc('fn_confirm_production_batch', {
  p_production_batch_id: batchId,
  p_actual_output: 98,
  p_reason: 'Batch completed and checked'
})
```

## 8. Task Delegation API

### Create task

```ts
supabase.from('tasks').insert({
  task_no: '',
  production_batch_id: batchId,
  title: 'Prepare raw material',
  description: 'Prepare plastic granule and aluminum pole based on BOM',
  priority: 'high',
  status: 'open',
  assigned_to: staffUserId,
  due_at: '2026-07-01T10:00:00+07:00'
})
```

### Staff starts task

```ts
supabase
  .from('tasks')
  .update({ status: 'in_progress', started_at: new Date().toISOString() })
  .eq('id', taskId)
```

### Submit proof

Upload file first to private Supabase Storage bucket `proof-of-work`, then call:

```ts
supabase.rpc('fn_submit_proof_of_work', {
  p_task_id: taskId,
  p_file_url: publicOrSignedUrl,
  p_file_path: storagePath,
  p_file_name: file.name,
  p_mime_type: file.type,
  p_file_size_bytes: file.size,
  p_notes: 'Work completed'
})
```

### Supervisor reviews proof

```ts
supabase.rpc('fn_review_proof_of_work', {
  p_proof_id: proofId,
  p_approved: true,
  p_review_note: 'Approved. Continue batch confirmation.'
})
```

Reject:

```ts
supabase.rpc('fn_review_proof_of_work', {
  p_proof_id: proofId,
  p_approved: false,
  p_review_note: 'Photo unclear. Please reupload after recount.'
})
```

## 9. Reports API

### Sales fulfillment report

```ts
supabase
  .from('v_sales_order_fulfillment')
  .select('*')
  .gte('order_date', '2026-06-01')
  .lte('order_date', '2026-06-30')
```

### Open shortage report

```ts
supabase
  .from('v_open_order_shortage')
  .select('*')
  .order('shortage', { ascending: false })
```

### Production progress report

```ts
supabase
  .from('v_production_batch_progress')
  .select('*')
  .in('status', ['planned', 'materials_reserved', 'tasks_assigned', 'in_progress', 'proof_review', 'approved'])
```

### Stock movement report

```ts
supabase
  .from('v_stock_card')
  .select('*')
  .gte('created_at', fromDate)
  .lte('created_at', toDate)
```

## 10. Recommended Frontend Pages

| Page | Backend Source |
|---|---|
| Dashboard | `v_dashboard_summary`, `v_task_board`, `v_low_stock_items` |
| Product Catalog | `product_catalog`, `product_bom`, `item_master` |
| Sales Order | `sales_orders`, `sales_order_items`, RPC reservation/fulfillment |
| Master Barang | `item_master`, `units` |
| Bahan Baku | `item_master where item_type=raw_material`, `v_stock_position` |
| Barang Jadi | `item_master where item_type=finished_good`, `v_stock_position` |
| Stock Movement | `v_stock_card`, `fn_apply_stock_movement` |
| Production Batch | `production_batches`, `production_batch_materials`, RPC reserve/confirm |
| Task Delegation | `tasks`, `v_task_board` |
| Proof of Work | `proof_of_work`, Storage bucket, RPC review |
| Reports | Report views |
| Users & Roles | `user_profiles` |
| Settings | `app_settings` |
| Activity Logs | `activity_logs` |
