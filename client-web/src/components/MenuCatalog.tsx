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

const CATEGORIES = [
  { id: 'tutti', name: 'Tutto' },
  { id: 'pizze_rosse', name: 'Pizze Rosse' },
  { id: 'pizze_bianche', name: 'Pizze Bianche' },
  { id: 'schiacciatine', name: 'Schiacciatine' },
  { id: 'fastfood', name: 'Fast Food' },
  { id: 'specialita', name: 'Specialità' },
  { id: 'delizie', name: 'Sfiziosità' },
  { id: 'riso_naan', name: 'Riso e Naan' },
  { id: 'girarrosto', name: 'Girarrosto' },
  { id: 'bibite', name: 'Bibite' },
  { id: 'cocktails', name: 'Cocktails' },
];

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
    return <div className={styles.loading}>Caricamento del menu in corso...</div>;
  }

  if (error) {
    return <div className={styles.error}>Errore: {error}</div>;
  }

  // Filter items based on selected category id
  const filteredItems = selectedCategory === 'tutti'
    ? menuItems
    : menuItems.filter(item => item.category === selectedCategory);

  // Group items by category to render individual sections
  const categoriesToRender = selectedCategory === 'tutti'
    ? CATEGORIES.filter(c => c.id !== 'tutti')
    : CATEGORIES.filter(c => c.id === selectedCategory);

  return (
    <div className={styles.container}>
      <h2 className={styles.title}>Il Nostro Menu</h2>

      {/* Category Navigation Tabs */}
      <div className={styles.categoriesContainer}>
        {CATEGORIES.map(category => (
          <button
            key={category.id}
            onClick={() => setSelectedCategory(category.id)}
            className={`${styles.categoryButton} ${
              selectedCategory === category.id ? styles.activeCategoryButton : ''
            }`}
          >
            {category.name}
          </button>
        ))}
      </div>

      {/* List of items grouped by category with traditional dotted dividers */}
      <div className={styles.menuList}>
        {categoriesToRender.map(category => {
          const categoryItems = filteredItems.filter(item => item.category === category.id);
          if (categoryItems.length === 0) return null;

          return (
            <div key={category.id} className={styles.categorySection}>
              <h3 className={styles.categoryHeader}>{category.name}</h3>
              
              {categoryItems.map(item => (
                <div key={item.id} className={styles.itemRowContainer}>
                  <div className={styles.itemHeaderLine}>
                    <span className={styles.itemName}>{item.name}</span>
                    <span className={styles.dottedDivider}></span>
                    <span className={styles.itemPrice}>€{Number(item.price).toFixed(2)}</span>
                  </div>
                  
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                    {item.description && (
                      <p className={styles.itemDescription}>{item.description}</p>
                    )}
                    <div className={styles.itemFooterAction}>
                      <button
                        onClick={() => onAddToCart(item)}
                        className={styles.addButton}
                      >
                        Aggiungi
                      </button>
                    </div>
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
