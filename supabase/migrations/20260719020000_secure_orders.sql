-- Migration: Secure orders table and set up admin role
-- Date: 2026-07-19

-- 1. Add guest_token column to public.orders if it doesn't exist
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS guest_token UUID DEFAULT gen_random_uuid();

-- Create index on guest_token and guest_phone for policy check performance
CREATE INDEX IF NOT EXISTS idx_orders_guest_token ON public.orders(guest_token);
CREATE INDEX IF NOT EXISTS idx_orders_guest_phone ON public.orders(guest_phone);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON public.orders(customer_id);

-- 2. Clean up existing policies on the orders table
DROP POLICY IF EXISTS "Allow public insert access to orders" ON public.orders;
DROP POLICY IF EXISTS "Allow users to view their own orders" ON public.orders;
DROP POLICY IF EXISTS "Allow gestore (service_role) to update orders" ON public.orders;
DROP POLICY IF EXISTS "Allow select access to orders for owners and admins" ON public.orders;
DROP POLICY IF EXISTS "Allow update access to orders for owners and admins" ON public.orders;

-- 3. Create the INSERT policy
-- Anyone (guests and clients) can place orders.
CREATE POLICY "Allow public insert access to orders"
ON public.orders FOR INSERT
WITH CHECK (true);

-- 4. Create the SELECT policy
-- Restrict order visibility to:
--   - Admin users (identified by email 'admin@angels.it' or user_metadata role = 'admin')
--   - The customer (client) who created the order (auth.uid() = customer_id)
--   - The guest client (matching guest_phone via verified auth phone or request headers/cookies, or matching guest_token)
CREATE POLICY "Allow select access to orders for owners and admins"
ON public.orders FOR SELECT
USING (
  -- 1. Admin users (by email or metadata role)
  (auth.jwt() ->> 'email' = 'admin@angels.it') OR 
  ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin') OR
  
  -- 2. Registered customers (by matching user ID)
  (auth.uid() = customer_id) OR
  
  -- 3. Guests (by verified auth phone number)
  (guest_phone = (auth.jwt() ->> 'phone')) OR
  
  -- 4. Guests (by guest token in custom request headers)
  (guest_token::text = (COALESCE(NULLIF(current_setting('request.headers', true), ''), '{}')::json ->> 'x-guest-token')) OR
  
  -- 5. Guests (by guest phone in custom request headers)
  (guest_phone = (COALESCE(NULLIF(current_setting('request.headers', true), ''), '{}')::json ->> 'x-guest-phone')) OR
  
  -- 6. Guests (by guest token in cookies)
  (guest_token::text = (COALESCE(NULLIF(current_setting('request.cookies', true), ''), '{}')::json ->> 'guest_token')) OR
  
  -- 7. Guests (by guest phone in cookies)
  (guest_phone = (COALESCE(NULLIF(current_setting('request.cookies', true), ''), '{}')::json ->> 'guest_phone'))
);

-- 5. Create the UPDATE policy
-- Restrict order status/info updates to:
--   - Admin users (identified by email 'admin@angels.it' or user_metadata role = 'admin')
--   - The customer/guest who created the order (e.g., to cancel it)
CREATE POLICY "Allow update access to orders for owners and admins"
ON public.orders FOR UPDATE
USING (
  -- 1. Admin users (by email or metadata role)
  (auth.jwt() ->> 'email' = 'admin@angels.it') OR 
  ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin') OR
  
  -- 2. Registered customers
  (auth.uid() = customer_id) OR
  
  -- 3. Guests (by verified auth phone number)
  (guest_phone = (auth.jwt() ->> 'phone')) OR
  
  -- 4. Guests (by guest token in custom request headers)
  (guest_token::text = (COALESCE(NULLIF(current_setting('request.headers', true), ''), '{}')::json ->> 'x-guest-token')) OR
  
  -- 5. Guests (by guest phone in custom request headers)
  (guest_phone = (COALESCE(NULLIF(current_setting('request.headers', true), ''), '{}')::json ->> 'x-guest-phone')) OR
  
  -- 6. Guests (by guest token in cookies)
  (guest_token::text = (COALESCE(NULLIF(current_setting('request.cookies', true), ''), '{}')::json ->> 'guest_token')) OR
  
  -- 7. Guests (by guest phone in cookies)
  (guest_phone = (COALESCE(NULLIF(current_setting('request.cookies', true), ''), '{}')::json ->> 'guest_phone'))
)
WITH CHECK (
  -- 1. Admin users can set any status
  (auth.jwt() ->> 'email' = 'admin@angels.it') OR 
  ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin') OR
  
  -- 2. Clients/Guests can only UPDATE their order if they are not changing the status to admin-only roles, or they can only update notes/cancel
  -- For safety, we enforce that client/guest updates can only transition to 'cancelled' status
  (
    (
      (auth.uid() = customer_id) OR
      (guest_phone = (auth.jwt() ->> 'phone')) OR
      (guest_token::text = (COALESCE(NULLIF(current_setting('request.headers', true), ''), '{}')::json ->> 'x-guest-token')) OR
      (guest_token::text = (COALESCE(NULLIF(current_setting('request.cookies', true), ''), '{}')::json ->> 'guest_token'))
    ) AND (
      -- They can only change status to 'cancelled' (cannot accept or complete their own orders)
      status = 'cancelled'
    )
  )
);

-- 6. Set custom metadata role 'admin' for the restaurant owner's email
-- We run an update on auth.users for this specific account.
-- Since auth.users is in a separate schema managed by Supabase, the public schema trigger/functions
-- can update user metadata. Here is a SQL query that will execute if/when the user exists.
UPDATE auth.users
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb
WHERE email = 'admin@angels.it';
