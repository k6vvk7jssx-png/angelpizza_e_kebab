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
  
  // Form states
  const [guestName, setGuestName] = useState('');
  const [guestPhone, setGuestPhone] = useState('');
  const [guestAddress, setGuestAddress] = useState('');
  const [deliveryType, setDeliveryType] = useState('delivery');
  const [notes, setNotes] = useState('');
  
  // Order tracking states
  const [placedOrderId, setPlacedOrderId] = useState<string | null>(null);
  const [orderStatus, setOrderStatus] = useState<string>('pending');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Cart operations
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

  const cartTotal = cart.reduce((acc, item) => acc + item.price * item.quantity, 0);

  // Realtime subscription to the order status
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

  // Handle Checkout submission
  const handleCheckoutSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!guestName || !guestPhone) {
      alert('Inserisci nome e numero di telefono!');
      return;
    }
    if (deliveryType === 'delivery' && !guestAddress) {
      alert('Inserisci l\'indirizzo di consegna!');
      return;
    }

    try {
      setIsSubmitting(true);

      // 1. Create order row
      const { data: orderData, error: orderError } = await supabase
        .from('orders')
        .insert({
          guest_name: guestName,
          guest_phone: guestPhone,
          guest_address: deliveryType === 'delivery' ? guestAddress : null,
          delivery_type: deliveryType,
          total_price: cartTotal,
          status: 'pending',
          requested_time: new Date(Date.now() + 30 * 60000).toISOString(), // 30 minutes from now
          notes: notes,
        })
        .select()
        .single();

      if (orderError) throw orderError;

      // 2. Create order items
      const orderItemsToInsert = cart.map((item) => ({
        order_id: orderData.id,
        menu_item_id: item.id,
        quantity: item.quantity,
        unit_price: item.price,
      }));

      const { error: itemsError } = await supabase
        .from('order_items')
        .insert(orderItemsToInsert);

      if (itemsError) throw itemsError;

      // Success!
      setPlacedOrderId(orderData.id);
      setOrderStatus('pending');
      setCart([]);
      setIsCheckingOut(false);
    } catch (err: any) {
      console.error('Error submitting order:', err);
      alert(`Errore nell'invio dell'ordine: ${err.message || err}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  // If order is placed, show tracker page
  if (placedOrderId) {
    return (
      <div className={styles.trackerContainer}>
        <h2 className={styles.trackerTitle}>Grazie per il tuo ordine!</h2>
        <p>Il tuo ordine è stato ricevuto ed è in fase di elaborazione.</p>
        
        <div className={`${styles.trackerStatus} ${styles[`status-${orderStatus}`]}`}>
          Stato: {orderStatus === 'pending' && 'In Attesa di Conferma'}
          {orderStatus === 'accepted' && 'In Preparazione'}
          {orderStatus === 'delivering' && 'In Consegna (Fattorino partito)'}
          {orderStatus === 'completed' && 'Consegnato! Buon Appetito!'}
          {orderStatus === 'cancelled' && 'Annullato'}
        </div>

        <p className={styles.trackerTime}>
          Tempo di consegna stimato: 30 minuti. Rimani su questa pagina per tracciare lo stato in tempo reale.
        </p>

        <button
          onClick={() => setPlacedOrderId(null)}
          className={styles.orderButton}
          style={{ width: 'auto', padding: '0.8rem 2rem' }}
        >
          Fai un nuovo ordine
        </button>
      </div>
    );
  }

  return (
    <div className={styles.container}>
      {/* Header with Clerk integration placeholder */}
      <header className={styles.header}>
        <div className={styles.logoContainer}>
          <span className={styles.logoText}>ANGELS LIVORNO</span>
        </div>
        
        {/* Clerk Sign In future integration wrapper */}
        <div className={styles.authBadgePlaceholder}>
          <span style={{ fontSize: '1.1rem' }}>👤</span>
          <span>Accedi (Clerk in arrivo)</span>
          <span style={{ fontSize: '0.7rem', color: '#3b82f6', fontWeight: 'bold' }}>FUTURE AUTH</span>
        </div>
      </header>

      <main className={styles.mainLayout}>
        {/* Menu Catalog Section */}
        <div className={styles.menuColumn}>
          <MenuCatalog onAddToCart={handleAddToCart} />
        </div>

        {/* Sidebar Cart or Checkout Section */}
        <div>
          {!isCheckingOut ? (
            <div className={styles.cartCard}>
              <h3 className={styles.cartTitle}>Carrello</h3>
              {cart.length === 0 ? (
                <p className={styles.cartEmpty}>Il tuo carrello è vuoto. Aggiungi dei piatti dal menu!</p>
              ) : (
                <>
                  <ul className={styles.cartList}>
                    {cart.map((item) => (
                      <li key={item.id} className={styles.cartItem}>
                        <div className={styles.cartItemInfo}>
                          <span className={styles.cartItemName}>{item.name}</span>
                          <span className={styles.cartItemQty}>Quantità: {item.quantity}</span>
                        </div>
                        <span className={styles.cartItemPrice}>
                          €{(item.price * item.quantity).toFixed(2)}
                        </span>
                      </li>
                    ))}
                  </ul>
                  
                  <div className={styles.cartTotal}>
                    <span>Totale:</span>
                    <span>€{cartTotal.toFixed(2)}</span>
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
            <div className={styles.checkoutOverlay}>
              <h3 className={styles.formTitle}>Completa Ordine</h3>
              
              <form onSubmit={handleCheckoutSubmit}>
                <div className={styles.formGroup}>
                  <label className={styles.formLabel}>Nome e Cognome *</label>
                  <input
                    type="text"
                    required
                    value={guestName}
                    onChange={(e) => setGuestName(e.target.value)}
                    placeholder="Es: Mario Rossi"
                    className={styles.formInput}
                  />
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.formLabel}>Numero di Telefono *</label>
                  <input
                    type="tel"
                    required
                    value={guestPhone}
                    onChange={(e) => setGuestPhone(e.target.value)}
                    placeholder="Es: 3331234567"
                    className={styles.formInput}
                  />
                </div>

                <div className={styles.formGroup}>
                  <label className={styles.formLabel}>Metodo di Ricezione *</label>
                  <div className={styles.rowInputs}>
                    <button
                      type="button"
                      onClick={() => setDeliveryType('delivery')}
                      style={{
                        padding: '0.75rem',
                        borderRadius: '6px',
                        border: deliveryType === 'delivery' ? '2px solid #ea580c' : '1px solid #d6d3d1',
                        backgroundColor: deliveryType === 'delivery' ? '#fff7ed' : '#ffffff',
                        fontWeight: 'bold',
                        cursor: 'pointer'
                      }}
                    >
                      Consegna a domicilio
                    </button>
                    <button
                      type="button"
                      onClick={() => setDeliveryType('pickup')}
                      style={{
                        padding: '0.75rem',
                        borderRadius: '6px',
                        border: deliveryType === 'pickup' ? '2px solid #ea580c' : '1px solid #d6d3d1',
                        backgroundColor: deliveryType === 'pickup' ? '#fff7ed' : '#ffffff',
                        fontWeight: 'bold',
                        cursor: 'pointer'
                      }}
                    >
                      Asporto
                    </button>
                  </div>
                </div>

                {deliveryType === 'delivery' && (
                  <div className={styles.formGroup}>
                    <label className={styles.formLabel}>Indirizzo di Consegna *</label>
                    <input
                      type="text"
                      required
                      value={guestAddress}
                      onChange={(e) => setGuestAddress(e.target.value)}
                      placeholder="Es: Via Roma 10, Livorno"
                      className={styles.formInput}
                    />
                  </div>
                )}

                <div className={styles.formGroup}>
                  <label className={styles.formLabel}>Note per la cucina / campanello</label>
                  <textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="Es: Senza cipolla nel kebab, citofono Rossi..."
                    className={styles.formInput}
                    rows={3}
                  />
                </div>

                {/* Stripe Future Integration Checkbox styling */}
                <div className={styles.formGroup}>
                  <label className={styles.formLabel}>Metodo di Pagamento</label>
                  <div className={styles.paymentOption}>
                    <input type="radio" checked readOnly />
                    <span>Pagamento in contanti alla consegna</span>
                  </div>
                  <div className={`${styles.paymentOption} ${styles.paymentDisabled}`}>
                    <input type="radio" disabled />
                    <span>Paga online con Carta (Stripe in arrivo)</span>
                    <span className={styles.badgeStripePlaceholder}>FUTURE CARD</span>
                  </div>
                </div>

                <div className={styles.formButtons}>
                  <button
                    type="submit"
                    disabled={isSubmitting}
                    className={styles.submitBtn}
                  >
                    {isSubmitting ? 'Invio in corso...' : `Ordina ora (€${cartTotal.toFixed(2)})`}
                  </button>
                  <button
                    type="button"
                    onClick={() => setIsCheckingOut(false)}
                    className={styles.cancelBtn}
                  >
                    Annulla
                  </button>
                </div>
              </form>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
