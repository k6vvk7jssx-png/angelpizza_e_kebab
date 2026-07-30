'use client';

import React from 'react';
import Header from '../../components/Header';
import Footer from '../../components/Footer';
import styles from '../page.module.css';

export default function NotiziePage() {
  return (
    <div className={styles.pageContainer}>
      <Header />

      <main className={styles.mainLayout} style={{ marginTop: '2rem', display: 'block' }}>
        <div style={{ maxWidth: '800px', margin: '0 auto' }}>
          <h1 className={styles.heroTitle} style={{ color: '#0f172a', fontSize: '2.2rem', marginBottom: '0.5rem' }}>
            📰 Notizie & Offerte Speciali
          </h1>
          <p className={styles.heroSubtitle} style={{ color: '#64748b', marginBottom: '2rem' }}>
            Rimani aggiornato sulle ultime novità, menù promozionali e sconti del ristorante Angels Livorno.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
            {/* Promo Card 1 */}
            <div className={styles.sidebarWidget}>
              <div className={styles.newsDate}>PROMOZIONE SPECIALE</div>
              <h2 className={styles.newsTitle} style={{ fontSize: '1.3rem', margin: '6px 0' }}>
                🍕 Menu Completo Speciale a soli € 12,00!
              </h2>
              <p className={styles.newsDesc} style={{ fontSize: '0.95rem' }}>
                Gusta una pizza a tua scelta, sfiziosità calda e bibita ad un prezzo promozionale unico. Ordina dal nostro sito per la consegna rapida a domicilio o per asporto.
              </p>
            </div>

            {/* Promo Card 2 */}
            <div className={styles.sidebarWidget}>
              <div className={styles.newsDate}>FAST FOOD & KEBAB</div>
              <h2 className={styles.newsTitle} style={{ fontSize: '1.3rem', margin: '6px 0' }}>
                🍔 Panino Kebab a soli € 5,00
              </h2>
              <p className={styles.newsDesc} style={{ fontSize: '0.95rem' }}>
                Carne selezionata di prima scelta, cotta sullo spiedo verticale e servita con insalata fresca, pomodoro e salse artigianali.
              </p>
            </div>

            {/* Promo Card 3 */}
            <div className={styles.sidebarWidget}>
              <div className={styles.newsDate}>TECNOLOGIA CLOUD</div>
              <h2 className={styles.newsTitle} style={{ fontSize: '1.3rem', margin: '6px 0' }}>
                🚀 Servizio Ordinazioni Online in Tempo Reale
              </h2>
              <p className={styles.newsDesc} style={{ fontSize: '0.95rem' }}>
                Grazie al nostro nuovo sito web ed al sistema di notifica Telegram, gli ordini inviati dal tuo cellulare arrivano direttamente sul tablet in cucina per una preparazione immediata!
              </p>
            </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
