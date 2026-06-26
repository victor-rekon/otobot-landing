# Implementation Checklist

## Phase 1 — Supabase Setup

- [ ] Create Supabase project.
- [ ] Run `001_schema.sql`.
- [ ] Run `002_functions_and_triggers.sql`.
- [ ] Run `003_rls_policies.sql`.
- [ ] Run `004_report_views.sql`.
- [ ] Run optional `seed.sql`.
- [ ] Create private Storage bucket: `proof-of-work`.
- [ ] Add first owner/admin user in Supabase Auth.
- [ ] Insert matching row into `user_profiles`.

## Phase 2 — Frontend MVP Pages

- [ ] Login page.
- [ ] Dashboard page.
- [ ] Product Catalog page.
- [ ] Master Barang page.
- [ ] Raw Material Stock page.
- [ ] Finished Goods Stock page.
- [ ] Sales Order list/detail/form.
- [ ] Production Batch list/detail.
- [ ] Task Board.
- [ ] Proof upload/review page.
- [ ] Reports page.
- [ ] Users & Roles page.
- [ ] Settings page.
- [ ] Activity Log page.

## Phase 3 — Critical QA Flow

Test this exact flow:

1. Create product and BOM.
2. Add opening raw material stock.
3. Add opening finished goods stock.
4. Create sales order with quantity greater than finished goods stock.
5. Run `fn_reserve_sales_order`.
6. Confirm order becomes `needs_production`.
7. Confirm production batch auto-created.
8. Reserve production raw materials.
9. Assign production task to staff.
10. Staff uploads proof.
11. Supervisor approves proof.
12. Confirm production batch.
13. Confirm raw material stock deducted.
14. Confirm finished goods stock increased.
15. Confirm finished goods reserved for sales order.
16. Fulfill sales order.
17. Confirm finished goods stock deducted.
18. Check dashboard and reports updated.

## Phase 4 — Scope Control

Do not add these during MVP unless explicitly quoted:

- accounting journal,
- payment gateway,
- public checkout,
- payroll,
- procurement approval,
- supplier portal,
- delivery routing,
- native Android/iOS app,
- barcode scanner integration,
- AI forecasting.

## Phase 5 — Client Demo Script

Demo order:

1. Dashboard: show open orders, production, tasks, low stock.
2. Product Catalog: show Youngpro products and BOM.
3. Sales Order: create order that exceeds stock.
4. Stock Check: show shortage.
5. Auto Production Batch: show generated batch.
6. Production Batch: reserve raw materials.
7. Task Delegation: assign task and upload proof.
8. Supervisor Review: approve proof.
9. Confirm Production: show raw deducted and finished goods increased.
10. Fulfill Order: show finished goods deducted.
11. Reports: show stock card and fulfillment report.
