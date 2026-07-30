import { NextResponse } from 'next/server';

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
      console.log('Telegram Bot Token or Chat ID not configured in environment variables.');
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

    const shortId = order_id ? String(order_id).slice(0, 8).toUpperCase() : 'NEW';

    const messageText =
      `🚨 *NUOVO ORDINE RICEVUTO!* 🚨\n\n` +
      `🆔 *ID Ordine:* \`#${shortId}\`\n` +
      `👤 *Cliente:* ${guest_name}\n` +
      `📞 *Telefono:* ${guest_phone}\n` +
      `📍 *Indirizzo/Tipo:* ${delivery_address}\n` +
      `⏰ *Orario Richiesto:* ${formattedTime}\n\n` +
      `🛒 *PIATTI ORDINATI:*\n${itemsText}\n\n` +
      `💰 *TOTALE DA PAGARE:* *€ ${Number(total_amount).toFixed(2)}*\n\n` +
      `🟢 *STATO:* *DISPONIBILE PER LA CONSEGNA*`;

    // Send Telegram message with interactive Inline Claim Button
    const telegramUrl = `https://api.telegram.org/bot${botToken}/sendMessage`;
    const response = await fetch(telegramUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: messageText,
        parse_mode: 'Markdown',
        reply_markup: {
          inline_keyboard: [
            [
              {
                text: '🛵 PRENDI IN CARICO (PRENOTA CONSEGNA)',
                callback_data: `claim:${order_id}:${shortId}`,
              },
            ],
          ],
        },
      }),
    });

    const data = await response.json();
    return NextResponse.json({ success: true, data });
  } catch (error: any) {
    console.error('Error sending Telegram notification:', error);
    return NextResponse.json(
      { success: false, error: error.message },
      { status: 500 }
    );
  }
}
