import type { SupabaseClient } from '@supabase/supabase-js';
import type { CreateSalesOrderInput, CreateTaskInput, StockAdjustmentInput } from './types';

export async function getDashboardSummary(supabase: SupabaseClient) {
  return supabase.from('v_dashboard_summary').select('*').single();
}

export async function getStockPosition(supabase: SupabaseClient) {
  return supabase.from('v_stock_position').select('*').order('item_code');
}

export async function getLowStockItems(supabase: SupabaseClient) {
  return supabase.from('v_low_stock_items').select('*').order('available');
}

export async function getProductCatalog(supabase: SupabaseClient) {
  return supabase
    .from('product_catalog')
    .select('*, item_master(*, units(*)), product_bom(*, item_master(*, units(*)))')
    .eq('is_active', true)
    .order('product_code');
}

export async function createSalesOrder(supabase: SupabaseClient, input: CreateSalesOrderInput) {
  if (!input.lines?.length) {
    throw new Error('Sales order must have at least one line.');
  }

  const { data: order, error: orderError } = await supabase
    .from('sales_orders')
    .insert({
      order_no: '',
      customer_name: input.customer_name,
      customer_phone: input.customer_phone ?? null,
      target_ship_date: input.target_ship_date ?? null,
      notes: input.notes ?? null,
      status: 'draft',
    })
    .select('*')
    .single();

  if (orderError) throw orderError;

  const linesPayload = input.lines.map((line) => ({
    sales_order_id: order.id,
    product_id: line.product_id,
    qty_ordered: line.qty_ordered,
    unit_price: line.unit_price,
    status: 'pending',
    notes: line.notes ?? null,
  }));

  const { error: linesError } = await supabase.from('sales_order_items').insert(linesPayload);
  if (linesError) throw linesError;

  return order;
}

export async function checkSalesOrderStock(supabase: SupabaseClient, orderId: string) {
  return supabase.rpc('fn_check_sales_order_stock', { p_sales_order_id: orderId });
}

export async function reserveSalesOrder(supabase: SupabaseClient, orderId: string) {
  return supabase.rpc('fn_reserve_sales_order', { p_sales_order_id: orderId });
}

export async function releaseSalesOrderReservation(
  supabase: SupabaseClient,
  orderId: string,
  reason = 'Reservation released'
) {
  return supabase.rpc('fn_release_sales_order_reservation', {
    p_sales_order_id: orderId,
    p_reason: reason,
  });
}

export async function fulfillSalesOrder(
  supabase: SupabaseClient,
  orderId: string,
  reason = 'Sales order fulfilled'
) {
  return supabase.rpc('fn_fulfill_sales_order', {
    p_sales_order_id: orderId,
    p_reason: reason,
  });
}

export async function createProductionBatch(
  supabase: SupabaseClient,
  params: {
    productId: string;
    qtyPlanned: number;
    salesOrderId?: string | null;
    salesOrderItemId?: string | null;
    notes?: string | null;
  }
) {
  return supabase.rpc('fn_create_production_batch', {
    p_product_id: params.productId,
    p_qty_planned: params.qtyPlanned,
    p_sales_order_id: params.salesOrderId ?? null,
    p_sales_order_item_id: params.salesOrderItemId ?? null,
    p_notes: params.notes ?? null,
  });
}

export async function reserveProductionMaterials(supabase: SupabaseClient, batchId: string) {
  return supabase.rpc('fn_reserve_production_materials', { p_production_batch_id: batchId });
}

export async function confirmProductionBatch(
  supabase: SupabaseClient,
  batchId: string,
  actualOutput: number,
  reason = 'Production confirmed'
) {
  return supabase.rpc('fn_confirm_production_batch', {
    p_production_batch_id: batchId,
    p_actual_output: actualOutput,
    p_reason: reason,
  });
}

export async function createTask(supabase: SupabaseClient, input: CreateTaskInput) {
  return supabase
    .from('tasks')
    .insert({
      task_no: '',
      production_batch_id: input.production_batch_id ?? null,
      title: input.title,
      description: input.description ?? null,
      priority: input.priority ?? 'normal',
      status: input.assigned_to ? 'assigned' : 'open',
      assigned_to: input.assigned_to ?? null,
      due_at: input.due_at ?? null,
    })
    .select('*')
    .single();
}

export async function startTask(supabase: SupabaseClient, taskId: string) {
  return supabase
    .from('tasks')
    .update({ status: 'in_progress', started_at: new Date().toISOString() })
    .eq('id', taskId)
    .select('*')
    .single();
}

export async function submitProofOfWork(
  supabase: SupabaseClient,
  params: {
    taskId: string;
    fileUrl: string;
    filePath?: string | null;
    fileName?: string | null;
    mimeType?: string | null;
    fileSizeBytes?: number | null;
    notes?: string | null;
  }
) {
  return supabase.rpc('fn_submit_proof_of_work', {
    p_task_id: params.taskId,
    p_file_url: params.fileUrl,
    p_file_path: params.filePath ?? null,
    p_file_name: params.fileName ?? null,
    p_mime_type: params.mimeType ?? null,
    p_file_size_bytes: params.fileSizeBytes ?? null,
    p_notes: params.notes ?? null,
  });
}

export async function reviewProofOfWork(
  supabase: SupabaseClient,
  proofId: string,
  approved: boolean,
  reviewNote?: string | null
) {
  return supabase.rpc('fn_review_proof_of_work', {
    p_proof_id: proofId,
    p_approved: approved,
    p_review_note: reviewNote ?? null,
  });
}

export async function applyStockAdjustment(supabase: SupabaseClient, input: StockAdjustmentInput) {
  if (input.quantity_delta === 0) throw new Error('Stock adjustment cannot be zero.');

  return supabase.rpc('fn_apply_stock_movement', {
    p_item_id: input.item_id,
    p_location_id: input.location_id,
    p_movement_type: input.movement_type,
    p_quantity_delta: input.quantity_delta,
    p_reference_type: 'manual_adjustment',
    p_reference_id: null,
    p_reference_line_id: null,
    p_reason: input.reason,
    p_metadata: {},
  });
}
