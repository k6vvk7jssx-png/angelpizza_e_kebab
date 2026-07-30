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

      if (dataStr.startsWith('claim:')) {
        const parts = dataStr.split(':');
        const orderId = parts[1];
        const shortId = parts[2] || 'ORD';

        // Check or update status on Supabase
        if (orderId) {
          await supabase
            .from('orders')
            .update({
              status: 'delivering',
            })
            .eq('id', orderId);
        }

        // 1. Answer Telegram popup alert to the driver
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

          // 2. Edit Telegram message text to lock and mark as claimed
          if (message && message.message_id) {
            const originalText = message.text || '';
            const updatedText =
              originalText.replace(
                '🟢 *STATO:* *DISPONIBILE PER LA CONSEGNA*',
                `🔒 *PRENOTATO DA:* *${driverName.toUpperCase()}* 🛵`
              ) + `\n\n🔒 *PRENOTATO IN SIMULTANEA DA:* ${driverName} (Pulsante disattivato)`;

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
        // Driver taps an already claimed button
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

    return NextResponse.json({ ok: true });
  } catch (error: any) {
    console.error('Error handling Telegram webhook:', error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
