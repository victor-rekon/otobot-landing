export const SALES_ORDER_STATUS = {
  DRAFT: 'draft',
  STOCK_CHECK: 'stock_check',
  RESERVED: 'reserved',
  NEEDS_PRODUCTION: 'needs_production',
  IN_PRODUCTION: 'in_production',
  READY_TO_SHIP: 'ready_to_ship',
  FULFILLED: 'fulfilled',
  CANCELLED: 'cancelled',
} as const;

export const PRODUCTION_STATUS = {
  DRAFT: 'draft',
  PLANNED: 'planned',
  MATERIALS_RESERVED: 'materials_reserved',
  TASKS_ASSIGNED: 'tasks_assigned',
  IN_PROGRESS: 'in_progress',
  PROOF_REVIEW: 'proof_review',
  APPROVED: 'approved',
  CONFIRMED: 'confirmed',
  CANCELLED: 'cancelled',
} as const;

export const TASK_STATUS = {
  OPEN: 'open',
  ASSIGNED: 'assigned',
  IN_PROGRESS: 'in_progress',
  SUBMITTED: 'submitted',
  REVISION_REQUESTED: 'revision_requested',
  APPROVED: 'approved',
  REJECTED: 'rejected',
  DONE: 'done',
  CANCELLED: 'cancelled',
} as const;

export const STOCK_MOVEMENT_TYPE = {
  OPENING_BALANCE: 'opening_balance',
  SALES_ISSUE: 'sales_issue',
  PRODUCTION_MATERIAL_ISSUE: 'production_material_issue',
  PRODUCTION_OUTPUT: 'production_output',
  ADJUSTMENT_IN: 'adjustment_in',
  ADJUSTMENT_OUT: 'adjustment_out',
  TRANSFER_IN: 'transfer_in',
  TRANSFER_OUT: 'transfer_out',
  RETURN_IN: 'return_in',
  DAMAGE_OUT: 'damage_out',
} as const;

export const PROOF_BUCKET = 'proof-of-work';
