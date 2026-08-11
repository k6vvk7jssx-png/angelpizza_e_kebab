import { NextResponse } from 'next/server';
import { supabase } from '../../../lib/supabaseClient';

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const month = searchParams.get('month'); // YYYY-MM optional

    let startDate: Date;
    let endDate: Date;

    if (month && /^\d{4}-\d{2}$/.test(month)) {
      const [year, m] = month.split('-').map(Number);
      startDate = new Date(year, m - 1, 1);
      endDate = new Date(year, m, 0, 23, 59, 59);
    } else {
      const now = new Date();
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
      endDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);
    }

    // Query orders for the target month
    const { data: orders, error: dbError } = await supabase
      .from('orders')
      .select('*')
      .gte('created_at', startDate.toISOString())
      .lte('created_at', endDate.toISOString());

    if (dbError) throw dbError;

    const totalOrders = orders ? orders.length : 0;
    let totalRevenue = 0;
    let pickupOrders = 0;
    let deliveryOrders = 0;

    const productQtyMap: Record<string, number> = {};
    const productRevenueMap: Record<string, number> = {};

    if (orders && orders.length > 0) {
      for (const order of orders) {
        const amount = Number(order.total_amount || 0);
        totalRevenue += amount;

        const address = String(order.delivery_address || '').toLowerCase();
        if (address.includes('asporto') || address.includes('ritiro') || address.includes('cassa')) {
          pickupOrders++;
        } else {
          deliveryOrders++;
        }

        let items = order.items || [];
        if (typeof items === 'string') {
          try {
            items = JSON.parse(items);
          } catch (e) {
            items = [];
          }
        }

        if (Array.isArray(items)) {
          for (const item of items) {
            const name = item.name || 'Prodotto Sconosciuto';
            const qty = Number(item.qty || 1);
            const price = Number(item.price_at_order || 0);

            productQtyMap[name] = (productQtyMap[name] || 0) + qty;
            productRevenueMap[name] = (productRevenueMap[name] || 0) + qty * price;
          }
        }
      }
    }

    // Sort products by quantity sold
    const sortedProducts = Object.entries(productQtyMap).sort(
      ([, qtyA], [, qtyB]) => qtyB - qtyA
    );

    const topProduct = sortedProducts.length > 0 ? sortedProducts[0] : null;
    const monthName = startDate.toLocaleDateString('it-IT', { month: 'long', year: 'numeric' });

    // Send Telegram Notification to Manager if bot credentials exist
    const botToken = process.env.TELEGRAM_BOT_TOKEN || process.env.NEXT_PUBLIC_TELEGRAM_BOT_TOKEN;
    const chatId = process.env.TELEGRAM_CHAT_ID || process.env.NEXT_PUBLIC_TELEGRAM_CHAT_ID;

    if (botToken && chatId) {
      const topProductText = topProduct
        ? `🏆 *PRODOTTO PIÙ VENDUTO DEL MESE:* *${topProduct[0]}* (${topProduct[1]} unità vendute - €${(productRevenueMap[topProduct[0]] || 0).toFixed(2)})`
        : 'ℹ️ Nessun ordine registrato questo mese.';

      const rankingText = sortedProducts
        .slice(0, 5)
        .map(
          ([pName, qty], idx) =>
            `${idx + 1}. *${pName}*: ${qty} venduti (€${(productRevenueMap[pName] || 0).toFixed(2)})`
        )
        .join('\n');

      const telegramMsg =
        `📊 *RAPPORTO MENSILE VENDITE - ANGELS LIVORNO*\n` +
        `📅 *Mese:* ${monthName.toUpperCase()}\n\n` +
        `${topProductText}\n\n` +
        `💰 *Incasso Totale Mese:* €${totalRevenue.toFixed(2)}\n` +
        `📦 *Totale Ordini:* ${totalOrders} (${deliveryOrders} Domicilio / ${pickupOrders} Asporto)\n\n` +
        `🔝 *TOP 5 PIATTI DEL MESE:*\n${rankingText || 'N/D'}\n\n` +
        `📍 *Angels Pizzeria & Kebab Livorno*`;

      fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: telegramMsg,
          parse_mode: 'Markdown',
        }),
      }).catch(console.error);
    }

    return NextResponse.json({
      success: true,
      month: monthName,
      totalOrders,
      totalRevenue: Number(totalRevenue.toFixed(2)),
      pickupOrders,
      deliveryOrders,
      topProduct: topProduct
        ? {
            name: topProduct[0],
            quantitySold: topProduct[1],
            revenue: Number((productRevenueMap[topProduct[0]] || 0).toFixed(2)),
          }
        : null,
      rankings: sortedProducts.map(([name, quantitySold]) => ({
        name,
        quantitySold,
        revenue: Number((productRevenueMap[name] || 0).toFixed(2)),
      })),
    });
  } catch (error: any) {
    console.error('Error generating monthly report:', error);
    return NextResponse.json(
      { success: false, error: error.message },
      { status: 500 }
    );
  }
}
