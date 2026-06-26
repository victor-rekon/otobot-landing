# Backend Architecture — Youngpro Cleaning Tools System

## 1. System Positioning

This system is an internal operational system for Youngpro Cleaning Tools. Its job is to control product data, sales orders, stock, production, task execution, proof approval, and reports.

It is not public ecommerce. It is not full ERP. It does not handle payment gateway, tax accounting, payroll, procurement approval, or delivery route optimization.

## 2. Main Data Domains

### A. Users & Roles

Table: `user_profiles`

Roles:

| Role | Permission Direction |
|---|---|
| owner | Full visibility and control. |
| admin | Full operational control except ownership-level business decisions. |
| sales | Create sales orders, check stock, monitor order status. |
| supervisor | Manage production, tasks, proof review, stock operations. |
| staff | Execute assigned tasks and submit proof. |
| viewer | Read-only dashboard/report access. |

### B. Master Barang

Tables:

- `units`
- `locations`
- `item_master`

`item_master` stores every stock-controlled item:

- raw material,
- finished good,
- packaging,
- consumable,
- other.

This prevents the common mistake of creating separate incompatible stock logic for raw material and finished goods.

### C. Product Catalog

Tables:

- `product_catalog`
- `product_bom`

`product_catalog` only stores sellable products. Each product links to one finished-good item in `item_master`.

`product_bom` defines raw material usage per one finished product.

Example:

```txt
Youngpro Mop Handle Set
- Plastic Granule PP: 0.20 KG/unit + scrap
- Aluminum Pole: 1 PCS/unit
- Packaging Box: 1 BOX/unit
- Sticker Label: 1 PCS/unit
```

### D. Inventory

Tables:

- `stock_balances`
- `stock_movements`
- `stock_reservations`

Inventory is not just a number. It has three separate concepts:

| Concept | Meaning |
|---|---|
| `on_hand` | Physical stock currently in location. |
| `reserved` | Stock locked for sales/production. |
| `available` | Stock still usable for new orders/batches. Generated from `on_hand - reserved`. |

Physical stock changes are recorded in `stock_movements`.

Reservation changes are recorded in `stock_reservations` and reflected in `stock_balances.reserved`.

### E. Sales Order

Tables:

- `sales_orders`
- `sales_order_items`

Sales order flow:

```txt
draft
→ stock_check
→ reserved / needs_production
→ ready_to_ship
→ fulfilled
```

If finished goods stock is enough, the system reserves it.

If stock is short, the system creates a production batch for shortage quantity.

### F. Production Batch

Tables:

- `production_batches`
- `production_batch_materials`

Production batch flow:

```txt
planned
→ materials_reserved
→ tasks_assigned
→ in_progress
→ proof_review
→ approved
→ confirmed
```

Raw materials are reserved before production. Raw material stock is deducted only when production is confirmed.

Finished goods stock is increased only when production is confirmed.

### G. Task Delegation

Table: `tasks`

Tasks can be tied to production batches. Supervisor assigns task to staff. Staff updates progress and submits proof.

Task flow:

```txt
open
→ assigned
→ in_progress
→ submitted
→ approved / revision_requested
→ done
```

### H. Proof of Work

Table: `proof_of_work`

Proof is tied to a task, not directly to a batch. This is cleaner because one batch can have multiple tasks and multiple proofs.

Proof flow:

```txt
submitted
→ approved / rejected
```

Production cannot be confirmed while related tasks are still unapproved.

### I. Reports

Views:

- `v_dashboard_summary`
- `v_stock_position`
- `v_low_stock_items`
- `v_sales_order_fulfillment`
- `v_open_order_shortage`
- `v_production_batch_progress`
- `v_task_board`
- `v_stock_card`

## 3. Core Transaction Logic

### Sales Order Reservation

Function: `fn_reserve_sales_order(order_id)`

What it does:

1. Checks finished goods stock.
2. Reserves available stock.
3. Updates item reserved quantity.
4. If shortage exists, creates production batch from BOM.
5. Sets order status to `reserved` or `needs_production`.

### Production Material Reservation

Function: `fn_reserve_production_materials(batch_id)`

What it does:

1. Checks raw material availability.
2. Locks raw materials for the batch.
3. Updates batch material status.
4. Prevents other batches from consuming the same raw stock.

### Production Confirmation

Function: `fn_confirm_production_batch(batch_id, actual_output)`

What it does:

1. Ensures tasks are approved.
2. Ensures raw materials are reserved.
3. Deducts raw materials.
4. Adds finished goods.
5. Confirms production batch.
6. If batch came from sales order shortage, reserves the new finished stock for that order.

### Sales Fulfillment

Function: `fn_fulfill_sales_order(order_id)`

What it does:

1. Checks all order lines are fully reserved.
2. Deducts finished goods stock.
3. Consumes reservations.
4. Marks order fulfilled.

## 4. Non-Negotiable Integrity Rules

1. No negative stock.
2. Reserved stock cannot exceed on-hand stock.
3. Sales order cannot be fulfilled unless all lines are fully reserved.
4. Production cannot be confirmed unless all production task proofs are approved or tasks are closed.
5. Raw material deduction happens at production confirmation, not at batch creation.
6. Finished goods deduction happens at sales fulfillment, not at order creation.
7. Every physical stock change must create a stock movement row.
8. Every important operational change should appear in `activity_logs`.
