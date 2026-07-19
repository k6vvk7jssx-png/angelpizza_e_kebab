-- Migration: Fix INSERT policy to allow anonymous guest orders
-- The anon key client needs to be able to place orders without authentication

-- Ensure RLS is enabled
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Drop and recreate the INSERT policy to be fully permissive for anon users
DROP POLICY IF EXISTS "Allow public insert access to orders" ON public.orders;

CREATE POLICY "Allow public insert access to orders"
ON public.orders FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- Also ensure the menu_items table allows public read access
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read access to menu_items" ON public.menu_items;

CREATE POLICY "Allow public read access to menu_items"
ON public.menu_items FOR SELECT
TO anon, authenticated
USING (true);
