-- =============================================================================
-- 014_seed.sql
-- Demo data for local development.
--
-- Creates two businesses, four users (all with the password demo1234),
-- catalogs, quotations, orders, payments, costs and expenses.
--
-- The auth.users inserts below emulate what the sign up screen does. If the
-- project blocks them, create the users from the app instead and re-run the
-- rest of this file.
--
-- Demo logins
--   owner@demo.test      / demo1234   owner of "Sunrise Custom Cakes"
--   staff@demo.test      / demo1234   staff of "Sunrise Custom Cakes"
--   accountant@demo.test / demo1234   accountant of "Sunrise Custom Cakes"
--   owner2@demo.test     / demo1234   owner of "Nordic Woodworks"
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Auth users
-- -----------------------------------------------------------------------------
do $$
declare
  v_user record;
begin
  for v_user in
    select *
    from (values
      ('11111111-1111-4111-8111-111111111111'::uuid, 'owner@demo.test', 'Demo Owner'),
      ('22222222-2222-4222-8222-222222222222'::uuid, 'staff@demo.test', 'Demo Staff'),
      ('33333333-3333-4333-8333-333333333333'::uuid, 'accountant@demo.test', 'Demo Accountant'),
      ('44444444-4444-4444-8444-444444444444'::uuid, 'owner2@demo.test', 'Other Owner')
    ) as t(id, email, name)
  loop
    if not exists (select 1 from auth.users where id = v_user.id) then
      insert into auth.users (
        instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at
      ) values (
        '00000000-0000-0000-0000-000000000000',
        v_user.id,
        'authenticated',
        'authenticated',
        v_user.email,
        crypt('demo1234', gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('display_name', v_user.name),
        now(),
        now()
      );

      insert into auth.identities (
        id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at
      ) values (
        v_user.id,
        v_user.id,
        v_user.email,
        jsonb_build_object('sub', v_user.id::text, 'email', v_user.email, 'email_verified', true),
        'email',
        now(),
        now(),
        now()
      );
    end if;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Businesses and members
-- -----------------------------------------------------------------------------
insert into public.businesses (id, name, currency_code, overhead_rate)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'Sunrise Custom Cakes', 'PHP', 5),
  ('aaaaaaaa-0000-4000-8000-000000000002', 'Nordic Woodworks', 'PHP', 0)
on conflict (id) do nothing;

