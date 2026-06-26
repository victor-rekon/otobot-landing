export type AppRole = 'owner' | 'admin' | 'sales' | 'supervisor' | 'staff' | 'viewer';

export type ItemType = 'raw_material' | 'finished_good' | 'packaging' | 'consumable' | 'other';

export type SalesOrderStatus =
  | 'draft'
  | 'stock_check'
  | 'reserved'
  | 'needs_production'
  | 'in_production'
  | 'ready_to_ship'
  | 'fulfilled'
  | 'cancelled';

export type SalesOrderItemStatus =
  | 'pending'
  | 'reserved'
  | 'short_production'
  | 'ready_to_fulfill'
  | 'fulfilled'
  | 'cancelled';

export type ProductionStatus =
  | 'draft'
  | 'planned'
  | 'materials_reserved'
  | 'tasks_assigned'
  | 'in_progress'
  | 'proof_review'
  | 'approved'
  | 'confirmed'
  | 'cancelled';

export type TaskStatus =
  | 'open'
  | 'assigned'
  | 'in_progress'
  | 'submitted'
  | 'revision_requested'
  | 'approved'
  | 'rejected'
  | 'done'
  | 'cancelled';

export type TaskPriority = 'low' | 'normal' | 'high' | 'urgent';

export type ProofStatus = 'submitted' | 'approved' | 'rejected';

export type StockMovementType =
  | 'opening_balance'
  | 'sales_issue'
  | 'production_material_issue'
  | 'production_output'
  | 'adjustment_in'
  | 'adjustment_out'
  | 'transfer_in'
  | 'transfer_out'
  | 'return_in'
  | 'damage_out';

export interface CreateSalesOrderLineInput {
  product_id: string;
  qty_ordered: number;
  unit_price: number;
  notes?: string | null;
}

export interface CreateSalesOrderInput {
  customer_name: string;
  customer_phone?: string | null;
  target_ship_date?: string | null;
  notes?: string | null;
  lines: CreateSalesOrderLineInput[];
}

export interface CreateTaskInput {
  production_batch_id?: string | null;
  title: string;
  description?: string | null;
  priority?: TaskPriority;
  assigned_to?: string | null;
  due_at?: string | null;
}

export interface StockAdjustmentInput {
  item_id: string;
  location_id: string;
  movement_type: 'adjustment_in' | 'adjustment_out' | 'damage_out' | 'return_in';
  quantity_delta: number;
  reason: string;
}
