-- Migration: Add requested_time column to orders table to support delivery/pickup time selection and management
-- Date: 2026-07-19

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS requested_time TIMESTAMPTZ DEFAULT (now() + interval '30 minutes') NOT NULL;
