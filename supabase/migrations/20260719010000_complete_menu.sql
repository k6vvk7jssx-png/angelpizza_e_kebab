-- Truncate existing menu items to clean up any wrong categories
TRUNCATE TABLE public.menu_items CASCADE;

-- Insert complete menu items from the printed flyers with correct categories
INSERT INTO public.menu_items (id, name, category, price, description, is_available) VALUES
-- FAST FOOD
(1, 'Panino Kebab', 'fastfood', 5.00, 'Carne kebab di prima scelta, lattuga, pomodoro, cipolla e salse in pane caldo.', true),
(2, 'Piadina Kebab', 'fastfood', 6.00, 'Carne kebab, insalata fresca, pomodoro e salse avvolti in una piadina morbida.', true),
(3, 'Panino Falafel', 'fastfood', 5.00, 'Polpette di ceci speziate e croccanti con lattuga, pomodoro e salse nel panino.', true),
(4, 'Piadina Falafel', 'fastfood', 6.00, 'Piadina arrotolata con falafel dorati, insalata mista e salse.', true),
(5, 'Panino Seekh Kebab', 'fastfood', 5.00, 'Spiedini di carne tritata speziata cotta alla griglia con verdure e salse.', true),
(6, 'Piadina Seekh Kebab', 'fastfood', 6.00, 'Piadina arrotolata con spiedini di carne tritata speziata alla griglia, insalata e salse.', true),
(7, 'Menù Panino Kebab', 'fastfood', 8.50, 'Panino Kebab classico servito con patatine fritte croccanti e bibita in lattina.', true),
(8, 'Menù Piadina Kebab', 'fastfood', 9.50, 'Piadina Kebab classica servita con patatine fritte croccanti e bibita in lattina.', true),
(9, 'Patatine Fritte Piccole', 'fastfood', 2.50, 'Porzione piccola di patatine fritte dorate.', true),
(10, 'Patatine Fritte Grandi', 'fastfood', 3.50, 'Porzione grande di patatine fritte dorate.', true),
(29, 'Kebab con Pane da Asporto (Piccolo)', 'fastfood', 7.00, 'Kebab al piatto servito con pane da asporto (porzione piccola).', true),
(30, 'Kebab con Pane da Asporto (Grande)', 'fastfood', 12.00, 'Kebab al piatto servito con pane da asporto (porzione grande).', true),
(92, 'Kebab Solo Carne da Asporto (Piccolo)', 'fastfood', 9.00, 'Solo carne kebab in vaschetta da asporto (porzione piccola).', true),
(93, 'Kebab Solo Carne da Asporto (Grande)', 'fastfood', 15.00, 'Solo carne kebab in vaschetta da asporto (porzione grande).', true),

-- SPECIALITÀ
(11, 'Vegetable Biryani', 'specialita', 9.00, 'Riso basmati speziato cotto a fuoco lento con verdure miste.', true),
(12, 'Chicken Biryani', 'specialita', 9.00, 'Riso basmati cotto con pollo tenero marinato in spezie tradizionali.', true),
(13, 'Piatto Kebab', 'specialita', 9.00, 'Carne kebab speziata servita al piatto con insalata fresca e salse.', true),
(14, 'Piatto Kebab con Riso', 'specialita', 9.00, 'Carne kebab servita al piatto con riso basmati aromatico.', true),
(15, 'Piatto Falafel', 'specialita', 9.00, 'Porzione di falafel dorati serviti al piatto con insalata fresca e hummus.', true),
(16, 'Piatto Seekh Kebab', 'specialita', 9.00, 'Spiedini di carne tritata speziata alla griglia serviti con insalata.', true),
(17, 'Specialità di Ceci con Pane', 'specialita', 9.00, 'Zuppa di ceci speziata servita calda con pane.', true),
(18, 'Coscia di Pollo al Forno con Pane', 'specialita', 9.00, 'Coscia di pollo saporita cotta al forno servita con pane.', true),
(19, 'Piatto Chicken Tikka Kebab BBQ', 'specialita', 9.00, 'Piatto di pollo speziato marinato cotto al barbecue.', true),
(20, 'Spezzatino di Manzo con Patate', 'specialita', 9.00, 'Spezzatino di manzo cotto a fuoco lento con patate.', true),

