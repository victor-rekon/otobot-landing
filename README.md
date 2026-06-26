# Youngpro Cleaning Tools Operations System

Internal web app foundation for Youngpro Cleaning Tools. This repository now contains both:

1. a clickable Next.js frontend demo, and
2. Supabase/PostgreSQL backend architecture, schema, RPC functions, RLS, reports, and seed data.

The system covers:

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

This system is intentionally **not** a marketplace, full ERP, accounting system, payroll system, payment gateway, native mobile app, or delivery route system.

## Frontend Demo

The frontend is a Next.js app with a polished mock-data demo for client presentation.

Run locally:

```bash
npm install
npm run dev
```

Build:

```bash
npm run build
```

Environment variables:

```bash
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
```

If Supabase variables are not configured yet, the frontend still renders using mock data.

## Folder Structure

```txt
app/
├── globals.css
├── layout.tsx
└── page.tsx
src/
├── backend/
│   ├── api-services.ts
│   ├── constants.ts
│   └── types.ts
└── lib/
    ├── mock-data.ts
    └── supabase.ts
docs/
├── backend_architecture.md
├── business_rules.md
├── api_direction.md
├── status_transitions.md
└── implementation_checklist.md
supabase/
├── migrations/
│   ├── 001_schema.sql
│   ├── 002_functions_and_triggers.sql
│   ├── 003_rls_policies.sql
│   └── 004_report_views.sql
└── seed.sql
```

## Supabase Install Order

Run these files in order inside Supabase SQL Editor or Supabase CLI migration flow:

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

## Demo Flow

Use this order when showing the client:

1. Dashboard: open orders, production, tasks, low stock.
2. Product Catalog: products and BOM.
3. Sales Order: order exceeds finished goods stock.
4. Stock Check: shortage appears.
5. Production Batch: batch generated from shortage.
6. Task Delegation: staff task and proof submission.
7. Supervisor Review: approve/reject proof.
8. Production Confirmation: raw material deducted, finished goods increased.
9. Fulfillment: reserved finished goods deducted.
10. Reports: stock movement and operational trace.
