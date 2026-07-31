import { NextResponse } from 'next/server';
import { supabase } from '../../../lib/supabaseClient';
import {
  geocodeLivornoAddress,
  calculateDistanceMeters,
  calculateBearing,
  generateGoogleMapsMultiStopUrl,
} from '../../../lib/geoUtils';

const ANGELS_LIVORNO_LOC = { lat: 43.5485, lng: 10.3106 };

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const {
      guest_name,
      guest_phone,
      delivery_address,
      items,
      total_amount,
      requested_time,
      order_id,
    } = body;

    const botToken =
      process.env.TELEGRAM_BOT_TOKEN ||
      process.env.NEXT_PUBLIC_TELEGRAM_BOT_TOKEN;
    const chatId =
      process.env.TELEGRAM_CHAT_ID ||
      process.env.NEXT_PUBLIC_TELEGRAM_CHAT_ID;

    if (!botToken || !chatId) {
      console.log('Telegram Bot Token or Chat ID not configured.');
      return NextResponse.json({
        success: false,
        message: 'Telegram credentials missing',
      });
    }

    const formattedTime = requested_time
      ? new Date(requested_time).toLocaleTimeString('it-IT', {
          hour: '2-digit',
          minute: '2-digit',
        })
      : 'Prima possibile';

    const shortId = order_id ? String(order_id).slice(0, 8).toUpperCase() : 'NEW';

    // 1. SMART DELIVERY BATCHING CHECK
    let isBatched = false;
    let pairedOrder: any = null;
    let distanceMeters = 0;
    let batchId = '';
    let mapsMultiStopUrl = '';

    if (delivery_address && delivery_address.trim().length > 3) {
      // Find candidate unassigned delivery orders in the same 15-min shift window
      const { data: activeOrders } = await supabase
        .from('orders')
        .select('*')
        .eq('status', 'pending')
        .neq('id', order_id || '')
        .order('created_at', { ascending: false });

      if (activeOrders && activeOrders.length > 0) {
        // Filter for UNBATCHED delivery orders with address
        const candidateDeliveryOrders = activeOrders.filter(
          (o) =>
            o.delivery_address &&
            o.delivery_address.trim().length > 3 &&
            (!o.notes || (!o.notes.includes('Abbinato') && !o.notes.includes('Batch:')))
        );

        if (candidateDeliveryOrders.length > 0) {
          const newOrderLoc = await geocodeLivornoAddress(delivery_address);

          for (const candidate of candidateDeliveryOrders) {
            const candidateLoc = await geocodeLivornoAddress(candidate.delivery_address);
            const dist = calculateDistanceMeters(newOrderLoc, candidateLoc);

            const newBearing = calculateBearing(ANGELS_LIVORNO_LOC, newOrderLoc);
            const candidateBearing = calculateBearing(ANGELS_LIVORNO_LOC, candidateLoc);
            const angleDiff = Math.abs(newBearing - candidateBearing);
            const isSameDirection = angleDiff <= 35 || angleDiff >= 325;

            // Trigger batching ONLY if within 600m radius OR within 1000m along same direction corridor
            if (dist <= 600 || (dist <= 1100 && isSameDirection)) {
              isBatched = true;
              pairedOrder = candidate;
              distanceMeters = dist;
              batchId = `BATCH-${Date.now().toString().slice(-6)}`;
              mapsMultiStopUrl = generateGoogleMapsMultiStopUrl(
                candidate.delivery_address,
                delivery_address
              );

              // Update both orders in Supabase with batch reference
              const batchNote = `Abbinato: #${batchId} (~${dist}m)`;
              await supabase
                .from('orders')
                .update({ notes: batchNote })
                .in('id', [order_id, candidate.id]);

              break;
            }
          }
        }
      }
    }

    const itemsText = items
      ? items
          .map(
            (i: any) =>
              `• ${i.qty}x ${i.name} (€${(
                Number(i.price_at_order || 0) * Number(i.qty || 1)
              ).toFixed(2)})`
          )
          .join('\n')
      : 'Nessun dettaglio articoli';

    let messageText = '';
    let replyMarkup: any = {};

    if (isBatched && pairedOrder) {
      const pairedShortId = String(pairedOrder.id).slice(0, 8).toUpperCase();
      const combinedTotal = Number(total_amount) + Number(pairedOrder.total_amount || 0);

      messageText =
        `📦 *DOPPIA CONSEGNA ABBINATA IN ZONA!* 🛵💨\n` +
        `⚡ *Distanza tra le 2 consegne:* ~${distanceMeters}m (Stessa Direzione)\n\n` +
        `1️⃣ *CONSEGNA A:* ${pairedOrder.guest_name} (#${pairedShortId})\n` +
        `📍 *Indirizzo:* ${pairedOrder.delivery_address}\n` +
        `📞 *Tel:* ${pairedOrder.guest_phone} | 💰 €${Number(pairedOrder.total_amount).toFixed(2)}\n\n` +
        `2️⃣ *CONSEGNA B:* ${guest_name} (#${shortId})\n` +
        `📍 *Indirizzo:* ${delivery_address}\n` +
        `📞 *Tel:* ${guest_phone} | 💰 €${Number(total_amount).toFixed(2)}\n\n` +
        `⏰ *Orario Richiesto:* ${formattedTime}\n` +
        `💵 *TOTALE COMPLESSIVO INCASSO:* *€ ${combinedTotal.toFixed(2)}*\n\n` +
        `🗺️ [APRI ITINERARIO MULTI-TAPPA SU GOOGLE MAPS](${mapsMultiStopUrl})\n\n` +
        `🟢 *STATO:* *PRONTO PER PRESA IN CARICO DOPPIA*`;

      replyMarkup = {
        inline_keyboard: [
          [
            {
              text: '🛵 PRENDI IN CARICO DOPPIA CONSEGNA',
              callback_data: `claim_batch:${batchId}:${order_id}:${pairedOrder.id}`,
            },
          ],
          [
            {
              text: '🗺️ APRI PERCORSO GOOGLE MAPS',
              url: mapsMultiStopUrl,
            },
          ],
        ],
      };
    } else {
      // Standard Single Order Telegram Message
      const mapsSingleUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
        `${delivery_address}, Livorno`
      )}`;

      messageText =
        `🚨 *NUOVO ORDINE RICEVUTO!* 🚨\n\n` +
        `🆔 *ID Ordine:* \`#${shortId}\`\n` +
        `👤 *Cliente:* ${guest_name}\n` +
        `📞 *Telefono:* ${guest_phone}\n` +
        `📍 *Indirizzo/Tipo:* ${delivery_address}\n` +
        `⏰ *Orario Richiesto:* ${formattedTime}\n\n` +
        `🛒 *PIATTI ORDINATI:*\n${itemsText}\n\n` +
        `💰 *TOTALE DA PAGARE:* *€ ${Number(total_amount).toFixed(2)}*\n\n` +
        `🟢 *STATO:* *DISPONIBILE PER LA CONSEGNA*`;

      replyMarkup = {
        inline_keyboard: [
          [
            {
              text: '🛵 PRENDI IN CARICO (PRENOTA CONSEGNA)',
              callback_data: `claim:${order_id}:${shortId}`,
            },
          ],
          [
            {
              text: '📍 NAVIGA CON GOOGLE MAPS',
              url: mapsSingleUrl,
            },
          ],
        ],
      };
    }

    // Send Telegram message
    const telegramUrl = `https://api.telegram.org/bot${botToken}/sendMessage`;
    const response = await fetch(telegramUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: messageText,
        parse_mode: 'Markdown',
        reply_markup: replyMarkup,
      }),
    });

    const data = await response.json();
    return NextResponse.json({ success: true, isBatched, data });
  } catch (error: any) {
    console.error('Error sending Telegram notification:', error);
    return NextResponse.json(
      { success: false, error: error.message },
      { status: 500 }
    );
  }
}
