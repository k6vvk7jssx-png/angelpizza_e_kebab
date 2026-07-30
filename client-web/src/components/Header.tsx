'use client';

import React from 'react';
import Link from 'next/link';
import styles from '../app/page.module.css';

interface HeaderProps {
  cartItemCount?: number;
  onOpenCart?: () => void;
}

export default function Header({ cartItemCount = 0, onOpenCart }: HeaderProps) {
  return (
    <header className={styles.header}>
      <div className={styles.headerContainer}>
        <Link href="/" className={styles.logoContainer}>
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
        </Link>

        <nav className={styles.nav}>
          <Link href="/menu" className={styles.navLink}>
            Il Menu
          </Link>
          <Link href="/notizie" className={styles.navLink}>
            Notizie & Novità
          </Link>
          <Link href="/contatti" className={styles.navLink}>
            Contatti
          </Link>
        </nav>

        {onOpenCart && (
          <button
            className={styles.headerCartBtn}
            onClick={onOpenCart}
          >
            🛒
            <span className={styles.headerCartText}>Carrello</span>
            {cartItemCount > 0 && (
              <span className={styles.headerCartBadge}>{cartItemCount}</span>
            )}
          </button>
        )}
      </div>
    </header>
  );
}
