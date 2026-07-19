-- Migration: Add €12 Combo Menu item
-- Date: 2026-07-19

INSERT INTO public.menu_items (id, name, category, price, description, is_available)
VALUES (119, 'Menù Speciale Angels', 'specialita', 12.00, 'Scegli una Pizza o un Panino Kebab + una porzione di patatine fritte + una bibita in lattina.', true)
ON CONFLICT (id) DO UPDATE 
SET name = EXCLUDED.name,
    category = EXCLUDED.category,
    price = EXCLUDED.price,
    description = EXCLUDED.description,
    is_available = EXCLUDED.is_available;
