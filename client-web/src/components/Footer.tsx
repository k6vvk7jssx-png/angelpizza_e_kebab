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
          <p>Pizzeria Artigianale, Kebab Fast Food &amp; Ristorante Etnico.</p>
          <p>Ingredienti freschi di prima scelta e cottura nel nostro forno.</p>

          <div style={{ marginTop: '1rem' }}>
            <a
              href={googleReviewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className={styles.googleReviewBtn}
              aria-label="Valuta il Locale su Google (apre in una nuova scheda)"
            >
              <span aria-hidden="true">⭐</span> Valuta il Locale su Google
            </a>
          </div>
        </div>

        <div className={styles.footerInfo}>
          <h3>Orari &amp; Contatti</h3>
          <p><span aria-hidden="true">📍</span> Piazza Mazzini 82/83 - Livorno (LI)</p>
          <p>
            <span aria-hidden="true">📞</span> Ordini Telefonici:{' '}
            <a href="tel:0586996524" className={styles.phoneLink}>
              0586 99 65 24
            </a>
          </p>
          <p><span aria-hidden="true">⏰</span> Aperto tutti i giorni dalle 12:00 alle 24:00</p>
        </div>
      </div>

      <div className={styles.copyright}>
        © 2026 Angels Livorno. Tutti i diritti riservati.
      </div>
    </footer>
  );
}
