-- Migration: Add user email eraldolamberto@gmail.com as authorized admin
-- Date: 2026-07-19

-- Update existing policies to explicitly support eraldolamberto@gmail.com as admin
DROP POLICY IF EXISTS "Allow select access to orders for owners and admins" ON public.orders;
DROP POLICY IF EXISTS "Allow update access to orders for owners and admins" ON public.orders;

CREATE POLICY "Allow select access to orders for owners and admins"
ON public.orders FOR SELECT
USING (
  -- 1. Admin users (by email or metadata role)
  (auth.jwt() ->> 'email' = 'admin@angels.it') OR 
  (auth.jwt() ->> 'email' = 'eraldolamberto@gmail.com') OR 
  ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin') OR
  
  -- 2. Registered customers (by matching user ID)
  (auth.uid() = customer_id) OR
  
  -- 3. Guests (by verified auth phone number)
  (guest_phone = (auth.jwt() ->> 'phone')) OR
  
  -- 4. Guests (by guest token in custom request headers)
  (guest_token::text = (current_setting('request.headers', true)::json ->> 'x-guest-token')) OR
  
  -- 5. Guests (by guest phone in custom request headers)
  (guest_phone = (current_setting('request.headers', true)::json ->> 'x-guest-phone')) OR
  
  -- 6. Guests (by guest token in cookies)
  (guest_token::text = (current_setting('request.cookies', true)::json ->> 'guest_token')) OR
  
  -- 7. Guests (by guest phone in cookies)
  (guest_phone = (current_setting('request.cookies', true)::json ->> 'guest_phone'))
);

CREATE POLICY "Allow update access to orders for owners and admins"
ON public.orders FOR UPDATE
USING (
  -- 1. Admin users (by email or metadata role)
  (auth.jwt() ->> 'email' = 'admin@angels.it') OR 
  (auth.jwt() ->> 'email' = 'eraldolamberto@gmail.com') OR 
  ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin') OR
  
  -- 2. Registered customers
  (auth.uid() = customer_id) OR
  
  -- 3. Guests (by verified auth phone number)
  (guest_phone = (auth.jwt() ->> 'phone')) OR
  
  -- 4. Guests (by guest token in custom request headers)
  (guest_token::text = (current_setting('request.headers', true)::json ->> 'x-guest-token')) OR
  
  -- 5. Guests (by guest phone in custom request headers)
  (guest_phone = (current_setting('request.headers', true)::json ->> 'x-guest-phone')) OR
  
  -- 6. Guests (by guest token in cookies)
  (guest_token::text = (current_setting('request.cookies', true)::json ->> 'guest_token')) OR
  
  -- 7. Guests (by guest phone in cookies)
  (guest_phone = (current_setting('request.cookies', true)::json ->> 'guest_phone'))
)
WITH CHECK (
  -- 1. Admin users can set any status
  (auth.jwt() ->> 'email' = 'admin@angels.it') OR 
  (auth.jwt() ->> 'email' = 'eraldolamberto@gmail.com') OR 
  ((auth.jwt() -> 'user_metadata' ->> 'role') = 'admin') OR
  
  -- 2. Clients/Guests
  (
    (
      (auth.uid() = customer_id) OR
      (guest_phone = (auth.jwt() ->> 'phone')) OR
      (guest_token::text = (current_setting('request.headers', true)::json ->> 'x-guest-token')) OR
      (guest_token::text = (current_setting('request.cookies', true)::json ->> 'guest_token'))
    ) AND (
      status = 'cancelled'
    )
  )
);

-- Assign admin role metadata to the email if the user is already created
UPDATE auth.users
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"role": "admin"}'::jsonb
WHERE email = 'eraldolamberto@gmail.com';