-- DELIZIE
(21, 'Hot Dog', 'delizie', 3.00, 'Wurstel classico grigliato servito in pane morbido con salse.', true),
(22, 'Hamburger', 'delizie', 5.00, 'Svizzera di manzo saporita con lattuga fresca, pomodoro e salse.', true),
(23, 'Chicken Burger', 'delizie', 6.00, 'Cotoletta di pollo croccante con lattuga, pomodoro e maionese.', true),
(24, 'Chicken Nuggets', 'delizie', 5.00, 'Bocconcini di pollo croccanti fritti (6 pezzi).', true),
(25, 'Alette di Pollo', 'delizie', 5.00, 'Alette di pollo speziate e fritte (6 pezzi).', true),
(26, 'Onion Rings', 'delizie', 4.00, 'Anelli di cipolla pastellati e fritti (8 pezzi).', true),
(27, 'Samosa', 'delizie', 5.00, 'Fagottini di sfoglia fritti ripieni di patate e piselli speziati (5 pezzi).', true),
(28, 'Baklava', 'delizie', 2.50, 'Dolce tipico con noci, pistacchi e sciroppo di miele (1 pezzo).', true),

-- PIZZE ROSSE
(31, 'Marinara', 'pizze_rosse', 6.00, 'Pomodoro, aglio, origano.', true),
(32, 'Margherita', 'pizze_rosse', 7.00, 'Pomodoro, mozzarella, basilico.', true),
(33, 'Cotto', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, prosciutto cotto.', true),
(34, 'Crudo', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, prosciutto crudo.', true),
(35, 'Salamino', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, salamino piccante.', true),
(36, 'Salamino Special', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, salamino piccante, peperoni, grana.', true),
(37, 'Funghi', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, funghi.', true),
(38, 'Wurstel', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, wurstel.', true),
(39, 'Wurstel e Patatine', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, wurstel, patatine fritte.', true),
(40, 'Salsiccia', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, salsiccia.', true),
(41, 'Salsiccia e Funghi', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, salsiccia, funghi.', true),
(42, 'Boscaiola', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, salsiccia, funghi, gorgonzola, olive.', true),
(43, 'Capricciosa', 'pizze_rosse', 10.00, 'Pomodoro, mozzarella, cotto, salamino piccante, funghi, carciofi, olive.', true),
(44, '4 Stagioni', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, cotto, funghi, carciofi, olive.', true),
(45, 'Napoli', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, capperi, acciughe, origano.', true),
(46, 'Cotto e Funghi', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, prosciutto cotto, funghi.', true),
(47, 'Speck e Gorgonzola', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, speck, gorgonzola.', true),
(48, 'Speck e Mascarpone', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, speck, mascarpone.', true),
(49, 'Diavola', 'pizze_rosse', 8.00, 'Pomodoro, mozzarella, salamino piccante, peperoncino.', true),
(50, 'Vegetariana', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, verdure fresche al forno.', true),
(51, 'Bufalina', 'pizze_rosse', 10.00, 'Pomodoro, mozzarella di bufala, pomodori ciliegini, basilico.', true),
(52, '4 Formaggi', 'pizze_rosse', 9.00, 'Pomodoro, mozzarella, scamorza affumicata, gorgonzola, grana.', true),

-- PIZZE BIANCHE
(53, 'Tartufata', 'pizze_bianche', 11.00, 'Mozzarella, salsa tartufata, salsiccia, patate arrosto.', true),
(54, 'Tartufata Special', 'pizze_bianche', 12.00, 'Mozzarella di bufala, salsa tartufata, funghi porcini, prosciutto crudo.', true),
(55, 'Estiva', 'pizze_bianche', 10.00, 'Mozzarella, pomodori ciliegini, rucola, crudo, grana.', true),
(56, 'Acciughina', 'pizze_bianche', 10.00, 'Mozzarella, acciughe, stracciatella di burrata.', true),
(57, 'Mortadella e Pistacchio', 'pizze_bianche', 11.00, 'Mozzarella, mortadella, stracciatella di burrata, granella di pistacchio.', true),
(58, 'Quella del Pizzaiolo', 'pizze_bianche', 10.00, 'Mozzarella di bufala, zucchine, acciughe.', true),

-- SCHIACCIATINE
(59, 'Schiacciatina Cotto e Mozzarella', 'schiacciatine', 7.00, 'Prosciutto cotto e mozzarella filante.', true),
(60, 'Schiacciatina Crudo e Mozzarella', 'schiacciatine', 7.00, 'Prosciutto crudo e mozzarella.', true),
(61, 'Schiacciatina Cotto Mozzarella e Funghi', 'schiacciatine', 8.00, 'Prosciutto cotto, mozzarella e funghi.', true),
(62, 'Schiacciatina Crudo Melanzane Salsa Verde', 'schiacciatine', 8.00, 'Prosciutto crudo, melanzane grigliate, salsa verde.', true),
(63, 'Schiacciatina Vegetariana', 'schiacciatine', 7.00, 'Verdure fresche di stagione e scamorza.', true),
(64, 'Schiacciatina Contadina', 'schiacciatine', 9.00, 'Salsa tartufata, funghi porcini, speck croccante.', true),
(65, 'Schiacciatina Bolognese', 'schiacciatine', 9.00, 'Mortadella, stracciatella di burrata, granella di pistacchio.', true),

-- RISO E NAAN
(66, 'Riso Fritto con Pollo', 'riso_naan', 5.00, 'Riso saltato in padella con pollo, uovo e verdurine saporite.', true),
(67, 'Riso Fritto con Verdure', 'riso_naan', 6.00, 'Riso saltato in padella con verdure fresche miste.', true),
(68, 'Riso Fritto con Manzo', 'riso_naan', 7.00, 'Riso saltato in padella con bocconcini di manzo e spezie.', true),
(69, 'Riso Fritto con Gamberi', 'riso_naan', 7.00, 'Riso saltato in padella con gamberetti e verdure.', true),
(70, 'Pane Naan', 'riso_naan', 1.50, 'Pane piatto indiano cotto al tandoor (1 pezzo).', true),
(71, 'Naan con Formaggio', 'riso_naan', 2.00, 'Pane tandoor ripieno di formaggio fuso (1 pezzo).', true),

-- GIRARROSTO
(80, 'Pollo Arrosto Intero', 'girarrosto', 14.00, 'Pollo intero cotto al girarrosto con erbe aromatiche.', true),
(81, 'Mezzo Pollo Arrosto', 'girarrosto', 8.00, 'Mezzo pollo arrosto speziato al girarrosto.', true),
(82, '1/4 di Pollo Arrosto', 'girarrosto', 5.00, 'Un quarto di pollo arrosto speziato.', true),
(83, 'Coscia di Pollo Arrosto con Patate', 'girarrosto', 9.00, 'Coscia di pollo arrosto servita con patate al forno dorate.', true),
(84, 'Coscia di Pollo Arrosto (Solo Coscia)', 'girarrosto', 7.00, 'Coscia di pollo arrosto speziata (senza contorno).', true),

-- BIBITE
(90, 'Acqua Naturale 50cl', 'bibite', 1.00, 'Acqua naturale in bottiglia da 50cl.', true),
(91, 'Acqua Frizzante 50cl', 'bibite', 1.00, 'Acqua frizzante in bottiglia da 50cl.', true),
(94, 'Acqua Naturale 1.5L', 'bibite', 1.50, 'Acqua naturale in bottiglia grande da 1.5L.', true),
(95, 'Acqua Frizzante 1.5L', 'bibite', 1.50, 'Acqua frizzante in bottiglia grande da 1.5L.', true),
(96, 'Estathè Brick (Limone/Pesca)', 'bibite', 1.00, 'Tè freddo Estathè in brick da 20cl.', true),
(97, 'Bibita in Lattina (Coca/Fanta/Sprite)', 'bibite', 1.50, 'Bibita fresca a scelta in lattina da 33cl.', true),
(98, 'Bibita in Bottiglietta 45cl', 'bibite', 2.00, 'Bibita in bottiglietta di plastica da 45cl.', true),
(99, 'Bibita in Bottiglia 1.5L', 'bibite', 3.50, 'Bibita in bottiglia grande da 1.5L.', true),
(100, 'Birra in Bottiglia 33cl', 'bibite', 2.00, 'Birra fresca in bottiglia piccola da 33cl.', true),
(101, 'Birra in Bottiglia 66cl', 'bibite', 2.50, 'Birra fresca in bottiglia grande da 66cl.', true),

-- COCKTAILS
(110, 'Americano', 'cocktails', 5.00, 'Campari, Vermut rosso, soda.', true),
(111, 'Aperol Spritz', 'cocktails', 5.00, 'Aperol, prosecco, soda, fetta d''arancia.', true),
(112, 'Negroni', 'cocktails', 5.00, 'Campari, Vermut rosso, Gin.', true),
(113, 'Gin Tonic', 'cocktails', 5.00, 'Gin, acqua tonica, limone.', true),
(114, 'Mojito', 'cocktails', 6.00, 'Rum bianco, foglie di menta, lime, zucchero di canna, soda.', true),
(115, 'Vodka Martini', 'cocktails', 5.00, 'Vodka, vermut dry.', true),
(116, 'Cuba Libre', 'cocktails', 5.00, 'Rum, coca cola, lime.', true),
(117, 'Limoncello Spritz', 'cocktails', 5.00, 'Limoncello, prosecco, soda.', true),
(118, 'Hugo Spritz', 'cocktails', 5.00, 'Sciroppo di fiori di sambuco, prosecco, menta, soda.', true);