insert into public.business_members (id, business_id, user_id, email, role, status)
values
  ('bbbbbbbb-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'owner@demo.test', 'owner', 'active'),
  ('bbbbbbbb-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'staff@demo.test', 'staff', 'active'),
  ('bbbbbbbb-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333', 'accountant@demo.test', 'accountant', 'active'),
  ('bbbbbbbb-0000-4000-8000-000000000004', 'aaaaaaaa-0000-4000-8000-000000000002', '44444444-4444-4444-8444-444444444444', 'owner2@demo.test', 'owner', 'active')
on conflict (id) do nothing;

insert into public.business_counters (business_id, kind, next_value)
values
  ('aaaaaaaa-0000-4000-8000-000000000001', 'order', 3),
  ('aaaaaaaa-0000-4000-8000-000000000001', 'quotation', 2),
  ('aaaaaaaa-0000-4000-8000-000000000002', 'order', 0)
on conflict (business_id, kind) do nothing;

-- -----------------------------------------------------------------------------
-- Catalogs
-- -----------------------------------------------------------------------------
insert into public.customers (id, business_id, name, phone, email, address, assigned_to)
values
  ('c0000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', 'Maria Santos', '0917 555 0101', 'maria@example.com', '12 Katipunan Ave, Quezon City', '22222222-2222-4222-8222-222222222222'),
  ('c0000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', 'Juan Dela Cruz', '0918 555 0102', 'juan@example.com', '45 Session Rd, Pasig City', null),
  ('c0000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', 'Ana Reyes', '0919 555 0103', 'ana@example.com', '8 Legazpi Village, Makati', '22222222-2222-4222-8222-222222222222'),
  ('d0000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000002', 'Erik Johansson', '0920 555 0104', 'erik@example.com', '3 Nordic St, San Juan', null)
on conflict (id) do nothing;

insert into public.products (id, business_id, name, description, base_price, unit)
values
  ('90000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', 'Custom Cake (per size)', 'Three layer celebration cake, buttercream finish', 4500, 'cake'),
  ('90000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', 'Cupcakes (dozen)', 'Assorted flavours, fondant topper included', 1800, 'dozen'),
  ('90000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', 'Dessert Table (50 pax)', 'Five dessert varieties with styling', 22000, 'event'),
  ('90000000-0000-4000-8000-000000000004', 'aaaaaaaa-0000-4000-8000-000000000001', 'Custom Cake (per size)', 'Wedding cake, three tiers', 8500, 'cake'),
  ('90000000-0000-4000-8000-000000000005', 'aaaaaaaa-0000-4000-8000-000000000002', 'Oak Dining Table', 'Solid oak, 200 x 90 cm', 32000, 'table')
on conflict (id) do nothing;

insert into public.materials (id, business_id, name, unit, default_unit_cost)
values
  ('10000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', 'All-purpose flour', 'kg', 65),
  ('10000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', 'Butter', 'kg', 480),
  ('10000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', 'Fondant', 'kg', 520),
  ('10000000-0000-4000-8000-000000000004', 'aaaaaaaa-0000-4000-8000-000000000001', 'Candles and toppers', 'set', 180)
on conflict (id) do nothing;

insert into public.expense_categories (id, business_id, name, type)
values
  ('e0000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', 'Rent', 'operating'),
  ('e0000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', 'Electricity', 'utilities'),
  ('e0000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', 'Advertising', 'marketing'),
  ('e0000000-0000-4000-8000-000000000004', 'aaaaaaaa-0000-4000-8000-000000000001', 'Staff wages', 'payroll')
on conflict (id) do nothing;

insert into public.payment_methods (id, business_id, name)
values
  ('f0000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', 'Cash'),
  ('f0000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', 'Bank transfer'),
  ('f0000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', 'GCash'),
  ('f0000000-0000-4000-8000-000000000004', 'aaaaaaaa-0000-4000-8000-000000000001', 'Maya')
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Quotations
-- -----------------------------------------------------------------------------
insert into public.quotations (
  id, business_id, customer_id, quotation_no, status, valid_until, notes,
  subtotal, discount_type, discount_value, discount_amount,
  estimated_cost, assigned_to, created_by
)
values
  (
    '20000000-0000-4000-8000-000000000001',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'QUO-' || to_char(now(), 'YYYY') || '-0001',
    'draft',
    current_date + 14,
    'Two layer cake, floral design',
    8000, 'none', 0, 0, 4000,
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222'
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000003',
    'QUO-' || to_char(now(), 'YYYY') || '-0002',
    'accepted',
    current_date + 7,
    'Dessert table for a 50 pax reception',
    12500, 'percent', 5, 625, 6000,
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222'
  )
on conflict (id) do nothing;

insert into public.quotation_items (
  id, quotation_id, product_id, description, quantity, unit_price, estimated_cost, position
)
values
  ('50000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001', 'Two layer celebration cake', 1, 8000, 4000, 0),
  ('50000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000003', 'Dessert table (50 pax)', 1, 12500, 6000, 0)
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Orders
-- -----------------------------------------------------------------------------
insert into public.orders (
  id, business_id, customer_id, order_no, status, subtotal, discount_type,
  discount_value, discount_amount, estimated_cost, actual_cost,
  notes, due_date, confirmed_at, delivered_at, assigned_to, created_by
)
values
  (
    '30000000-0000-4000-8000-000000000001',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'ORD-' || to_char(now(), 'YYYY') || '-0001',
    'confirmed', 8000, 'none', 0, 0, 4000, 0,
    'Deposit received, awaiting production',
    current_date + 7, now() - interval '5 days', null,
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222'
  ),
  (
    '30000000-0000-4000-8000-000000000002',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000002',
    'ORD-' || to_char(now(), 'YYYY') || '-0002',
    'in_progress', 5000, 'none', 0, 0, 2600, 2700,
    'Baking the layers tomorrow',
    current_date + 3, now() - interval '4 days', null,
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222'
  ),
  (
    '30000000-0000-4000-8000-000000000003',
    'aaaaaaaa-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000003',
    'ORD-' || to_char(now(), 'YYYY') || '-0003',
    'delivered', 12500, 'percent', 5, 625, 6000, 5800,
    'Delivered and fully paid',
    current_date - 2, now() - interval '9 days', now() - interval '2 days',
    '22222222-2222-4222-8222-222222222222',
    '22222222-2222-4222-8222-222222222222'
  )
on conflict (id) do nothing;

insert into public.order_items (
  id, order_id, product_id, description, quantity, unit_price, position
)
values
  ('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000001', 'Two layer celebration cake', 1, 8000, 0),
  ('40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002', '90000000-0000-4000-8000-000000000002', 'Cupcakes (dozen)', 2, 2500, 0),
  ('40000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000003', '90000000-0000-4000-8000-000000000003', 'Dessert table (50 pax)', 1, 12500, 0)
on conflict (id) do nothing;

insert into public.order_status_history (id, order_id, from_status, to_status, note, changed_by, changed_at)
values
  ('80000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', null, 'draft', 'Order created', '22222222-2222-4222-8222-222222222222', now() - interval '5 days'),
  ('80000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001', 'draft', 'confirmed', 'Deposit received', '22222222-2222-4222-8222-222222222222', now() - interval '5 days'),
  ('80000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000002', 'draft', 'confirmed', 'Order created', '22222222-2222-4222-8222-222222222222', now() - interval '4 days'),
  ('80000000-0000-4000-8000-000000000004', '30000000-0000-4000-8000-000000000002', 'confirmed', 'in_progress', 'Production started', '22222222-2222-4222-8222-222222222222', now() - interval '2 days'),
  ('80000000-0000-4000-8000-000000000005', '30000000-0000-4000-8000-000000000003', 'draft', 'confirmed', 'Converted from quotation', '22222222-2222-4222-8222-222222222222', now() - interval '9 days'),
  ('80000000-0000-4000-8000-000000000006', '30000000-0000-4000-8000-000000000003', 'confirmed', 'in_progress', 'Production started', '22222222-2222-4222-8222-222222222222', now() - interval '6 days'),
  ('80000000-0000-4000-8000-000000000007', '30000000-0000-4000-8000-000000000003', 'in_progress', 'completed', 'Finished and packed', '22222222-2222-4222-8222-222222222222', now() - interval '3 days'),
  ('80000000-0000-4000-8000-000000000008', '30000000-0000-4000-8000-000000000003', 'completed', 'delivered', 'Delivered to the venue', '22222222-2222-4222-8222-222222222222', now() - interval '2 days')
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Payments, refunds, costs and expenses
-- -----------------------------------------------------------------------------
insert into public.payments (
  id, business_id, order_id, customer_id, kind, amount, method, reference,
  paid_at, status, idempotency_key, created_by
)
values
  ('b0000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', 'deposit', 2500, 'GCash', 'GC-77812', now() - interval '5 days', 'successful', 'seed-payment-0001', '33333333-3333-4333-8333-333333333333'),
  ('b0000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000002', 'installment', 1500, 'Cash', null, now() - interval '2 days', 'successful', 'seed-payment-0002', '33333333-3333-4333-8333-333333333333'),
  ('b0000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000003', 'final', 13300, 'Bank transfer', 'TRF-55120', now() - interval '2 days', 'successful', 'seed-payment-0003', '33333333-3333-4333-8333-333333333333')
on conflict (id) do nothing;

insert into public.refunds (
  id, business_id, order_id, payment_id, amount, method, reason, refunded_at, created_by
)
values
  ('d0000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000002', 200, 'Cash', 'One box damaged in transit', now() - interval '1 day', '33333333-3333-4333-8333-333333333333')
on conflict (id) do nothing;

insert into public.order_costs (
  id, business_id, order_id, cost_type, material_id, description, quantity, unit_cost, cost_date, created_by
)
values
  ('60000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'material', '10000000-0000-4000-8000-000000000001', 'All-purpose flour', 2, 800, current_date - 2, '22222222-2222-4222-8222-222222222222'),
  ('60000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'labor', null, 'Baker time', 3, 300, current_date - 2, '22222222-2222-4222-8222-222222222222'),
  ('60000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'overhead', null, 'Oven and electricity share', 1, 200, current_date - 2, '22222222-2222-4222-8222-222222222222'),
  ('60000000-0000-4000-8000-000000000004', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'material', '10000000-0000-4000-8000-000000000003', 'Fondant', 4, 1050, current_date - 6, '22222222-2222-4222-8222-222222222222'),
  ('60000000-0000-4000-8000-000000000005', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'labor', null, 'Decorating time', 4, 250, current_date - 4, '22222222-2222-4222-8222-222222222222'),
  ('60000000-0000-4000-8000-000000000006', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'overhead', null, 'Utilities share', 1, 600, current_date - 3, '22222222-2222-4222-8222-222222222222')
on conflict (id) do nothing;

insert into public.expenses (
  id, business_id, order_id, category_id, amount, description, expense_date, method, created_by
)
values
  ('70000000-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001', null, 'e0000000-0000-4000-8000-000000000001', 5000, 'Monthly stall rent', current_date - 5, 'Bank transfer', '33333333-3333-4333-8333-333333333333'),
  ('70000000-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000001', null, 'e0000000-0000-4000-8000-000000000002', 1200, 'Electricity bill', current_date - 10, 'Cash', '33333333-3333-4333-8333-333333333333'),
  ('70000000-0000-4000-8000-000000000003', 'aaaaaaaa-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000000003', 800, 'Delivery van fuel', current_date - 2, 'Cash', '33333333-3333-4333-8333-333333333333')
on conflict (id) do nothing;
