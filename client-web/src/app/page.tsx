'use client';

import React, { useState, useEffect } from 'react';
import MenuCatalog, { MenuItem } from '../components/MenuCatalog';
import Header from '../components/Header';
import Footer from '../components/Footer';
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

  // Google Review URL
  const googleReviewUrl = 'https://maps.google.com/?q=Angels+Pizzeria+Kebab+Piazza+Mazzini+Livorno';

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

  // If order is placed, render tracking panel
  if (placedOrderId) {
    return (
      <div className={styles.pageContainer}>
        <Header />

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
      <Header
        cartItemCount={cartItemCount}
        onOpenCart={() => setIsCartOpen(true)}
      />

      {/* MODERN RESTAURANT HERO BANNER */}
      <section className={styles.heroSection}>
        <div className={styles.heroBannerCard}>
          <div className={styles.heroBadgesRow}>
            <span className={styles.heroBadgeHighlight}>⏰ Aperto • 12:00 - 24:00</span>
            <span className={styles.heroBadgeSecondary}>🛵 Consegna Gratuita</span>
            {/* DIRECT GOOGLE REVIEW BUTTON */}
            <a
              href={googleReviewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className={styles.googleReviewBtn}
            >
              ⭐ Valuta su Google
            </a>
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
                <a href="tel:0586996524" target="_blank" rel="noopener noreferrer">
                  0586 99 65 24
                </a>
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

          {/* GOOGLE REVIEW SIDEBAR CARD */}
          <div className={styles.sidebarWidget} style={{ textAlign: 'center', background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)', color: '#ffffff' }}>
            <span style={{ fontSize: '1.8rem', display: 'block', marginBottom: '0.25rem' }}>⭐ ⭐ ⭐ ⭐ ⭐</span>
            <h3 style={{ fontSize: '1rem', fontWeight: '800', margin: '0 0 0.5rem', color: '#ffffff' }}>
              Valuta Angels Livorno
            </h3>
            <p style={{ fontSize: '0.8rem', color: '#94a3b8', margin: '0 0 1rem' }}>
              Lascia una recensione su Google per farci sapere cosa ne pensi!
            </p>
            <a
              href={googleReviewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className={styles.googleReviewBtn}
            >
              ⭐ Scrivi una Recensione →
            </a>
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

      {/* FLOATING BOTTOM BAR FOR MOBILE */}
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

      <Footer googleReviewUrl={googleReviewUrl} />
    </div>
  );
}
