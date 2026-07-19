-- Migration: Allow anonymous users to select recent orders to enable guest checkout and realtime tracking
-- Date: 2026-07-19

-- Recreate SELECT policy to allow admins, registered owners, and recent anonymous guest orders (last 2 hours)
DROP POLICY IF EXISTS "Allow select access to orders for owners and admins" ON public.orders;

CREATE POLICY "Allow select access to orders for owners and admins"
ON public.orders FOR SELECT
TO anon, authenticated
USING (
  -- 1. Admin users (by email or metadata role)
  (auth.jwt() ->> 'email' = 'admin@angels.it') OR 
  (auth.jwt() ->> 'email' = 'eraldolamberto@gmail.com') OR 
  ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin') OR
  
  -- 2. Registered customers (by matching user ID)
  (auth.uid() = customer_id) OR
  
  -- 3. Anonymous guests can view recent orders (last 2 hours) to track their current order status
  (created_at > now() - interval '2 hours')
);
