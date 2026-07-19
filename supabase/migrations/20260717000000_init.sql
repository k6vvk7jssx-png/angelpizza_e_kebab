-- 1. Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT UNIQUE NOT NULL,
    full_name TEXT,
    default_address TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS on profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to profiles" 
ON public.profiles FOR SELECT USING (true);

CREATE POLICY "Allow users to update their own profile" 
ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- 3. Create menu_items table
CREATE TABLE IF NOT EXISTS public.menu_items (
    id BIGINT PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL, -- 'fastfood', 'specialita', 'pizze', 'delizie', 'bevande'
    price NUMERIC(10, 2) NOT NULL,
    description TEXT,
    image_path TEXT,
    is_available BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS on menu_items
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to menu_items" 
ON public.menu_items FOR SELECT USING (true);

-- 4. Create orders table
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    guest_name TEXT,
    guest_phone TEXT,
    delivery_address TEXT NOT NULL,
    items JSONB NOT NULL, -- Array of {menu_item_id, name, qty, price_at_order}
    total_amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT DEFAULT 'cod' NOT NULL, -- 'cod', 'stripe'
    payment_status TEXT DEFAULT 'pending' NOT NULL, -- 'pending', 'paid', 'failed'
    status TEXT DEFAULT 'pending' NOT NULL, -- 'pending', 'preparing', 'delivering', 'completed', 'cancelled'
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Enable RLS on orders
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public insert access to orders" 
ON public.orders FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow users to view their own orders" 
ON public.orders FOR SELECT USING (
    (auth.uid() = customer_id) OR 
    (auth.role() = 'service_role')
);

CREATE POLICY "Allow gestore (service_role) to update orders" 
ON public.orders FOR UPDATE USING (true);

-- 5. Enable Supabase Realtime for the orders table
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.menu_items;

-- 6. Insert default menu items from the flyers
INSERT INTO public.menu_items (id, name, category, price, description, is_available) VALUES
(1, 'Panino Kebab', 'fastfood', 5.00, 'Carne kebab di prima scelta, lattuga, pomodoro, cipolla e salse in pane caldo.', true),
(2, 'Piadina Kebab', 'fastfood', 6.00, 'Carne kebab, insalata fresca, pomodoro e salse avvolti in una piadina morbida.', true),
(3, 'Panino Falafel', 'fastfood', 5.00, 'Polpette di ceci speziate e croccanti con lattuga, pomodoro e salse nel panino.', true),
(4, 'Piadina Falafel', 'fastfood', 6.00, 'Piadina arrotolata con falafel dorati, insalata mista e salse.', true),
(5, 'Panino Seekh Kebab', 'fastfood', 5.00, 'Spiedini di carne tritata speziata cotta alla griglia con verdure e salse.', true),
(6, 'Piadina Seekh Kebab', 'fastfood', 6.00, 'Piadina arrotolata con spiedini di carne tritata speziata alla griglia, insalata e salse.', true),
(7, 'Menù Panino Kebab', 'fastfood', 8.50, 'Panino Kebab classico servito con patatine fritte croccanti e bibita in lattina a scelta.', true),
(8, 'Menù Piadina Kebab', 'fastfood', 9.50, 'Piadina Kebab classica servita con patatine fritte croccanti e bibita in lattina a scelta.', true),
(9, 'Patatine Fritte (Piccole)', 'fastfood', 2.50, 'Porzione piccola di patatine fritte dorate e salate.', true),
(10, 'Patatine Fritte (Grandi)', 'fastfood', 3.50, 'Porzione abbondante di patatine fritte dorate e salate.', true),
(11, 'Vegetable Biryani', 'specialita', 9.00, 'Riso basmati speziato cotto a fuoco lento con verdure miste e aromi orientali.', true),
(12, 'Chicken Biryani', 'specialita', 9.00, 'Riso basmati cotto con pollo tenero marinato in spezie tradizionali biryani.', true),
(13, 'Piatto Kebab', 'specialita', 9.00, 'Carne kebab speziata servita al piatto con contorno di insalata fresca, pomodori e salse.', true),
(14, 'Piatto Kebab con Riso', 'specialita', 9.00, 'Carne kebab servita al piatto accompagnata da riso basmati aromatico e salse.', true),
(15, 'Piatto Falafel', 'specialita', 9.00, 'Porzione di falafel dorati serviti al piatto con insalata fresca, hummus e pane.', true),
(16, 'Piatto Seekh Kebab', 'specialita', 9.00, 'Spiedini di carne tritata speziata alla griglia serviti al piatto con insalata e salse.', true),
(17, 'Specialità di Ceci con Pane', 'specialita', 9.00, 'Zuppa di ceci speziata della casa servita calda accompagnata da pane artigianale.', true),
(21, 'Hot Dog', 'delizie', 3.00, 'Wurstel classico grigliato servito in pane morbido con maionese e ketchup.', true),
(22, 'Hamburger', 'delizie', 5.00, 'Svizzera di manzo saporita con lattuga fresca, pomodoro e salse.', true),
(23, 'Chicken Burger', 'delizie', 6.00, 'Cotoletta di pollo croccante con lattuga, pomodoro e maionese.', true),
(24, 'Chicken Nuggets', 'delizie', 5.00, 'Bocconcini di pollo croccanti fritti (6 pezzi).', true),
(25, 'Alette di Pollo', 'delizie', 5.00, 'Alette di pollo speziate e fritte a doratura (6 pezzi).', true),
(26, 'Onion Rings', 'delizie', 4.00, 'Anelli di cipolla pastellati e fritti (8 pezzi).', true),
(27, 'Samosa', 'delizie', 5.00, 'Fagottini di sfoglia fritti ripieni di patate, piselli e spezie (5 pezzi).', true),
(28, 'Baklava', 'delizie', 2.50, 'Dolce tipico di sfoglia con noci, pistacchi e sciroppo di miele (1 pezzo).', true),
(32, 'Pizza Margherita', 'pizze', 7.00, 'Pomodoro saporito, mozzarella filante, olio d''oliva e basilico.', true),
(35, 'Pizza Salamino', 'pizze', 8.00, 'Pomodoro, mozzarella e fettine di salame piccante.', true),
(49, 'Pizza Diavola', 'pizze', 8.00, 'Pomodoro, mozzarella, salame piccante e peperoncino.', true),
(50, 'Pizza Vegetariana', 'pizze', 9.00, 'Pomodoro, mozzarella e verdure fresche grigliate al forno.', true),
(66, 'Riso Fritto con Pollo', 'bevande', 5.00, 'Riso saltato in padella con pezzetti di pollo, uovo e verdure.', true),
(70, 'Pane Naan', 'bevande', 1.50, 'Pane piatto tradizionale cotto al forno tandoor (1 pezzo).', true),
(71, 'Naan con Formaggio', 'bevande', 2.00, 'Pane tandoor ripieno di formaggio fuso filante.', true),
(90, 'Acqua 50cl', 'bevande', 1.00, 'Acqua minerale naturale o frizzante in bottiglia da 50cl.', true),
(91, 'Bibita in lattina', 'bevande', 1.50, 'Bibita a scelta (Coca Cola, Fanta, Sprite, Estathé) in lattina da 33cl.', true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    category = EXCLUDED.category,
    price = EXCLUDED.price,
    description = EXCLUDED.description;
