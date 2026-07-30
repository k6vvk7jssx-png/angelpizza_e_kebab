'use client';

import React from 'react';
import styles from '../app/page.module.css';

interface FooterProps {
  googleReviewUrl?: string;
}

export default function Footer({
  googleReviewUrl = 'https://maps.google.com/?q=Angels+Pizzeria+Kebab+Piazza+Mazzini+Livorno',
}: FooterProps) {
  return (
    <footer id="footer-section" className={styles.footer}>
      <div className={styles.footerContainer}>
        <div className={styles.footerInfo}>
          <h3>Angels Livorno</h3>
          <p>Pizzeria Artigianale, Kebab Fast Food & Ristorante Etnico.</p>
          <p>Ingredienti freschi di prima scelta e cottura nel nostro forno.</p>

          <div style={{ marginTop: '1rem' }}>
            <a
              href={googleReviewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className={styles.googleReviewBtn}
            >
              ⭐ Valuta il Locale su Google
            </a>
          </div>
        </div>

        <div className={styles.footerInfo}>
          <h3>Orari & Consegne</h3>
          <p>📍 Piazza Mazzini 82/83 - Livorno</p>
          <p>
            📞 Telefonaci:{' '}
            <a href="tel:0586996524" target="_blank" rel="noopener noreferrer">
              0586 99 65 24
            </a>
          </p>
          <p>⏰ Aperto tutti i giorni dalle 12:00 alle 24:00</p>
        </div>

        <div className={styles.footerInfo}>
          <h3>Ordina Online</h3>
          <p>Ordinazioni real-time collegate all'applicazione del gestore.</p>
          <p>Consegna rapida a domicilio a Livorno e dintorni.</p>
          <p>
            💬 Telegram:{' '}
            <a
              href="https://t.me"
              target="_blank"
              rel="noopener noreferrer"
            >
              Canale Ordini Telegram
            </a>
          </p>
        </div>
      </div>

      <div className={styles.copyright}>
        © 2026 Angels Livorno. Tutti i diritti riservati.
      </div>
    </footer>
  );
}
