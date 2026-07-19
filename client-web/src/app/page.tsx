'use client';

import React, { useState, useEffect } from 'react';
import MenuCatalog, { MenuItem } from '../components/MenuCatalog';
import { supabase } from '../lib/supabaseClient';
import styles from './page.module.css';

interface CartItem extends MenuItem {
  quantity: number;
}

export default function Home() {
  const [cart, setCart] = useState<CartItem[]>([]);
  const [isCheckingOut, setIsCheckingOut] = useState(false);
  const [checkoutMode, setCheckoutMode] = useState<'guest' | 'login'>('guest');
  const [paymentMethod, setPaymentMethod] = useState<'cod' | 'stripe'>('cod');
  
  // Guest checkout details
  const [guestName, setGuestName] = useState('');
  const [guestPhone, setGuestPhone] = useState('');
  const [guestAddress, setGuestAddress] = useState('');
  const [deliveryType, setDeliveryType] = useState<'delivery' | 'pickup'>('delivery');
  
  // OTP simulation details
  const [otpPhone, setOtpPhone] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState('');

  // Order state
  const [placedOrderId, setPlacedOrderId] = useState<string | null>(null);
  const [orderStatus, setOrderStatus] = useState<string>('pending');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Cart actions
  const handleAddToCart = (item: MenuItem) => {
    setCart((prevCart) => {
      const existing = prevCart.find((i) => i.id === item.id);
      if (existing) {
        return prevCart.map((i) =>
          i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
        );
      }
      return [...prevCart, { ...item, quantity: 1 }];
    });
  };

  const handleIncreaseQty = (id: string) => {
    setCart((prevCart) =>
      prevCart.map((item) =>
        item.id === id ? { ...item, quantity: item.quantity + 1 } : item
      )
    );
  };

  const handleDecreaseQty = (id: string) => {
    setCart((prevCart) =>
      prevCart
        .map((item) =>
          item.id === id ? { ...item, quantity: item.quantity - 1 } : item
        )
        .filter((item) => item.quantity > 0)
    );
  };

  const cartTotal = cart.reduce((acc, item) => acc + item.price * item.quantity, 0);

  // Real-time tracking subscription
  useEffect(() => {
    if (!placedOrderId) return;

    const channel = supabase
      .channel(`order-tracker-${placedOrderId}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', filter: `id=eq.${placedOrderId}`, schema: 'public', table: 'orders' },
        (payload) => {
          if (payload.new && payload.new.status) {
            setOrderStatus(payload.new.status);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [placedOrderId]);

  // Scroll to top when an order is placed (crucial for mobile layout redirection feedback)
  useEffect(() => {
    if (placedOrderId) {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
  }, [placedOrderId]);

  // Order submission
  const handleCheckoutSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    let customerName = guestName;
    let customerPhone = guestPhone;
    let deliveryAddress = deliveryType === 'delivery' ? guestAddress : 'Asporto / Ritiro';

    if (checkoutMode === 'login') {
      if (!otpPhone || !otpCode) {
        alert('Inserisci il numero di telefono e il codice OTP ricevuto per procedere!');
        return;
      }
      customerName = 'Utente OTP';
      customerPhone = otpPhone;
      deliveryAddress = 'Profilo Salvato / Asporto';
    } else {
      if (!guestName || !guestPhone) {
        alert('Compila il Nome e il Telefono prima di inviare!');
        return;
      }
      if (deliveryType === 'delivery' && !guestAddress) {
        alert('Inserisci l\'indirizzo di consegna per procedere!');
        return;
      }
    }

    try {
      setIsSubmitting(true);

      const orderPayload = {
        guest_name: customerName,
        guest_phone: customerPhone,
        delivery_address: deliveryAddress,
        items: cart.map(item => ({
          menu_item_id: item.id,
          name: item.name,
          qty: item.quantity,
          price_at_order: item.price
        })),
        total_amount: cartTotal,
        payment_method: paymentMethod,
        payment_status: 'pending',
        status: 'pending',
      };

      const { data: orderData, error: orderError } = await supabase
        .from('orders')
        .insert(orderPayload)
        .select()
        .single();

      if (orderError) throw orderError;

      // Success
      setPlacedOrderId(orderData.id);
      setOrderStatus('pending');
      setCart([]);
      setIsCheckingOut(false);
      
      // Reset form states
      setGuestName('');
      setGuestPhone('');
      setGuestAddress('');
      setOtpPhone('');
      setOtpSent(false);
      setOtpCode('');
    } catch (err: any) {
      console.error('Error placing order:', err);
      alert(`Impossibile inviare l'ordine: ${err.message || err}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSendOTP = () => {
    if (!otpPhone) {
      alert('Inserisci un numero di cellulare valido.');
      return;
    }
    setOtpSent(true);
    alert(`[Simulatore Supabase Auth] Codice OTP inviato a ${otpPhone}. Digita un codice qualsiasi per procedere.`);
  };

  const scrollToMenu = () => {
    document.getElementById('menu-section')?.scrollIntoView({ behavior: 'smooth' });
  };

  const scrollToNews = () => {
    document.getElementById('news-marquee')?.scrollIntoView({ behavior: 'smooth' });
  };

  const scrollToFooter = () => {
    document.getElementById('footer-section')?.scrollIntoView({ behavior: 'smooth' });
  };

  // If order is placed, render tracking panel
  if (placedOrderId) {
    return (
      <div className={styles.pageContainer}>
        <header className={styles.header}>
          <div className={styles.headerContainer}>
            <div className={styles.logoContainer}>
              <svg className={styles.logoWings} viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
                <path d="M 15 50 C 5 40, 5 25, 25 35 C 30 25, 10 15, 35 25 C 40 15, 20 5, 45 20 C 48 30, 48 45, 45 50" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round"/>
                <path d="M 85 50 C 95 40, 95 25, 75 35 C 70 25, 90 15, 65 25 C 60 15, 80 5, 55 20 C 52 30, 52 45, 55 50" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round"/>
                <path d="M 38 48 C 30 45, 30 35, 40 35 C 38 28, 62 28, 60 35 C 70 35, 70 45, 62 48 Z" fill="white" stroke="white" strokeWidth="2"/>
                <rect x="42" y="48" width="16" height="8" rx="2" fill="white"/>
                <rect x="44" y="52" width="12" height="2" fill="#EA580C"/>
              </svg>
              <div className={styles.logoTextWrapper}>
                <span className={styles.logoText}>Angels</span>
                <span className={styles.logoSubtext}>Kebab & Fast Food • Pizzeria</span>
              </div>
            </div>
          </div>
        </header>

        <div className={styles.trackerContainer}>
          <h2 className={styles.trackerTitle}>Ordine Ricevuto!</h2>
          <p style={{ fontWeight: '600' }}>Il tuo ordine è stato registrato ed è in fase di elaborazione dal gestore.</p>
          
          <div className={`${styles.trackerStatus} ${styles[`status-${orderStatus}`]}`}>
            {orderStatus === 'pending' && '⏳ In Attesa di Conferma'}
            {orderStatus === 'accepted' && '🧑‍🍳 In Preparazione'}
            {orderStatus === 'delivering' && '🛵 In Consegna (Fattorino partito)'}
            {orderStatus === 'completed' && '✅ Consegnato! Buon Appetito!'}
            {orderStatus === 'cancelled' && '❌ Annullato dal Locale'}
          </div>

          <p className={styles.trackerTime}>
            Tempo stimato di consegna: 30 minuti. Rimani su questa pagina per tracciare gli aggiornamenti in tempo reale.
          </p>

          <button
            onClick={() => setPlacedOrderId(null)}
            className={styles.orderButton}
            style={{ width: 'auto', padding: '0.8rem 2rem' }}
          >
            Fai un nuovo ordine
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.pageContainer}>
      {/* Visual Design top indicator bar */}
      <div className={styles.optionBar}>
        <span>Proposta di Design: Home Page Interattiva per Angels Livorno</span>
        <span>Aggiungi le delizie dal menu ed effettua un ordine di prova!</span>
      </div>

      {/* STICKY HEADER */}
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          <div className={styles.logoContainer}>
            <svg className={styles.logoWings} viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <path d="M 15 50 C 5 40, 5 25, 25 35 C 30 25, 10 15, 35 25 C 40 15, 20 5, 45 20 C 48 30, 48 45, 45 50" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round"/>
              <path d="M 85 50 C 95 40, 95 25, 75 35 C 70 25, 90 15, 65 25 C 60 15, 80 5, 55 20 C 52 30, 52 45, 55 50" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round"/>
              <path d="M 38 48 C 30 45, 30 35, 40 35 C 38 28, 62 28, 60 35 C 70 35, 70 45, 62 48 Z" fill="white" stroke="white" stroke-width="2"/>
              <rect x="42" y="48" width="16" height="8" rx="2" fill="white"/>
              <rect x="44" y="52" width="12" height="2" fill="#EA580C"/>
            </svg>
            <div className={styles.logoTextWrapper}>
              <span className={styles.logoText}>Angels</span>
              <span className={styles.logoSubtext}>Kebab & Fast Food • Pizzeria</span>
            </div>
          </div>

          <nav className={styles.nav}>
            <span onClick={scrollToMenu} className={styles.navLink}>Il Menu</span>
            <span onClick={scrollToNews} className={styles.navLink}>Notizie & Novità</span>
            <span onClick={scrollToFooter} className={styles.navLink}>Contatti</span>
          </nav>

          <button className={styles.cartBadgeContainer} onClick={() => {
            document.getElementById('cart-sidebar-section')?.scrollIntoView({ behavior: 'smooth' });
          }}>
            🛒 Carrello
            <span className={styles.cartBadge}>
              {cart.reduce((acc, item) => acc + item.quantity, 0)}
            </span>
          </button>
        </div>
      </header>

      {/* HERO SECTION STYLED LIKE THE MOCKUP INAUGURATION */}
      <section className={styles.hero}>
        <div className={styles.heroContainer}>
          <div>
            <div className={styles.heroBadge}>Inaugurazione</div>
            <h1 className={styles.heroTitle}>Grande<br />Inaugurazione</h1>
            <span className={styles.heroScript}>Sabato 18 Luglio dalle 17:00 alle 22:00</span>
            <p className={styles.heroText}>
              Vieni ad assaggiare la nostra <strong>Pizza Gratis</strong> in Piazza Mazzini 82/83 a Livorno! Oppure ordina subito online con consegna a domicilio.
            </p>
            <div className={styles.heroButtons}>
              <button className={`${styles.btn} ${styles.btnPrimary}`} onClick={scrollToMenu}>Ordina Ora</button>
              <button className={`${styles.btn} ${styles.btnSecondary}`} onClick={scrollToNews}>Novità & Offerte</button>
            </div>
          </div>

          <div className={styles.heroImageArea}>
            <div className={styles.heroPizzaSticker}>
              <span>Assaggia la</span>
              <h2>Pizza</h2>
              <h2>Gratis</h2>
            </div>
            <div className={styles.restaurantImageMockup}>
              <svg width="100%" height="100%" viewBox="0 0 450 300" style={{ background: '#EA580C', display: 'block' }}>
                <circle cx="225" cy="150" r="120" fill="#FACC15" />
                <path d="M225 150 L150 70 A120 120 0 0 1 300 70 Z" fill="#EF4444" stroke="#1C1917" strokeWidth="6" />
                <circle cx="225" cy="100" r="8" fill="#FACC15" />
                <circle cx="200" cy="110" r="8" fill="#FACC15" />
                <circle cx="250" cy="110" r="8" fill="#FACC15" />
                <circle cx="225" cy="80" r="4" fill="#10B981" />
                <circle cx="205" cy="90" r="4" fill="#10B981" />
                <circle cx="245" cy="90" r="4" fill="#10B981" />
                <rect x="260" y="160" width="100" height="40" rx="20" transform="rotate(-30 260 160)" fill="#F5F5F4" stroke="#1C1917" strokeWidth="4" />
                <path d="M 330 110 L 360 90 L 340 125 Z" fill="#10B981" />
                <path d="M 320 115 L 340 100 L 335 125 Z" fill="#EF4444" />
                <text x="225" y="275" fontFamily="'Montserrat', sans-serif" fontWeight="900" fontSize="22" fill="#1C1917" textAnchor="middle">
                  PIZZA, KEBAB & SFIZIOSITÀ
                </text>
              </svg>
            </div>
          </div>
        </div>
      </section>

      {/* MOVING NEWS MARQUEE */}
      <div id="news-marquee" className={styles.newsBanner}>
        <div className={styles.newsTrack}>
          <div className={styles.newsItem}>🔥 CONSEGNA A DOMICILIO ATTIVA: Tel. <span>0586 99 65 24</span></div>
          <div className={styles.newsItem}>🍕 INAUGURAZIONE SABATO 18 LUGLIO: <span>PIZZA GRATIS</span> PER TUTTI</div>
          <div className={styles.newsItem}>🍔 PANINO KEBAB A SOLI <span>€ 5,00</span></div>
          <div className={styles.newsItem}>🌟 SCOPRI I NUOVI COCKTAIL DA ASPORTO A <span>€ 5,00 / € 6,00</span></div>
        </div>
      </div>

      {/* MAIN TWO-COLUMN LAYOUT */}
      <main className={styles.mainLayout}>
        {/* Left Column: Menu Catalog */}
        <div id="menu-section" className={styles.menuColumn}>
          <div className={styles.columnHeader}>
            <span>📖 Il Nostro Menu</span>
            <span className={styles.columnHeaderSubtext}>Clicca per aggiungere al carrello</span>
          </div>
          <MenuCatalog onAddToCart={handleAddToCart} />
        </div>

        {/* Right Column: Sidebar (Cart & Notices) */}
        <div id="cart-sidebar-section" className={styles.sidebar}>
          {/* CART CARD WIDGET */}
          <div className={styles.sidebarWidget}>
            <div className={styles.widgetTitle}>
              <span>🛒 Il Tuo Ordine</span>
            </div>

            {!isCheckingOut ? (
              // CART SUMMARY VIEW
              <div>
                {cart.length === 0 ? (
                  <p className={styles.cartEmpty}>Il carrello è vuoto. Aggiungi qualche delizia dal menu!</p>
                ) : (
                  <>
                    <ul className={styles.cartList}>
                      {cart.map((item) => (
                        <li key={item.id} className={styles.cartItem}>
                          <div className={styles.cartItemInfo}>
                            <span className={styles.cartItemName}>{item.name}</span>
                            <span className={styles.cartItemQty}>Quantità: {item.quantity}</span>
                          </div>
                          <div className={styles.cartItemRight}>
                            <span className={styles.cartItemPrice}>
                              €{(item.price * item.quantity).toFixed(2)}
                            </span>
                            <button onClick={() => handleDecreaseQty(item.id)} className={styles.qtyBtn}>-</button>
                            <button onClick={() => handleIncreaseQty(item.id)} className={styles.qtyBtn}>+</button>
                          </div>
                        </li>
                      ))}
                    </ul>

                    <div className={styles.cartSummary}>
                      <div className={styles.cartRow}>
                        <span>Subtotale</span>
                        <span>€{cartTotal.toFixed(2)}</span>
                      </div>
                      <div className={styles.cartRow}>
                        <span>Consegna a domicilio</span>
                        <span style={{ color: '#10B981' }}>Gratis</span>
                      </div>
                      <div className={`${styles.cartRow} ${styles.cartTotal}`}>
                        <span>Totale</span>
                        <span>€{cartTotal.toFixed(2)}</span>
                      </div>
                    </div>

                    <button
                      onClick={() => setIsCheckingOut(true)}
                      className={styles.orderButton}
                    >
                      Procedi all'Ordine
                    </button>
                  </>
                )}
              </div>
            ) : (
              // CHECKOUT FORM VIEW
              <div className={styles.checkoutOverlay}>
                <h3 className={styles.formTitle}>Completa Ordine</h3>
                
                <form onSubmit={handleCheckoutSubmit}>
                  {/* Mode Tabs */}
                  <div style={{ display: 'flex', border: '2px solid #1c1917', borderRadius: '6px', overflow: 'hidden', marginBottom: '1rem' }}>
                    <div
                      onClick={() => setCheckoutMode('guest')}
                      className={`${styles.deliveryTab} ${checkoutMode === 'guest' ? styles.deliveryTabActive : ''}`}
                      style={{ flex: 1, border: 'none', borderRadius: 0, boxShadow: 'none' }}
                    >
                      Ordine Rapido
                    </div>
                    <div
                      onClick={() => setCheckoutMode('login')}
                      className={`${styles.deliveryTab} ${checkoutMode === 'login' ? styles.deliveryTabActive : ''}`}
                      style={{ flex: 1, border: 'none', borderRadius: 0, boxShadow: 'none' }}
                    >
                      Accedi / OTP
                    </div>
                  </div>

                  {checkoutMode === 'guest' ? (
                    // Guest Fields
                    <>
                      <div className={styles.formGroup}>
                        <label className={styles.formLabel}>Nome Completo *</label>
                        <input
                          type="text"
                          required
                          value={guestName}
                          onChange={(e) => setGuestName(e.target.value)}
                          placeholder="Mario Rossi"
                          className={styles.formInput}
                        />
                      </div>

                      <div className={styles.formGroup}>
                        <label className={styles.formLabel}>Metodo di Ricezione *</label>
                        <div className={styles.rowInputs}>
                          <button
                            type="button"
                            onClick={() => setDeliveryType('delivery')}
                            className={`${styles.deliveryTab} ${deliveryType === 'delivery' ? styles.deliveryTabActive : ''}`}
                          >
                            Consegna
                          </button>
                          <button
                            type="button"
                            onClick={() => setDeliveryType('pickup')}
                            className={`${styles.deliveryTab} ${deliveryType === 'pickup' ? styles.deliveryTabActive : ''}`}
                          >
                            Asporto
                          </button>
                        </div>
                      </div>

                      {deliveryType === 'delivery' && (
                        <div className={styles.formGroup}>
                          <label className={styles.formLabel}>Indirizzo di Consegna (Livorno) *</label>
                          <input
                            type="text"
                            required
                            value={guestAddress}
                            onChange={(e) => setGuestAddress(e.target.value)}
                            placeholder="Piazza Mazzini 10, Livorno"
                            className={styles.formInput}
                          />
                        </div>
                      )}

                      <div className={styles.formGroup}>
                        <label className={styles.formLabel}>Telefono (per conferma) *</label>
                        <input
                          type="tel"
                          required
                          value={guestPhone}
                          onChange={(e) => setGuestPhone(e.target.value)}
                          placeholder="333 1234567"
                          className={styles.formInput}
                        />
                      </div>
                    </>
                  ) : (
                    // OTP Simulated Auth Fields
                    <>
                      <div className={styles.formGroup}>
                        <label className={styles.formLabel}>Numero di cellulare *</label>
                        <div style={{ display: 'flex', gap: '5px' }}>
                          <input
                            type="tel"
                            value={otpPhone}
                            onChange={(e) => setOtpPhone(e.target.value)}
                            placeholder="+39 333 1234567"
                            className={styles.formInput}
                            style={{ flex: 1 }}
                          />
                          <button
                            type="button"
                            onClick={handleSendOTP}
                            className={styles.btnPrimary}
                            style={{
                              padding: '6px 12px',
                              fontSize: '0.8rem',
                              borderRadius: '6px',
                              border: '2px solid #1c1917',
                              cursor: 'pointer',
                              fontWeight: 'bold',
                              whiteSpace: 'nowrap'
                            }}
                          >
                            Invia OTP
                          </button>
                        </div>
                      </div>

                      {otpSent && (
                        <div className={styles.formGroup}>
                          <label className={styles.formLabel}>Codice OTP Ricevuto *</label>
                          <input
                            type="text"
                            required
                            value={otpCode}
                            onChange={(e) => setOtpCode(e.target.value)}
                            placeholder="Es: 123456"
                            className={styles.formInput}
                          />
                        </div>
                      )}
                    </>
                  )}

                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Metodo di Pagamento</label>
                    <div className={styles.paymentMethodContainer}>
                      <div
                        onClick={() => setPaymentMethod('cod')}
                        className={`${styles.paymentOption} ${paymentMethod === 'cod' ? styles.paymentOptionActive : ''}`}
                      >
                        Consegna
                      </div>
                      <div className={`${styles.paymentOption} ${styles.paymentOptionDisabled}`}>
                        Carta Credito
                      </div>
                    </div>
                  </div>

                  <div className={styles.formButtons}>
                    <button
                      type="submit"
                      disabled={isSubmitting}
                      className={styles.submitBtn}
                    >
                      {isSubmitting ? 'Invio...' : `Invia Ordine (€${cartTotal.toFixed(2)})`}
                    </button>
                    <button
                      type="button"
                      onClick={() => setIsCheckingOut(false)}
                      className={styles.cancelBtn}
                    >
                      Indietro
                    </button>
                  </div>
                </form>
              </div>
            )}
          </div>

          {/* UPDATES & NEWS WIDGET */}
          <div className={styles.sidebarWidget}>
            <div className={styles.widgetTitle}>
              <span>📰 Novità & Aggiornamenti</span>
            </div>
            <div className={styles.newsWidgetItem}>
              <div className={styles.newsDate}>17 Luglio 2026</div>
              <div className={styles.newsTitle}>Servizio Online Attivo</div>
              <div className={styles.newsDesc}>Da oggi puoi ordinare sul sito ed il gestore riceverà la notifica istantanea sull'app proprietaria.</div>
            </div>
            <hr style={{ margin: '12px 0', border: '0', borderTop: '1px dotted #cccccc' }} />
            <div className={styles.newsWidgetItem}>
              <div className={styles.newsDate}>16 Luglio 2026</div>
              <div className={styles.newsTitle}>Nuove Pizze in Menu</div>
              <div className={styles.newsDesc}>Aggiunte le pizze speciali del volantino: Boscaiola, Capricciosa, Tartufata Special, Mortadella e Pistacchio!</div>
            </div>
          </div>
        </div>
      </main>

      {/* FOOTER STYLED LIKE THE MOCKUP FOOTER INFO */}
      <footer id="footer-section" className={styles.footer}>
        <div className={styles.footerContainer}>
          <div className={styles.footerInfo}>
            <h3>Angels Livorno</h3>
            <p>Kebab, Fast Food, Ristorante Etnico & Pizzeria.</p>
            <p>Il gusto unico della vera pizza e della carne speziata di prima scelta.</p>
          </div>
          <div className={styles.footerInfo}>
            <h3>Orari & Consegne</h3>
            <p>📍 Piazza Mazzini 82/83 - Livorno</p>
            <p>📞 Telefono: <a href="tel:0586996524">0586 99 65 24</a></p>
            <p>⏰ Aperto tutti i giorni dalle 12:00 alle 24:00</p>
          </div>
          <div className={styles.footerInfo}>
            <h3>Tecnologia</h3>
            <p>Sviluppato con <strong>Google Antigravity Core</strong> & <strong>Supabase</strong>.</p>
            <p>Ordinazioni real-time collegate all'applicazione del gestore.</p>
          </div>
        </div>
        <div className={styles.copyright}>
          © 2026 Angels Livorno. Tutti i diritti riservati.
        </div>
      </footer>
    </div>
  );
}
