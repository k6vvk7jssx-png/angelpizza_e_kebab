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

  return (
    <div className={styles.container}>
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

      {/* Grid of Menu Cards */}
      <div className={styles.menuGrid}>
        {filteredItems.map(item => (
          <div key={item.id} className={styles.menuCard}>
            <div>
              <div className={styles.cardHeader}>
                <span className={styles.cardTitle}>{item.name}</span>
                <span className={styles.cardPrice}>€{Number(item.price).toFixed(2)}</span>
              </div>
              {item.description && (
                <p className={styles.cardDescription}>{item.description}</p>
              )}
            </div>
            
            <div className={styles.cardFooter}>
              <span className={styles.cardCode}>Cod: #{item.id}</span>
              <button
                onClick={() => onAddToCart(item)}
                className={styles.addButton}
              >
                ➕ Aggiungi
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
