'use client';

import React, { useState, useEffect } from 'react';
import MenuCatalog, { MenuItem } from '../../components/MenuCatalog';
import Header from '../../components/Header';
import Footer from '../../components/Footer';
import { supabase } from '../../lib/supabaseClient';
import styles from '../page.module.css';

interface CartItem extends MenuItem {
  quantity: number;
}

export default function MenuPage() {
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

  // OTP simulation details
  const [otpPhone, setOtpPhone] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState('');

  // Order state
  const [placedOrderId, setPlacedOrderId] = useState<string | null>(null);
  const [orderStatus, setOrderStatus] = useState<string>('pending');
  const [isSubmitting, setIsSubmitting] = useState(false);

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

  const handleAddToCart = (item: MenuItem) => {
    setCart((prev) => {
      const found = prev.find((i) => i.id === item.id);
      if (found) {
        return prev.map((i) =>
          i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i
        );
      }
      return [...prev, { ...item, quantity: 1 }];
    });
  };

  const handleIncreaseQty = (id: string) => {
    setCart((prev) =>
      prev.map((i) => (i.id === id ? { ...i, quantity: i.quantity + 1 } : i))
    );
  };

  const handleDecreaseQty = (id: string) => {
    setCart((prev) =>
      prev
        .map((i) => (i.id === id ? { ...i, quantity: i.quantity - 1 } : i))
        .filter((i) => i.quantity > 0)
    );
  };

  const cartTotal = cart.reduce((acc, i) => acc + i.price * i.quantity, 0);
  const cartItemCount = cart.reduce((acc, i) => acc + i.quantity, 0);

  // Real-time tracking subscription
  useEffect(() => {
    if (!placedOrderId) return;

    const channel = supabase
      .channel(`order-tracker-menu-${placedOrderId}`)
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
        items: cart.map((i) => ({
          menu_item_id: i.id,
          name: i.name,
          qty: i.quantity,
          price_at_order: i.price,
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

      fetch('/api/telegram-notify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          order_id: orderData.id,
          guest_name: customerName,
          guest_phone: customerPhone,
          delivery_address: deliveryAddress,
          items: cart.map((i) => ({ name: i.name, qty: i.quantity, price_at_order: i.price })),
          total_amount: cartTotal,
          requested_time: requestedTimeIso.toISOString(),
        }),
      }).catch(console.error);

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
      alert(`Errore nell'invio dell'ordine: ${err.message || err}`);
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
              <div className={styles.tabToggleGroup} role="tablist" aria-label="Modalità checkout">
                <button
                  type="button"
                  role="tab"
                  aria-selected={checkoutMode === 'guest'}
                  onClick={() => setCheckoutMode('guest')}
                  className={`${styles.deliveryTab} ${checkoutMode === 'guest' ? styles.deliveryTabActive : ''}`}
                >
                  ⚡ Ordine Rapido
                </button>
                <button
                  type="button"
                  role="tab"
                  aria-selected={checkoutMode === 'login'}
                  onClick={() => setCheckoutMode('login')}
                  className={`${styles.deliveryTab} ${checkoutMode === 'login' ? styles.deliveryTabActive : ''}`}
                >
                  📲 Accedi / OTP
                </button>
              </div>

              {checkoutMode === 'guest' ? (
                <>
                  <div className={styles.formGroup}>
                    <label htmlFor="guest-name-input" className={styles.formLabel}>Nome Completo *</label>
                    <input
                      id="guest-name-input"
                      name="name"
                      type="text"
                      required
                      autoComplete="name"
                      value={guestName}
                      onChange={(e) => setGuestName(e.target.value)}
                      placeholder="Es. Mario Rossi"
                      className={styles.formInput}
                    />
                  </div>

                  <div className={styles.formGroup}>
                    <label htmlFor="guest-phone-input" className={styles.formLabel}>Telefono (per la consegna) *</label>
                    <input
                      id="guest-phone-input"
                      name="phone"
                      type="tel"
                      required
                      autoComplete="tel"
                      value={guestPhone}
                      onChange={(e) => setGuestPhone(e.target.value)}
                      placeholder="Es. 333 1234567"
                      className={styles.formInput}
                    />
                  </div>

                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Modalità di Ricezione</label>
                    <div className={styles.tabToggleGroup} role="tablist" aria-label="Modalità di ricezione">
                      <button
                        type="button"
                        role="tab"
                        aria-selected={deliveryType === 'delivery'}
                        onClick={() => setDeliveryType('delivery')}
                        className={`${styles.deliveryTab} ${deliveryType === 'delivery' ? styles.deliveryTabActive : ''}`}
                      >
                        🛵 Domicilio
                      </button>
                      <button
                        type="button"
                        role="tab"
                        aria-selected={deliveryType === 'pickup'}
                        onClick={() => setDeliveryType('pickup')}
                        className={`${styles.deliveryTab} ${deliveryType === 'pickup' ? styles.deliveryTabActive : ''}`}
                      >
                        🛍️ Asporto
                      </button>
                    </div>
                  </div>

                  {deliveryType === 'delivery' && (
                    <div className={styles.formGroup}>
                      <label htmlFor="guest-address-input" className={styles.formLabel}>Indirizzo di Consegna (Livorno) *</label>
                      <input
                        id="guest-address-input"
                        name="address"
                        type="text"
                        required
                        autoComplete="street-address"
                        value={guestAddress}
                        onChange={(e) => setGuestAddress(e.target.value)}
                        placeholder="Es. Via Grande 45, Piano 2"
                        className={styles.formInput}
                      />
                    </div>
                  )}

                  <div className={styles.formGroup}>
                    <label htmlFor="selected-time-select" className={styles.formLabel}>Orario desiderato</label>
                    <select
                      id="selected-time-select"
                      name="selectedTime"
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
                    <label htmlFor="otp-phone-input" className={styles.formLabel}>Numero di Telefono *</label>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <input
                        id="otp-phone-input"
                        name="phone"
                        type="tel"
                        autoComplete="tel"
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
                      <label htmlFor="otp-code-input" className={styles.formLabel}>Codice OTP Ricevuto *</label>
                      <input
                        id="otp-code-input"
                        name="otpCode"
                        type="text"
                        inputMode="numeric"
                        spellCheck={false}
                        autoComplete="one-time-code"
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
                  <button
                    type="button"
                    onClick={() => setPaymentMethod('cod')}
                    className={`${styles.paymentOption} ${paymentMethod === 'cod' ? styles.paymentOptionActive : ''}`}
                  >
                    💵 Contanti alla Consegna
                  </button>
                </div>
              </div>

              <div className={styles.formButtons}>
                <button
                  type="submit"
                  disabled={isSubmitting}
                  className={styles.submitBtn}
                >
                  {isSubmitting ? 'Invio in corso…' : `Conferma Ordine (€${cartTotal.toFixed(2)})`}
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

      <main className={styles.mainLayout} style={{ marginTop: '1rem' }}>
        <div className={styles.menuColumn}>
          <div style={{ marginBottom: '1rem' }}>
            <h1 className={styles.heroTitle} style={{ color: '#0f172a', fontSize: '2rem' }}>
              Menu Completo Pizzeria &amp; Kebab
            </h1>
            <p className={styles.heroSubtitle} style={{ color: '#64748b' }}>
              Seleziona i piatti desiderati per aggiungere al carrello ed ordinare a domicilio o per asporto.
            </p>
          </div>

          <MenuCatalog
            onAddToCart={handleAddToCart}
            cart={cart}
            onIncreaseQty={handleIncreaseQty}
            onDecreaseQty={handleDecreaseQty}
          />
        </div>

        {/* Sidebar on Desktop */}
        <div id="cart-sidebar-section" className={styles.sidebar}>
          {renderCartAndCheckout()}
        </div>
      </main>

      {/* Floating Bottom Bar for Mobile */}
      {cartItemCount > 0 && !isCartOpen && (
        <button
          type="button"
          className={styles.floatingBottomBar}
          onClick={() => setIsCartOpen(true)}
          aria-label={`Vedi ordine (${cartItemCount} articoli, totale €${cartTotal.toFixed(2)})`}
        >
          <div className={styles.bottomBarLeft}>
            <span className={styles.bottomBarBadge}>{cartItemCount}</span>
            <span className={styles.bottomBarText}>Vedi Ordine</span>
          </div>
          <div className={styles.bottomBarRight}>
            <span>€{cartTotal.toFixed(2)}</span>
            <span className={styles.bottomBarArrow} aria-hidden="true">→</span>
          </div>
        </button>
      )}

      {/* Mobile Cart Overlay */}
      {isCartOpen && (
        <div className={styles.mobileCartOverlay} onClick={() => setIsCartOpen(false)}>
          <div className={styles.mobileCartDrawer} onClick={(e) => e.stopPropagation()} role="dialog" aria-modal="true" aria-label="Carrello e checkout">
            <div className={styles.drawerHeader}>
              <div className={styles.drawerHeaderTitle}>
                <span>🛒 Il Tuo Carrello</span>
                <span className={styles.drawerHeaderBadge}>{cartItemCount} articoli</span>
              </div>
              <button
                type="button"
                onClick={() => setIsCartOpen(false)}
                className={styles.closeDrawerBtn}
                aria-label="Chiudi carrello"
              >
                ✕
              </button>
            </div>
            <div className={styles.drawerBody}>
              {renderCartAndCheckout()}
            </div>
          </div>
        </div>
      )}

      <Footer />
    </div>
  );
}
