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
  const [selectedTime, setSelectedTime] = useState('asap');
  const [orderEstimatedTime, setOrderEstimatedTime] = useState<string | null>(null);
  const [isCartOpen, setIsCartOpen] = useState(false);

  // Generate 15-minute time slots starting from now + 30 minutes up to 23:45
  const getTimeSlots = () => {
    const slots = [];
    const now = new Date();
    const startTime = new Date(now.getTime() + 30 * 60 * 1000);

    const minutes = startTime.getMinutes();
    const roundedMinutes = Math.ceil(minutes / 15) * 15;
    startTime.setMinutes(roundedMinutes);
    startTime.setSeconds(0);
    startTime.setMilliseconds(0);

    const endTime = new Date();
    endTime.setHours(23);
    endTime.setMinutes(45);

    let current = new Date(startTime);
    while (current <= endTime) {
      const hoursStr = current.getHours().toString().padStart(2, '0');
      const minStr = current.getMinutes().toString().padStart(2, '0');
      slots.push(`${hoursStr}:${minStr}`);
      current.setMinutes(current.getMinutes() + 15);
    }
    return slots;
  };

  const formatEstimatedTime = (timeStr: string | null) => {
    if (!timeStr) return '30-40 minuti';
    try {
      const date = new Date(timeStr);
      const hours = date.getHours().toString().padStart(2, '0');
      const mins = date.getMinutes().toString().padStart(2, '0');
      return `${hours}:${mins}`;
    } catch (e) {
      return '30-40 minuti';
    }
  };

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
  const cartItemCount = cart.reduce((acc, item) => acc + item.quantity, 0);

  // Real-time tracking subscription
  useEffect(() => {
    if (!placedOrderId) return;

    const channel = supabase
      .channel(`order-tracker-${placedOrderId}`)
      .on(
        'postgres_changes',
        { event: 'UPDATE', filter: `id=eq.${placedOrderId}`, schema: 'public', table: 'orders' },
        (payload) => {
          if (payload.new) {
            if (payload.new.status) setOrderStatus(payload.new.status);
            if (payload.new.requested_time) setOrderEstimatedTime(payload.new.requested_time);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [placedOrderId]);

  // Scroll to top when an order is placed
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
    let deliveryAddress = deliveryType === 'delivery' ? guestAddress : 'Asporto / Ritiro in cassa';

    if (checkoutMode === 'login') {
      if (!otpPhone || !otpCode) {
        alert('Inserisci il numero di telefono e il codice OTP per procedere!');
        return;
      }
      customerName = 'Cliente Autenticato';
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

      let requestedTimeIso = new Date();
      if (selectedTime === 'asap') {
        requestedTimeIso = new Date(requestedTimeIso.getTime() + 30 * 60 * 1000);
      } else {
        const [hours, minutes] = selectedTime.split(':').map(Number);
        requestedTimeIso.setHours(hours);
        requestedTimeIso.setMinutes(minutes);
        requestedTimeIso.setSeconds(0);
        requestedTimeIso.setMilliseconds(0);
      }

      const orderPayload = {
        guest_name: customerName,
        guest_phone: customerPhone,
        delivery_address: deliveryAddress,
        items: cart.map((item) => ({
          menu_item_id: item.id,
          name: item.name,
          qty: item.quantity,
          price_at_order: item.price,
        })),
        total_amount: cartTotal,
        payment_method: paymentMethod,
        payment_status: 'pending',
        status: 'pending',
        requested_time: requestedTimeIso.toISOString(),
      };

      const { data: orderData, error: orderError } = await supabase
        .from('orders')
        .insert(orderPayload)
        .select()
        .single();

      if (orderError) throw orderError;

      // Send instant Telegram Notification
      fetch('/api/telegram-notify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          order_id: orderData.id,
          guest_name: customerName,
          guest_phone: customerPhone,
          delivery_address: deliveryAddress,
          items: cart.map((item) => ({
            name: item.name,
            qty: item.quantity,
            price_at_order: item.price,
          })),
          total_amount: cartTotal,
          requested_time: requestedTimeIso.toISOString(),
        }),
      }).catch((err) => console.error('Telegram notification error:', err));

      setPlacedOrderId(orderData.id);
      setOrderStatus(orderData.status);
      setOrderEstimatedTime(orderData.requested_time);
      setCart([]);
      setIsCheckingOut(false);
      setIsCartOpen(false);

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
    alert(`[Supabase Auth] Codice OTP inviato a ${otpPhone}. Digita un codice qualsiasi per procedere.`);
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
                <span className={styles.logoSubtext}>Pizzeria & Kebab • Livorno</span>
              </div>
            </div>
          </div>
        </header>

        <div className={styles.trackerContainer}>
          <div className={styles.trackerHeaderBadge}>🎉 Ordine Ricevuto!</div>
          <h2 className={styles.trackerTitle}>Grazie per il tuo ordine</h2>
          <p className={styles.trackerSubtitle}>Il ristorante ha preso in carico la tua ordinazione ed è in fase di preparazione.</p>

          <div className={`${styles.trackerStatus} ${styles[`status-${orderStatus}`]}`}>
            {orderStatus === 'pending' && '⏳ In Attesa di Conferma dal Ristorante'}
            {orderStatus === 'accepted' && '🧑‍🍳 In Preparazione nel Forno'}
            {orderStatus === 'delivering' && '🛵 In Consegna (Fattorino partito)'}
            {orderStatus === 'completed' && '✅ Consegnato! Buon Appetito!'}
            {orderStatus === 'cancelled' && '❌ Annullato dal Locale'}
          </div>

          <div className={styles.trackerInfoBox}>
            <span>⏰ Orario stimato:</span>
            <strong>{formatEstimatedTime(orderEstimatedTime)}</strong>
          </div>

          <button
            onClick={() => setPlacedOrderId(null)}
            className={styles.newOrderBtn}
          >
            Fai un nuovo ordine
          </button>
        </div>
      </div>
    );
  }

  const renderCartAndCheckout = () => {
    return (
      <div className={styles.sidebarWidget}>
        <div className={styles.widgetTitle}>
          <span>🛒 Il Tuo Carrello ({cartItemCount})</span>
        </div>

        {!isCheckingOut ? (
          // CART SUMMARY VIEW
          <div>
            {cart.length === 0 ? (
              <div className={styles.cartEmptyContainer}>
                <span className={styles.cartEmptyIcon}>🍕</span>
                <p className={styles.cartEmpty}>Il carrello è vuoto.<br />Scegli le pizze e le sfiziosità dal menu!</p>
              </div>
            ) : (
              <>
                <ul className={styles.cartList}>
                  {cart.map((item) => (
                    <li key={item.id} className={styles.cartItem}>
                      <div className={styles.cartItemInfo}>
                        <span className={styles.cartItemName}>{item.name}</span>
                        <span className={styles.cartItemUnitPrice}>€{item.price.toFixed(2)} cad.</span>
                      </div>
                      <div className={styles.cartItemRight}>
                        <div className={styles.cartQtyControls}>
                          <button onClick={() => handleDecreaseQty(item.id)} className={styles.qtyBtn}>−</button>
                          <span className={styles.cartQtyNum}>{item.quantity}</span>
                          <button onClick={() => handleIncreaseQty(item.id)} className={styles.qtyBtn}>+</button>
                        </div>
                        <span className={styles.cartItemSubtotal}>
                          €{(item.price * item.quantity).toFixed(2)}
                        </span>
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
                    <span className={styles.freeDeliveryBadge}>GRATIS</span>
                  </div>
                  <div className={`${styles.cartRow} ${styles.cartTotal}`}>
                    <span>Totale da Pagare</span>
                    <span>€{cartTotal.toFixed(2)}</span>
                  </div>
                </div>

                <button
                  onClick={() => setIsCheckingOut(true)}
                  className={styles.orderButton}
                >
                  Procedi all'Ordine (€{cartTotal.toFixed(2)}) →
                </button>
              </>
            )}
          </div>
        ) : (
          // CHECKOUT FORM VIEW
          <div className={styles.checkoutOverlay}>
            <div className={styles.checkoutHeaderRow}>
              <h3 className={styles.formTitle}>Dettagli Consegna</h3>
              <button
                type="button"
                onClick={() => setIsCheckingOut(false)}
                className={styles.backToCartLink}
              >
                ← Torna al carrello
              </button>
            </div>

            <form onSubmit={handleCheckoutSubmit}>
              {/* Mode Tabs */}
              <div className={styles.tabToggleGroup}>
                <div
                  onClick={() => setCheckoutMode('guest')}
                  className={`${styles.deliveryTab} ${checkoutMode === 'guest' ? styles.deliveryTabActive : ''}`}
                >
                  ⚡ Ordine Rapido
                </div>
                <div
                  onClick={() => setCheckoutMode('login')}
                  className={`${styles.deliveryTab} ${checkoutMode === 'login' ? styles.deliveryTabActive : ''}`}
                >
                  📲 Accedi / OTP
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
                      placeholder="Es. Mario Rossi"
                      className={styles.formInput}
                    />
                  </div>

                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Telefono (per la consegna) *</label>
                    <input
                      type="tel"
                      required
                      value={guestPhone}
                      onChange={(e) => setGuestPhone(e.target.value)}
                      placeholder="Es. 333 1234567"
                      className={styles.formInput}
                    />
                  </div>

                  {/* Delivery / Pickup Toggle */}
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Modalità di Ricezione</label>
                    <div className={styles.tabToggleGroup}>
                      <div
                        onClick={() => setDeliveryType('delivery')}
                        className={`${styles.deliveryTab} ${deliveryType === 'delivery' ? styles.deliveryTabActive : ''}`}
                      >
                        🛵 Domicilio
                      </div>
                      <div
                        onClick={() => setDeliveryType('pickup')}
                        className={`${styles.deliveryTab} ${deliveryType === 'pickup' ? styles.deliveryTabActive : ''}`}
                      >
                        🛍️ Asporto
                      </div>
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
                        placeholder="Es. Via Grande 45, Piano 2"
                        className={styles.formInput}
                      />
                    </div>
                  )}

                  {/* Preferred Time Selector */}
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Orario desiderato</label>
                    <select
                      value={selectedTime}
                      onChange={(e) => setSelectedTime(e.target.value)}
                      className={styles.formSelect}
                    >
                      <option value="asap">⚡ Prima possibile (~30-40 min)</option>
                      {getTimeSlots().map((slot) => (
                        <option key={slot} value={slot}>
                          🕒 {slot}
                        </option>
                      ))}
                    </select>
                  </div>
                </>
              ) : (
                // OTP Login Fields
                <>
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Numero di Telefono *</label>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <input
                        type="tel"
                        value={otpPhone}
                        onChange={(e) => setOtpPhone(e.target.value)}
                        placeholder="Es. 333 1234567"
                        className={styles.formInput}
                        style={{ flex: 1 }}
                      />
                      <button
                        type="button"
                        onClick={handleSendOTP}
                        className={styles.otpBtn}
                      >
                        Invia SMS
                      </button>
                    </div>
                  </div>

                  {otpSent && (
                    <div className={styles.formGroup}>
                      <label className={styles.formLabel}>Codice OTP Ricevuto *</label>
                      <input
                        type="text"
                        value={otpCode}
                        onChange={(e) => setOtpCode(e.target.value)}
                        placeholder="Es. 123456"
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
                    💵 Contanti alla Consegna
                  </div>
                </div>
              </div>

              <div className={styles.formButtons}>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className={styles.submitBtn}
                >
                  {isSubmitting ? 'Invio in corso...' : `Conferma Ordine (€${cartTotal.toFixed(2)})`}
                </button>
              </div>
            </form>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className={styles.pageContainer}>
      {/* STICKY HEADER */}
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          <div className={styles.logoContainer} onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}>
            <svg className={styles.logoWings} viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
              <path d="M 15 50 C 5 40, 5 25, 25 35 C 30 25, 10 15, 35 25 C 40 15, 20 5, 45 20 C 48 30, 48 45, 45 50" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round"/>
              <path d="M 85 50 C 95 40, 95 25, 75 35 C 70 25, 90 15, 65 25 C 60 15, 80 5, 55 20 C 52 30, 52 45, 55 50" fill="none" stroke="white" strokeWidth="4" strokeLinecap="round"/>
              <path d="M 38 48 C 30 45, 30 35, 40 35 C 38 28, 62 28, 60 35 C 70 35, 70 45, 62 48 Z" fill="white" stroke="white" strokeWidth="2"/>
              <rect x="42" y="48" width="16" height="8" rx="2" fill="white"/>
              <rect x="44" y="52" width="12" height="2" fill="#EA580C"/>
            </svg>
            <div className={styles.logoTextWrapper}>
              <span className={styles.logoText}>Angels</span>
              <span className={styles.logoSubtext}>Pizzeria & Kebab • Livorno</span>
            </div>
          </div>

          <nav className={styles.nav}>
            <span onClick={scrollToMenu} className={styles.navLink}>Il Menu</span>
            <span onClick={scrollToNews} className={styles.navLink}>Notizie</span>
            <span onClick={scrollToFooter} className={styles.navLink}>Contatti</span>
          </nav>

          <button
            className={styles.headerCartBtn}
            onClick={() => {
              setIsCartOpen(true);
              if (window.innerWidth >= 1024) {
                document.getElementById('cart-sidebar-section')?.scrollIntoView({ behavior: 'smooth' });
              }
            }}
          >
            🛒
            <span className={styles.headerCartText}>Carrello</span>
            {cartItemCount > 0 && (
              <span className={styles.headerCartBadge}>{cartItemCount}</span>
            )}
          </button>
        </div>
      </header>

      {/* MODERN RESTAURANT HERO BANNER (Glovo / Deliveroo Style) */}
      <section className={styles.heroSection}>
        <div className={styles.heroBannerCard}>
          <div className={styles.heroBadgesRow}>
            <span className={styles.heroBadgeHighlight}>⏰ Aperto • 12:00 - 24:00</span>
            <span className={styles.heroBadgeSecondary}>🛵 Consegna Gratuita</span>
            <span className={styles.heroBadgeSecondary}>⭐ 4.9 (500+ recensioni)</span>
          </div>

          <h1 className={styles.heroTitle}>Angels Livorno</h1>
          <p className={styles.heroSubtitle}>
            Pizzeria Artigianale, Kebab Speziato & Sfiziosità Fritte. Ordina online a domicilio o per asporto in pochi tap!
          </p>

          <div className={styles.heroInfoGrid}>
            <div className={styles.heroInfoItem}>
              <span>📍</span>
              <div>
                <strong>Piazza Mazzini 82/83</strong>
                <small>Livorno (LI)</small>
              </div>
            </div>

            <div className={styles.heroInfoItem}>
              <span>📞</span>
              <div>
                <strong>Ordini Telefonici</strong>
                <a href="tel:0586996524">0586 99 65 24</a>
              </div>
            </div>

            <div className={styles.heroInfoItem}>
              <span>⚡</span>
              <div>
                <strong>Tempo Medio</strong>
                <small>30 - 40 Minuti</small>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* MOVING NEWS MARQUEE */}
      <div id="news-marquee" className={styles.newsBanner}>
        <div className={styles.newsTrack}>
          <div className={styles.newsItem}>🔥 CONSEGNA A DOMICILIO GRATUITA • Tel. <span>0586 99 65 24</span></div>
          <div className={styles.newsItem}>🍕 PROVA IL <span>MENÙ SPECIALE A € 12,00</span> COMPLETO!</div>
          <div className={styles.newsItem}>🍔 PANINO KEBAB A SOLI <span>€ 5,00</span></div>
          <div className={styles.newsItem}>🍹 COCKTAILS DA ASPORTO A <span>€ 5,00 / € 6,00</span></div>
        </div>
      </div>

      {/* MAIN TWO-COLUMN LAYOUT */}
      <main className={styles.mainLayout}>
        {/* Left Column: Menu Catalog */}
        <div id="menu-section" className={styles.menuColumn}>
          <MenuCatalog
            onAddToCart={handleAddToCart}
            cart={cart}
            onIncreaseQty={handleIncreaseQty}
            onDecreaseQty={handleDecreaseQty}
          />
        </div>

        {/* Right Column: Sidebar (Cart & Notices) */}
        <div id="cart-sidebar-section" className={styles.sidebar}>
          {renderCartAndCheckout()}

          {/* UPDATES & NEWS WIDGET */}
          <div className={styles.sidebarWidget}>
            <div className={styles.widgetTitle}>
              <span>📰 Novità & Aggiornamenti</span>
            </div>
            <div className={styles.newsWidgetItem}>
              <div className={styles.newsDate}>Servizio Consegne Attivo</div>
              <div className={styles.newsTitle}>Ordina dal Sito in Tempo Reale</div>
              <div className={styles.newsDesc}>Puoi inviare la tua ordinazione dal cellulare ed il pizzaiolo riceverà subito la notifica sul tablet di cucina.</div>
            </div>
          </div>
        </div>
      </main>

      {/* MOBILE CART OVERLAY DRAWER */}
      {isCartOpen && (
        <div className={styles.mobileCartOverlay} onClick={() => setIsCartOpen(false)}>
          <div
            className={styles.mobileCartDrawer}
            onClick={(e) => e.stopPropagation()}
          >
            <div className={styles.drawerHeader}>
              <div className={styles.drawerHeaderTitle}>
                <span>🛒 Il Tuo Ordine</span>
                <span className={styles.drawerHeaderBadge}>{cartItemCount} articoli</span>
              </div>
              <button onClick={() => setIsCartOpen(false)} className={styles.closeDrawerBtn}>
                ✕
              </button>
            </div>
            <div className={styles.drawerBody}>
              {renderCartAndCheckout()}
            </div>
          </div>
        </div>
      )}

      {/* FLOATING BOTTOM BAR FOR MOBILE (Glovo / Deliveroo Style Pill) */}
      {cartItemCount > 0 && !isCartOpen && (
        <div className={styles.floatingBottomBar} onClick={() => setIsCartOpen(true)}>
          <div className={styles.bottomBarLeft}>
            <span className={styles.bottomBarBadge}>{cartItemCount}</span>
            <span className={styles.bottomBarText}>Vedi Ordine</span>
          </div>
          <div className={styles.bottomBarRight}>
            <span>€{cartTotal.toFixed(2)}</span>
            <span className={styles.bottomBarArrow}>→</span>
          </div>
        </div>
      )}

      {/* FOOTER */}
      <footer id="footer-section" className={styles.footer}>
        <div className={styles.footerContainer}>
          <div className={styles.footerInfo}>
            <h3>Angels Livorno</h3>
            <p>Pizzeria Artigianale, Kebab Fast Food & Ristorante Etnico.</p>
            <p>Ingredienti freschi di prima scelta e cottura al forno a legna.</p>
          </div>
          <div className={styles.footerInfo}>
            <h3>Orari & Consegne</h3>
            <p>📍 Piazza Mazzini 82/83 - Livorno</p>
            <p>📞 Telefonaci: <a href="tel:0586996524">0586 99 65 24</a></p>
            <p>⏰ Aperto tutti i giorni dalle 12:00 alle 24:00</p>
          </div>
          <div className={styles.footerInfo}>
            <h3>Ordina Online</h3>
            <p>Ordinazioni real-time collegate all'applicazione del gestore.</p>
            <p>Consegna rapida a domicilio a Livorno e dintorni.</p>
          </div>
        </div>
        <div className={styles.copyright}>
          © 2026 Angels Livorno. Tutti i diritti riservati.
        </div>
      </footer>
    </div>
  );
}
