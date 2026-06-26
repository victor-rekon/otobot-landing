# Business Rules — Youngpro Cleaning Tools System

## 1. Product Catalog Rules

1. A product must link to exactly one finished-good item in `item_master`.
2. Only items with `item_type = finished_good` should be used as sellable products.
3. A product that can be produced internally must have a BOM in `product_bom`.
4. A product without BOM can still exist, but it cannot auto-create a production batch from shortage.
5. Product price in `product_catalog.default_price` is operational reference only, not accounting/tax invoice truth.

## 2. Item Master Rules

1. Every stock item must have a unit.
2. Raw materials, packaging, finished goods, and consumables all live in `item_master`.
3. `min_stock` is used by dashboard/reporting only. It does not auto-purchase stock.
4. `reorder_qty` is recommendation data only.

## 3. Stock Rules

### Stock Fields

| Field | Meaning |
|---|---|
| `on_hand` | Physical stock in warehouse. |
| `reserved` | Stock locked for order or production batch. |
| `available` | `on_hand - reserved`. |

### Physical Stock Movement

Physical stock changes only through `fn_apply_stock_movement()` or a higher-level function that calls it.

Allowed physical movement examples:

| Movement | Quantity Delta | Meaning |
|---|---:|---|
| `opening_balance` | positive | Starting stock. |
| `production_material_issue` | negative | Raw material consumed by production. |
| `production_output` | positive | Finished goods created by production. |
| `sales_issue` | negative | Finished goods shipped/fulfilled. |
| `adjustment_in` | positive | Manual stock correction increase. |
| `adjustment_out` | negative | Manual stock correction decrease. |
| `damage_out` | negative | Damaged stock removed. |
| `return_in` | positive | Returned goods accepted back into stock. |

### Reservation Rule

Reservation is not physical stock movement. Reservation only locks stock.

Do not show reservation as stock out. This is a common reporting mistake.

## 4. Sales Order Rules

### Status Flow

```txt
draft
→ stock_check
→ reserved
→ fulfilled
```

Or, when stock is short:

```txt
draft
→ stock_check
→ needs_production
→ reserved
→ fulfilled
```

### Sales Order Creation

1. Sales creates order header and lines.
2. Order starts as `draft`.
3. User triggers stock check/reservation.
4. System checks finished goods availability.

### Stock Enough

If stock is enough:

1. System reserves stock.
2. Order item status becomes `reserved`.
3. Order status becomes `reserved`.

### Stock Short

If stock is short:

1. System reserves whatever finished goods are available.
2. System creates production batch for shortage quantity.
3. Order item status becomes `short_production`.
4. Order status becomes `needs_production`.

### Fulfillment

Sales order can be fulfilled only if:

1. all active lines are fully reserved,
2. order is not cancelled,
3. finished goods stock still has the reserved quantity.

When fulfilled:

1. reserved finished stock decreases,
2. on-hand finished stock decreases,
3. stock movement `sales_issue` is created,
4. sales order becomes `fulfilled`.

## 5. Production Batch Rules

### Status Flow

```txt
planned
→ materials_reserved
→ tasks_assigned
→ in_progress
→ proof_review
→ approved
→ confirmed
```

### Batch Creation

A batch can be created:

1. manually by supervisor/admin, or
2. automatically from sales order shortage.

When created from shortage, batch has:

- `sales_order_id`,
- `sales_order_item_id`,
- `qty_planned = shortage_qty`.

### Material Planning

Material lines are copied from BOM:

```txt
planned_qty = qty_per_unit × qty_planned × (1 + scrap_percent / 100)
```

### Material Reservation

Before production confirmation, raw materials must be reserved.

If raw material is insufficient, production should not proceed unless supervisor adjusts stock or changes batch plan.

### Production Confirmation

Production can be confirmed only if:

1. raw materials are reserved,
2. related tasks are approved/done/cancelled,
3. batch is not cancelled,
4. actual output is greater than zero.

When confirmed:

1. raw material reserved stock is released,
2. raw material on-hand stock is deducted,
3. finished goods on-hand stock is increased,
4. batch becomes `confirmed`,
5. linked sales order is re-reserved automatically.

## 6. Task Delegation Rules

### Task Status Flow

```txt
open
→ assigned
→ in_progress
→ submitted
→ approved
→ done
```

Rejected/revision path:

```txt
submitted
→ revision_requested
→ in_progress
→ submitted
→ approved
```

### Who Does What

| Role | Can Do |
|---|---|
| supervisor/admin | create task, assign task, review proof, approve/reject. |
| staff | see assigned task, update progress, submit proof. |
| owner/viewer | read task dashboard/report. |

### Proof Required

If a production batch has tasks, production confirmation should wait until tasks are approved/done/cancelled.

This stops staff from marking production complete without supervisor-visible evidence.

## 7. Proof of Work Rules

1. Proof must belong to a task.
2. Proof should contain uploaded file URL/path and optional notes.
3. Staff can submit proof only for assigned tasks.
4. Supervisor/admin reviews proof.
5. Rejected proof pushes task back to `revision_requested`.
6. Approved proof pushes task to `approved`.

## 8. Dashboard Rules

Dashboard should show:

1. open sales orders,
2. orders needing production,
3. open production batches,
4. open tasks,
5. overdue tasks,
6. low stock items,
7. sales amount last 30 days,
8. production progress,
9. stock movement history.

## 9. Scope Guardrails

Do not add these unless explicitly sold as new scope:

- payment gateway,
- marketplace checkout,
- customer portal,
- accounting journal/general ledger,
- payroll,
- route optimization,
- native mobile app,
- supplier procurement approval,
- barcode hardware integration,
- advanced forecasting.
