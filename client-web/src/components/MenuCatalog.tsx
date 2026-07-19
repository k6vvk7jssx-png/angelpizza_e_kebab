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
  image_url?: string;
  is_available: boolean;
}

interface MenuCatalogProps {
  onAddToCart: (item: MenuItem) => void;
}

const CATEGORIES = ['tutti', 'panini', 'fritti', 'bevande', 'dolci'];

export default function MenuCatalog({ onAddToCart }: MenuCatalogProps) {
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
          .eq('is_available', true);

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

  if (loading) {
    return <div className={styles.loading}>Caricamento del menu...</div>;
  }

  if (error) {
    return <div className={styles.error}>Errore: {error}</div>;
  }

  // Filter items based on selected category
  const filteredItems = selectedCategory === 'tutti'
    ? menuItems
    : menuItems.filter(item => item.category === selectedCategory);

  // Group items by category for rendering sections
  const categoriesToRender = selectedCategory === 'tutti'
    ? CATEGORIES.filter(c => c !== 'tutti')
    : [selectedCategory];

  const capitalize = (str: string) => str.charAt(0).toUpperCase() + str.slice(1);

  return (
    <div className={styles.container}>
      <h2 className={styles.title}>Il Nostro Menu</h2>

      {/* Category Navigation Tabs */}
      <div className={styles.categoriesContainer}>
        {CATEGORIES.map(category => (
          <button
            key={category}
            onClick={() => setSelectedCategory(category)}
            className={`${styles.categoryButton} ${
              selectedCategory === category ? styles.activeCategoryButton : ''
            }`}
          >
            {capitalize(category)}
          </button>
        ))}
      </div>

      {/* Grid of items grouped by category */}
      <div className={styles.menuGrid}>
        {categoriesToRender.map(category => {
          const categoryItems = filteredItems.filter(item => item.category === category);
          if (categoryItems.length === 0) return null;

          return (
            <div key={category} className={styles.categorySection}>
              <h3 className={styles.categoryHeader}>{capitalize(category)}</h3>
              {categoryItems.map(item => (
                <div key={item.id} className={styles.itemCard}>
                  <div>
                    <div className={styles.itemHeader}>
                      <span className={styles.itemName}>{item.name}</span>
                      <span className={styles.itemPrice}>€{Number(item.price).toFixed(2)}</span>
                    </div>
                    {item.description && (
                      <p className={styles.itemDescription}>{item.description}</p>
                    )}
                  </div>
                  <div className={styles.itemFooter}>
                    <button
                      onClick={() => onAddToCart(item)}
                      className={styles.addButton}
                    >
                      Aggiungi
                    </button>
                  </div>
                </div>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );
}
