'use client';

import React from 'react';
import Header from '../../components/Header';
import Footer from '../../components/Footer';
import styles from '../page.module.css';

export default function ContattiPage() {
  const googleReviewUrl = 'https://maps.google.com/?q=Angels+Pizzeria+Kebab+Piazza+Mazzini+Livorno';

  return (
    <div className={styles.pageContainer}>
      <Header />

      <main className={styles.mainLayout} style={{ marginTop: '2rem', display: 'block' }}>
        <div style={{ maxWidth: '800px', margin: '0 auto' }}>
          <h1 className={styles.heroTitle} style={{ color: '#0f172a', fontSize: '2.2rem', marginBottom: '0.5rem' }}>
            📍 Contatti & Dove Siamo
          </h1>
          <p className={styles.heroSubtitle} style={{ color: '#64748b', marginBottom: '2rem' }}>
            Vienici a trovare a Livorno o contattaci per ordinazioni e prenotazioni.
          </p>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: '1.5rem', marginBottom: '2rem' }}>
            <div className={styles.sidebarWidget}>
              <h2 className={styles.widgetTitle}>📍 Indirizzo Locale</h2>
              <p style={{ fontSize: '1rem', color: '#0f172a', fontWeight: '800', marginBottom: '4px' }}>
                Angels Livorno
              </p>
              <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '1rem' }}>
                Piazza Mazzini 82/83 - 57126 Livorno (LI)
              </p>
              <a
                href={googleReviewUrl}
                target="_blank"
                rel="noopener noreferrer"
                className={styles.googleReviewBtn}
                style={{ display: 'inline-block', textDecoration: 'none' }}
              >
                🗺️ Apri su Google Maps →
              </a>
            </div>

            <div className={styles.sidebarWidget}>
              <h2 className={styles.widgetTitle}>📞 Telefonaci</h2>
              <p style={{ color: '#64748b', fontSize: '0.9rem', marginBottom: '8px' }}>
                Ordini telefonici e informazioni:
              </p>
              <a
                href="tel:0586996524"
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  fontSize: '1.4rem',
                  fontWeight: '900',
                  color: '#ea580c',
                  textDecoration: 'none',
                  display: 'block',
                  marginBottom: '1rem',
                }}
              >
                📞 0586 99 65 24
              </a>
              <p style={{ color: '#64748b', fontSize: '0.85rem' }}>
                ⏰ Aperto tutti i giorni dalle 12:00 alle 24:00
              </p>
            </div>
          </div>

          {/* Google Review Section */}
          <div className={styles.sidebarWidget} style={{ textAlign: 'center', padding: '2.5rem 1.5rem', background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)', color: '#ffffff' }}>
            <span style={{ fontSize: '2.5rem', display: 'block', marginBottom: '0.5rem' }}>⭐ ⭐ ⭐ ⭐ ⭐</span>
            <h2 style={{ fontSize: '1.6rem', fontWeight: '900', marginBottom: '0.5rem', color: '#ffffff' }}>
              Ti è piaciuta la nostra pizza?
            </h2>
            <p style={{ color: '#94a3b8', fontSize: '0.95rem', maxWidth: '500px', margin: '0 auto 1.5rem' }}>
              La tua opinione è importante per noi! Lascia una recensione direttamente sulla nostra scheda Google per aiutarci a crescere.
            </p>
            <a
              href={googleReviewUrl}
              target="_blank"
              rel="noopener noreferrer"
              className={styles.googleReviewBtn}
              style={{ fontSize: '1rem', padding: '12px 24px', display: 'inline-block', textDecoration: 'none' }}
            >
              ⭐ Scrivi una Recensione su Google →
            </a>
          </div>
        </div>
      </main>

      <Footer googleReviewUrl={googleReviewUrl} />
    </div>
  );
}
