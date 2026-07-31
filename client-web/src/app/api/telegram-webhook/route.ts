import { NextResponse } from 'next/server';
import { supabase } from '../../../lib/supabaseClient';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const botToken =
      process.env.TELEGRAM_BOT_TOKEN ||
      process.env.NEXT_PUBLIC_TELEGRAM_BOT_TOKEN;

    // Handle Callback Query (Button Clicks on Telegram)
    if (body.callback_query) {
      const callbackQuery = body.callback_query;
      const callbackId = callbackQuery.id;
      const dataStr = callbackQuery.data || '';
      const driverName =
        callbackQuery.from.first_name ||
        callbackQuery.from.username ||
        'Fattorino';
      const message = callbackQuery.message;

      // Handle Daily Rider Count Setting (set_riders:COUNT)
      if (dataStr.startsWith('set_riders:')) {
        const ridersCount = parseInt(dataStr.split(':')[1] || '2', 10);
        const todayStr = new Date().toISOString().split('T')[0];

        // Save into shift_settings table or fallback
        try {
          await supabase.from('shift_settings').upsert({
            date: todayStr,
            riders_count: ridersCount,
            updated_at: new Date().toISOString(),
          });
        } catch (e) {
          console.warn('shift_settings table not available, fallback to metadata:', e);
        }

        if (botToken) {
          await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              callback_query_id: callbackId,
              text: `✅ Impostati ${ridersCount} Rider per il turno serale!`,
              show_alert: true,
            }),
          }).catch(console.error);

          if (message && message.message_id) {
            await fetch(`https://api.telegram.org/bot${botToken}/editMessageText`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                chat_id: message.chat.id,
                message_id: message.message_id,
                text: `✅ *TURNO SERALE IMPOSTATO:* *${ridersCount} RIDER IN SERVIZIO STASERA!* 🛵💨\nIl sistema di abbinamento consegne si adatterà a ${ridersCount} fattorini.`,
                parse_mode: 'Markdown',
              }),
            }).catch(console.error);
          }
        }
      }

      // Handle Double Delivery Batch Claim
      else if (dataStr.startsWith('claim_batch:')) {
        const parts = dataStr.split(':');
        const batchId = parts[1] || 'BATCH';
        const orderId1 = parts[2];
        const orderId2 = parts[3];

        const targetIds = [orderId1, orderId2].filter(Boolean);

        if (targetIds.length > 0) {
          await supabase
            .from('orders')
            .update({
              status: 'delivering',
              notes: `Fattorino: ${driverName.toUpperCase()} (Doppia #${batchId})`,
            })
            .in('id', targetIds);
        }

        if (botToken) {
          await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              callback_query_id: callbackId,
              text: `🔒 DOPPIA CONSEGNA presi in carico da ${driverName}! Buon viaggio.`,
              show_alert: true,
            }),
          }).catch(console.error);

          if (message && message.message_id) {
            const originalText = message.text || '';
            const updatedText =
              originalText.replace(
                '🟢 *STATO:* *PRONTO PER PRESA IN CARICO DOPPIA*',
                `🔒 *PRENOTATO DA:* *${driverName.toUpperCase()}* 🛵 (DOPPIA CONSEGNA)`
              ) + `\n\n🔒 *PRENOTATO IN SIMULTANEA DA:* ${driverName}`;

            await fetch(`https://api.telegram.org/bot${botToken}/editMessageText`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                chat_id: message.chat.id,
                message_id: message.message_id,
                text: updatedText,
                parse_mode: 'Markdown',
                reply_markup: {
                  inline_keyboard: [
                    [
                      {
                        text: `🔒 DOPPIA PRENOTATA DA ${driverName.toUpperCase()}`,
                        callback_data: 'claimed_done',
                      },
                    ],
                  ],
                },
              }),
            }).catch(console.error);
          }
        }
      } else if (dataStr.startsWith('claim:')) {
        const parts = dataStr.split(':');
        const orderId = parts[1];

        if (orderId) {
          await supabase
            .from('orders')
            .update({
              status: 'delivering',
              notes: `Fattorino: ${driverName.toUpperCase()}`,
            })
            .eq('id', orderId);
        }

        if (botToken) {
          await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              callback_query_id: callbackId,
              text: `🔒 Preso in carico da ${driverName}! Buon viaggio.`,
              show_alert: true,
            }),
          }).catch(console.error);

          if (message && message.message_id) {
            const originalText = message.text || '';
            const updatedText =
              originalText.replace(
                '🟢 *STATO:* *DISPONIBILE PER LA CONSEGNA*',
                `🔒 *PRENOTATO DA:* *${driverName.toUpperCase()}* 🛵`
              ) + `\n\n🔒 *PRENOTATO IN SIMULTANEA DA:* ${driverName}`;

            await fetch(`https://api.telegram.org/bot${botToken}/editMessageText`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                chat_id: message.chat.id,
                message_id: message.message_id,
                text: updatedText,
                parse_mode: 'Markdown',
                reply_markup: {
                  inline_keyboard: [
                    [
                      {
                        text: `🔒 PRENOTATO DA ${driverName.toUpperCase()}`,
                        callback_data: 'claimed_done',
                      },
                    ],
                  ],
                },
              }),
            }).catch(console.error);
          }
        }
      } else if (dataStr === 'claimed_done') {
        if (botToken) {
          await fetch(`https://api.telegram.org/bot${botToken}/answerCallbackQuery`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              callback_query_id: callbackId,
              text: `⚠️ Questa consegna è già stata prenotata da un altro fattorino!`,
              show_alert: true,
            }),
          }).catch(console.error);
        }
      }
    }

    // Handle Incoming Telegram Text Commands (e.g. /rider, /shift, /start)
    if (body.message && body.message.text) {
      const text = body.message.text.toLowerCase();
      const chatId = body.message.chat.id;

      if (text.includes('/rider') || text.includes('/shift') || text.includes('/start') || text.includes('quanti rider')) {
        if (botToken) {
          await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              chat_id: chatId,
              text: `🌙 *TURNO SERALE ANGELS LIVORNO* 🛵\n\nQuanti fattorini ci sono in servizio stasera?`,
              parse_mode: 'Markdown',
              reply_markup: {
                inline_keyboard: [
                  [
                    { text: '🛵 1 Rider', callback_data: 'set_riders:1' },
                    { text: '🛵 2 Rider', callback_data: 'set_riders:2' },
                  ],
                  [
                    { text: '🛵 3 Rider', callback_data: 'set_riders:3' },
                    { text: '🛵 4 Rider', callback_data: 'set_riders:4' },
                  ],
                ],
              },
            }),
          }).catch(console.error);
        }
      }
    }

    return NextResponse.json({ ok: true });
  } catch (error: any) {
    console.error('Error handling Telegram webhook:', error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
