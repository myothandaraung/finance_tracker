# Supabase setup

The app talks to a **dedicated Supabase project** (staff facing, multi tenant).
The public, customer facing cake-ordering project is a different project and
must not be reused for this app.

## 1. Create the project

1. Supabase dashboard -> New project.
2. Authentication -> Providers -> Email: keep it enabled, **disable "Confirm
   email"** for development (enable it again for production).
3. Project Settings -> API: copy the project URL and the **anon / publishable**
   key. The service role key never goes into the app.

## 2. Apply the migrations

Open the SQL Editor and run the files below **in this order**, one file per
run (the editor does not support `\i` includes):

| # | File | Purpose |
| --- | --- | --- |
| 1 | `migrations/001_core_tenancy.sql` | businesses, profiles, memberships, counters, audit trail, helper functions |
| 2 | `migrations/002_catalog_tables.sql` | customers, products, materials, expense categories, payment methods |
| 3 | `migrations/003_sales_tables.sql` | quotations, orders, items, status history |
| 4 | `migrations/004_money_tables.sql` | payments, refunds, production costs, expenses |
| 5 | `migrations/005_auth_triggers.sql` | profile + membership sync with Supabase Auth |
| 6 | `migrations/006_rls_policies.sql` | Row Level Security for every table |
| 7 | `migrations/007_rpc_tenancy.sql` | business, team, document number RPCs |
| 8 | `migrations/008_rpc_catalog.sql` | catalog write RPCs |
| 9 | `migrations/009_rpc_quotations_orders.sql` | quotation and order lifecycle RPCs |
| 10 | `migrations/010_rpc_finance.sql` | payments, refunds, costs, expenses |
| 11 | `migrations/011_views_reports.sql` | reporting RPCs |
| 12 | `migrations/012_audit_triggers.sql` | audit safety net |
| 13 | `migrations/013_storage.sql` | private `receipts` and `product-images` buckets |
| 14 | `migrations/014_seed.sql` | demo data (optional) |

All files are idempotent where it matters (`create table if not exists`,
`create or replace function`, `drop policy if exists` before `create policy`),
so re-running one after a failure is safe.

### Optional: Supabase CLI

```powershell
npm install -g supabase
supabase link --project-ref <your-project-ref>
supabase db push
```

## 3. Verify

Run `tests/verify_rls.sql` in the SQL Editor. It prints `PASS` / `FAIL` lines
for tenant isolation, role separation and balance reconciliation, and it never
modifies data.

## 4. Seed data

`migrations/014_seed.sql` creates two businesses and four demo users. All demo
passwords are `demo1234`:

| Email | Role | Business |
| --- | --- | --- |
| `owner@demo.test` | Owner | Sunrise Custom Cakes |
| `staff@demo.test` | Staff | Sunrise Custom Cakes |
| `accountant@demo.test` | Accountant | Sunrise Custom Cakes |
| `owner2@demo.test` | Owner | Nordic Woodworks |

The second business exists to prove that records never leak between
businesses: sign in as `owner2@demo.test` and you only see Nordic Woodworks.

## 5. Conventions

* Money is stored as `numeric(15,2)` and mirrored by a generated `*_cents`
  column. The API only ever exchanges **integer centavos**, so no float ever
  touches a financial figure.
* Tax rate and discounts are percentages (`12` means 12%).
* Revenue is recognised on delivery, cash is reported on the payment date.
  Both views are available in the reports and each screen states its basis.
* Every write goes through a `SECURITY DEFINER` RPC. Row Level Security grants
  read access to members of the owning business and denies direct writes.

## 6. Production checklist

- [ ] Email confirmation turned on.
- [ ] Storage buckets created and still private.
- [ ] Redirect / site URL configured for the mobile deep links.
- [ ] Point-in-time backups enabled.
- [ ] The anon key in the app is the publishable key of the production project.
- [ ] The service role key is **not** in the repository, not in the app and
      not in `tool/env.local.json`.
