# MTO Finance

MTO Finance is a Flutter and Supabase application for small made-to-order
businesses. It manages customers, products, quotations, orders, payments,
expenses, production costs, and profitability in one multi-tenant workspace.

## Product and order costing

Each catalog product has two independently editable amounts:

- **Base price**: the suggested selling price for one unit.
- **Production cost / unit**: the current estimated cost to make one unit.

When a product is selected in a quotation or customer order, the app copies
both amounts into the document line. The user may override either amount for
that particular sale.

The saved order is a historical snapshot. Later changes to the catalog price
or production cost do not alter the revenue, cost, or profit of an existing
order.

```text
line revenue = quantity × unit selling price
line production cost = quantity × saved unit production cost
order profit = net sales after discount − production cost
```

If actual material, labour, or overhead costs are recorded against the order,
those actual costs replace the saved estimate in order details and
profitability reports.

## Main features

- Email authentication and multiple businesses
- Owner, staff, and accountant roles
- Customer, product, and material catalogues
- Quotations with PDF sharing and order conversion
- Customer orders and status history
- Payments, refunds, expenses, and receipt attachments
- Estimated and actual production costs
- Sales, profitability, and receivables reports
- Tenant isolation through Supabase Row Level Security

## Run locally

1. Create `tool/env.local.json` from `tool/env.local.example.json`.
2. Add the Supabase project URL and publishable/anon key.
3. Apply the migrations in `supabase/README.md` in numeric order.
4. Start the application:

```powershell
.\tool\run_dev.ps1
```

For direct Flutter commands, supply `SUPABASE_URL` and
`SUPABASE_ANON_KEY` with `--dart-define`.

## Verification

```powershell
flutter analyze
flutter test
```

Database setup, migration order, RLS verification, demo accounts, and the
production checklist are documented in `supabase/README.md`.
