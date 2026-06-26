# Status Transitions

## Sales Order

| From | To | Trigger | Rule |
|---|---|---|---|
| `draft` | `stock_check` | Run reservation/check | Order must have at least one item. |
| `stock_check` | `reserved` | Finished stock enough | All lines fully reserved. |
| `stock_check` | `needs_production` | Finished stock short | One or more lines has shortage. |
| `needs_production` | `reserved` | Production confirmed and output reserved | All lines fully reserved. |
| `reserved` | `fulfilled` | Ship/fulfill order | All lines reserved. |
| any non-final | `cancelled` | Manual cancel | Release active reservations first. |

## Sales Order Item

| From | To | Meaning |
|---|---|---|
| `pending` | `reserved` | Stock fully reserved. |
| `pending` | `short_production` | Some/all quantity requires production. |
| `short_production` | `reserved` | Production output reserved. |
| `reserved` | `fulfilled` | Finished goods deducted. |
| any non-final | `cancelled` | Item cancelled. |

## Production Batch

| From | To | Trigger | Rule |
|---|---|---|---|
| `planned` | `materials_reserved` | Reserve raw materials | All required raw materials available. |
| `materials_reserved` | `tasks_assigned` | Supervisor creates tasks | At least one task exists. |
| `tasks_assigned` | `in_progress` | Staff starts task | Task status moves to in progress. |
| `in_progress` | `proof_review` | Staff submits proof | Proof exists. |
| `proof_review` | `approved` | Supervisor approves all required proof | No active task waiting approval. |
| `approved` | `confirmed` | Confirm production | Raw deducted, finished goods added. |
| any non-final | `cancelled` | Manual cancel | Release raw material reservations first. |

## Task

| From | To | Actor | Meaning |
|---|---|---|---|
| `open` | `assigned` | Supervisor | Staff selected. |
| `assigned` | `in_progress` | Staff | Work started. |
| `in_progress` | `submitted` | Staff | Proof submitted. |
| `submitted` | `approved` | Supervisor | Proof accepted. |
| `submitted` | `revision_requested` | Supervisor | Proof rejected / needs fix. |
| `revision_requested` | `in_progress` | Staff | Staff reworks. |
| `approved` | `done` | Supervisor/Admin | Task closed. |
| any non-final | `cancelled` | Supervisor/Admin | Task no longer needed. |

## Proof of Work

| From | To | Actor | Meaning |
|---|---|---|---|
| `submitted` | `approved` | Supervisor/Admin | Accepted. |
| `submitted` | `rejected` | Supervisor/Admin | Rejected, task needs revision. |
