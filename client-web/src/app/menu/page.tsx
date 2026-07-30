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
  const [guestName, setGuestName] = useState('');
  const [guestPhone, setGuestPhone] = useState('');
  const [guestAddress, setGuestAddress] = useState('');
  const [deliveryType, setDeliveryType] = useState<'delivery' | 'pickup'>('delivery');
  const [selectedTime, setSelectedTime] = useState('asap');
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

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

  const handleCheckoutSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!guestName || !guestPhone) {
      alert('Inserisci Nome e Telefono!');
      return;
    }

    try {
      setIsSubmitting(true);
      let requestedTimeIso = new Date();
      if (selectedTime === 'asap') {
        requestedTimeIso = new Date(requestedTimeIso.getTime() + 30 * 60 * 1000);
      }

      const orderPayload = {
        guest_name: guestName,
        guest_phone: guestPhone,
        delivery_address: deliveryType === 'delivery' ? guestAddress : 'Asporto',
        items: cart.map((i) => ({
          menu_item_id: i.id,
          name: i.name,
          qty: i.quantity,
          price_at_order: i.price,
        })),
        total_amount: cartTotal,
        payment_method: 'cod',
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
          guest_name: guestName,
          guest_phone: guestPhone,
          delivery_address: deliveryType === 'delivery' ? guestAddress : 'Asporto',
          items: cart.map((i) => ({ name: i.name, qty: i.quantity, price_at_order: i.price })),
          total_amount: cartTotal,
          requested_time: requestedTimeIso.toISOString(),
        }),
      }).catch(console.error);

      alert('Ordine inviato con successo! Il ristorante ha preso in carico la richiesta.');
      setCart([]);
      setIsCheckingOut(false);
      setIsCartOpen(false);
    } catch (err: any) {
      alert(`Errore: ${err.message || err}`);
    } finally {
      setIsSubmitting(false);
    }
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
              Menu Completo Pizzeria & Kebab
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
      </main>

      {/* Floating Bottom Bar for Mobile */}
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

      {/* Mobile Cart Overlay */}
      {isCartOpen && (
        <div className={styles.mobileCartOverlay} onClick={() => setIsCartOpen(false)}>
          <div className={styles.mobileCartDrawer} onClick={(e) => e.stopPropagation()}>
            <div className={styles.drawerHeader}>
              <div className={styles.drawerHeaderTitle}>
                <span>🛒 Il Tuo Carrello</span>
                <span className={styles.drawerHeaderBadge}>{cartItemCount} articoli</span>
              </div>
              <button onClick={() => setIsCartOpen(false)} className={styles.closeDrawerBtn}>
                ✕
              </button>
            </div>
            <div className={styles.drawerBody}>
              {!isCheckingOut ? (
                <div>
                  <ul className={styles.cartList}>
                    {cart.map((item) => (
                      <li key={item.id} className={styles.cartItem}>
                        <div>
                          <div className={styles.cartItemName}>{item.name}</div>
                          <div className={styles.cartItemUnitPrice}>€{item.price.toFixed(2)}</div>
                        </div>
                        <div className={styles.cartItemRight}>
                          <div className={styles.cartQtyControls}>
                            <button onClick={() => handleDecreaseQty(item.id)} className={styles.qtyBtn}>−</button>
                            <span className={styles.cartQtyNum}>{item.quantity}</span>
                            <button onClick={() => handleIncreaseQty(item.id)} className={styles.qtyBtn}>+</button>
                          </div>
                          <span className={styles.cartItemSubtotal}>€{(item.price * item.quantity).toFixed(2)}</span>
                        </div>
                      </li>
                    ))}
                  </ul>
                  <div className={styles.cartSummary}>
                    <div className={styles.cartTotal}>
                      <span>Totale</span>
                      <span>€{cartTotal.toFixed(2)}</span>
                    </div>
                  </div>
                  <button onClick={() => setIsCheckingOut(true)} className={styles.orderButton}>
                    Procedi all'Ordine →
                  </button>
                </div>
              ) : (
                <form onSubmit={handleCheckoutSubmit}>
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
                    <label className={styles.formLabel}>Telefono *</label>
                    <input
                      type="tel"
                      required
                      value={guestPhone}
                      onChange={(e) => setGuestPhone(e.target.value)}
                      placeholder="333 1234567"
                      className={styles.formInput}
                    />
                  </div>
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Indirizzo di Consegna</label>
                    <input
                      type="text"
                      value={guestAddress}
                      onChange={(e) => setGuestAddress(e.target.value)}
                      placeholder="Via Grande 45, Livorno"
                      className={styles.formInput}
                    />
                  </div>
                  <button type="submit" disabled={isSubmitting} className={styles.submitBtn}>
                    {isSubmitting ? 'Invio...' : `Conferma (€${cartTotal.toFixed(2)})`}
                  </button>
                </form>
              )}
            </div>
          </div>
        </div>
      )}

      <Footer />
    </div>
  );
}
