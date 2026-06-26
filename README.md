# Youngpro Cleaning Tools Backend Pack

Backend logic and system architecture for an internal web app covering:

- Product Catalog
- Sales Order / Order Draft
- Finished Goods Stock
- Raw Material Stock
- Production Batch
- Task Delegation
- Proof of Work
- Dashboard
- Reports
- Users & Roles
- Settings
- Activity Logs

This pack is intentionally **not** a marketplace, full ERP, accounting system, payroll system, payment gateway, mobile app, or delivery route system.

## Folder Structure

```txt
youngpro_backend_pack/
├── README.md
├── docs/
│   ├── backend_architecture.md
│   ├── business_rules.md
│   ├── api_direction.md
│   ├── status_transitions.md
│   └── implementation_checklist.md
├── supabase/
│   ├── migrations/
│   │   ├── 001_schema.sql
│   │   ├── 002_functions_and_triggers.sql
│   │   ├── 003_rls_policies.sql
│   │   └── 004_report_views.sql
│   └── seed.sql
└── src/
    └── backend/
        ├── api-services.ts
        ├── constants.ts
        └── types.ts
```

## Install Order

Run these files in this order inside Supabase SQL Editor or Supabase CLI migration flow:

1. `supabase/migrations/001_schema.sql`
2. `supabase/migrations/002_functions_and_triggers.sql`
3. `supabase/migrations/003_rls_policies.sql`
4. `supabase/migrations/004_report_views.sql`
5. Optional dummy data: `supabase/seed.sql`

## Core Backend Principle

Inventory is split into:

- `on_hand`: physical stock currently available in warehouse.
- `reserved`: stock already locked for a sales order or production batch.
- `available`: generated value = `on_hand - reserved`.

Do not deduct finished goods stock when an order is created. Deduct only when order is fulfilled/shipped.

Do not deduct raw material stock when a batch is drafted. Reserve raw material first, deduct only when production is confirmed.

## Main RPC Functions

| Function | Purpose |
|---|---|
| `fn_check_sales_order_stock(order_id)` | Returns per-line stock availability and shortage. |
| `fn_reserve_sales_order(order_id)` | Reserves finished goods stock and auto-creates production batches for shortages. |
| `fn_release_sales_order_reservation(order_id)` | Releases active stock reservations if order is cancelled or changed. |
| `fn_fulfill_sales_order(order_id)` | Deducts reserved finished goods and marks order fulfilled. |
| `fn_create_production_batch(product_id, qty, sales_order_id, sales_order_item_id)` | Creates production batch and BOM material plan. |
| `fn_reserve_production_materials(batch_id)` | Reserves raw materials for production. |
| `fn_submit_proof_of_work(task_id, file_url, ...)` | Staff submits proof for assigned task. |
| `fn_review_proof_of_work(proof_id, approved, note)` | Supervisor approves/rejects proof. |
| `fn_confirm_production_batch(batch_id, actual_output)` | Deducts raw materials, adds finished goods, then reserves output for linked order. |

## Required Supabase Storage Bucket

Create a private bucket:

```txt
proof-of-work
```

Suggested path convention:

```txt
proof-of-work/{task_id}/{timestamp}-{filename}
```

Storage policies should allow:

- assigned staff to upload proof for their own task,
- supervisor/admin to view/review all proof,
- no public anonymous access.

## Frontend Direction

Use `src/backend/api-services.ts` as the first frontend API layer. Claude Code or another frontend builder can wire the screens directly to these service functions.
