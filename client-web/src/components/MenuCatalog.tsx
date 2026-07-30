'use client';

import React, { useEffect, useState } from 'react';
import { supabase } from '../lib/supabaseClient';
import styles from './MenuCatalog.module.css';

export interface MenuItem {
  id: string;
  name: string;
  description: string;
  price: number;
  category: string;
  image_path?: string;
  is_available: boolean;
}

interface MenuCatalogProps {
  onAddToCart: (item: MenuItem) => void;
  cart?: Array<{ id: string; quantity: number }>;
  onIncreaseQty?: (id: string) => void;
  onDecreaseQty?: (id: string) => void;
}

const CATEGORIES = [
  { id: 'tutti', name: 'Tutto', icon: '✨' },
  { id: 'pizze_rosse', name: 'Pizze Rosse', icon: '🍕' },
  { id: 'pizze_bianche', name: 'Pizze Bianche', icon: '🧀' },
  { id: 'schiacciatine', name: 'Schiacciatine', icon: '🥖' },
  { id: 'fastfood', name: 'Fast Food / Kebab', icon: '🍔' },
  { id: 'specialita', name: 'Specialità', icon: '⭐' },
  { id: 'delizie', name: 'Sfiziosità', icon: '🍟' },
  { id: 'riso_naan', name: 'Riso e Naan', icon: '🍚' },
  { id: 'girarrosto', name: 'Girarrosto', icon: '🍗' },
  { id: 'bibite', name: 'Bibite', icon: '🥤' },
  { id: 'cocktails', name: 'Cocktails', icon: '🍹' },
];

export default function MenuCatalog({
  onAddToCart,
  cart = [],
  onIncreaseQty,
  onDecreaseQty,
}: MenuCatalogProps) {
  const [menuItems, setMenuItems] = useState<MenuItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [selectedCategory, setSelectedCategory] = useState('tutti');

  useEffect(() => {
    async function fetchMenu() {
      try {
        setLoading(true);
        const { data, error: fetchError } = await supabase
          .from('menu_items')
          .select('*')
          .eq('is_available', true)
          .order('id', { ascending: true });

        if (fetchError) {
          throw fetchError;
        }

        setMenuItems(data || []);
      } catch (err: any) {
        console.error('Error fetching menu items:', err);
        setError(err.message || 'Errore nel caricamento del menu');
      } finally {
        setLoading(false);
      }
    }

    fetchMenu();
  }, []);

  const getItemQuantity = (id: string) => {
    const found = cart.find((item) => item.id === id);
    return found ? found.quantity : 0;
  };

  if (loading) {
    return (
      <div className={styles.loadingContainer}>
        <div className={styles.loadingSpinner}></div>
        <p>Caricamento delle pietanze golose...</p>
      </div>
    );
  }

  if (error) {
    return <div className={styles.error}>Errore: {error}</div>;
  }

  // Filter items based on selected category id
  const filteredItems =
    selectedCategory === 'tutti'
      ? menuItems
      : menuItems.filter((item) => item.category === selectedCategory);

  const renderCard = (item: MenuItem, isHorizontalCarousel = false) => {
    const qty = getItemQuantity(item.id);

    return (
      <div
        key={item.id}
        className={`${styles.menuCard} ${
          isHorizontalCarousel ? styles.carouselCard : ''
        }`}
      >
        <div className={styles.cardContentLeft}>
          <div className={styles.cardHeaderInfo}>
            <span className={styles.cardCode}>#{item.id}</span>
            <h3 className={styles.cardTitle}>{item.name}</h3>
          </div>

          {item.description && (
            <p className={styles.cardDescription}>{item.description}</p>
          )}

          <div className={styles.cardPriceRow}>
            <span className={styles.cardPrice}>
              €{Number(item.price).toFixed(2)}
            </span>
          </div>
        </div>

        <div className={styles.cardMediaRight}>
          {item.image_path ? (
            <img
              src={item.image_path}
              alt={item.name}
              className={styles.cardImage}
              loading="lazy"
            />
          ) : (
            <div className={styles.cardImagePlaceholder}>🍕</div>
          )}

          {/* Action button overlay or stepper */}
          <div className={styles.actionContainer}>
            {qty > 0 && onIncreaseQty && onDecreaseQty ? (
              <div className={styles.stepperPill}>
                <button
                  type="button"
                  onClick={() => onDecreaseQty(item.id)}
                  className={styles.stepperBtn}
                  aria-label="Riduci quantità"
                >
                  −
                </button>
                <span className={styles.stepperQty}>{qty}</span>
                <button
                  type="button"
                  onClick={() => onIncreaseQty(item.id)}
                  className={styles.stepperBtn}
                  aria-label="Aumenta quantità"
                >
                  +
                </button>
              </div>
            ) : (
              <button
                type="button"
                onClick={() => onAddToCart(item)}
                className={styles.addButton}
              >
                <span className={styles.addPlusIcon}>+</span> Aggiungi
              </button>
            )}
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className={styles.menuContainer}>
      {/* Category Navigation Tabs */}
      <div className={styles.categoriesStickyWrapper}>
        <div className={styles.categoriesContainer}>
          {CATEGORIES.map((category) => (
            <button
              key={category.id}
              onClick={() => setSelectedCategory(category.id)}
              className={`${styles.categoryButton} ${
                selectedCategory === category.id
                  ? styles.activeCategoryButton
                  : ''
              }`}
            >
              <span className={styles.categoryIcon}>{category.icon}</span>
              <span>{category.name}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Menu Content Area */}
      {selectedCategory === 'tutti' ? (
        <div className={styles.allCategoriesWrapper}>
          {CATEGORIES.filter((cat) => cat.id !== 'tutti').map((category) => {
            const itemsForCategory = menuItems.filter(
              (item) => item.category === category.id
            );
            if (itemsForCategory.length === 0) return null;

            return (
              <section key={category.id} className={styles.categorySection}>
                <div className={styles.categorySectionHeader}>
                  <h2 className={styles.categorySectionTitle}>
                    <span className={styles.categoryTitleIcon}>
                      {category.icon}
                    </span>
                    {category.name}
                  </h2>
                  <span className={styles.itemCountBadge}>
                    {itemsForCategory.length} prodotti
                  </span>
                </div>

                <div className={styles.categoryGrid}>
                  {itemsForCategory.map((item) => renderCard(item))}
                </div>
              </section>
            );
          })}
        </div>
      ) : (
        /* Specific Category Grid View */
        <div className={styles.categoryGrid}>
          {filteredItems.map((item) => renderCard(item))}
        </div>
      )}
    </div>
  );
}
