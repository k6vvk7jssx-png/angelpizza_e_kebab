import { NextResponse } from 'next/server';
import { supabase } from '../../../lib/supabaseClient';

export async function GET() {
  try {
    const botToken =
      process.env.TELEGRAM_BOT_TOKEN ||
      process.env.NEXT_PUBLIC_TELEGRAM_BOT_TOKEN;
    const chatId =
      process.env.TELEGRAM_CHAT_ID ||
      process.env.NEXT_PUBLIC_TELEGRAM_CHAT_ID;

    let ownerName = 'Eraldo Caracciolo';
    let ownerId = '6723086903';
    const telegramMembers: Array<{ id: string; name: string; username?: string; is_owner: boolean }> = [];

    // 1. Fetch Telegram Chat Administrators to automatically identify the Owner / Creator
    if (botToken && chatId) {
      try {
        const res = await fetch(
          `https://api.telegram.org/bot${botToken}/getChatAdministrators?chat_id=${chatId}`,
          { cache: 'no-store' }
        );
        const data = await res.json();
        if (data.ok && Array.isArray(data.result)) {
          for (const member of data.result) {
            const u = member.user;
            if (!u || u.is_bot) continue;

            const fullName = [u.first_name, u.last_name].filter(Boolean).join(' ').trim();
            const isCreator = member.status === 'creator';

            if (isCreator) {
              ownerName = fullName;
              ownerId = u.id?.toString() || ownerId;
            } else {
              telegramMembers.push({
                id: u.id?.toString() || fullName,
                name: fullName.toUpperCase(),
                username: u.username ? `@${u.username}` : undefined,
                is_owner: false,
              });
            }
          }
        }
      } catch (err) {
        console.warn('Error fetching Telegram admins:', err);
      }
    }

    // 2. Fetch riders registered via Telegram Webhook interaction from Supabase
    try {
      const { data: dbRiders } = await supabase
        .from('telegram_riders')
        .select('*')
        .order('updated_at', { ascending: false });

      if (dbRiders && dbRiders.length > 0) {
        for (const r of dbRiders) {
          if (r.is_owner || r.name.toUpperCase().includes(ownerName.toUpperCase())) {
            continue;
          }
          if (!telegramMembers.some((m) => m.name.toUpperCase() === r.name.toUpperCase())) {
            telegramMembers.push({
              id: r.telegram_id || r.id,
              name: r.name.toUpperCase(),
              username: r.username,
              is_owner: false,
            });
          }
        }
      }
    } catch (e) {
      console.warn('telegram_riders table fallback:', e);
    }

    // 3. Extract rider names already present in order notes
    try {
      const { data: orders } = await supabase
        .from('orders')
        .select('notes')
        .not('notes', 'is', null);

      if (orders) {
        for (const o of orders) {
          if (o.notes && o.notes.includes('Fattorino:')) {
            const index = o.notes.indexOf('Fattorino:');
            let dPart = o.notes.substring(index + 'Fattorino:'.length).trim();
            if (dPart.includes('|')) dPart = dPart.split('|')[0].trim();
            if (dPart.includes('(')) dPart = dPart.split('(')[0].trim();
            const clean = dPart.trim().toUpperCase();

            if (
              clean.length > 0 &&
              !clean.includes(ownerName.toUpperCase()) &&
              !telegramMembers.some((m) => m.name.toUpperCase() === clean)
            ) {
              telegramMembers.push({
                id: clean,
                name: clean,
                is_owner: false,
              });
            }
          }
        }
      }
    } catch (e) {
      console.warn('Orders note extraction fallback:', e);
    }

    return NextResponse.json({
      ok: true,
      owner: {
        id: ownerId,
        name: ownerName,
      },
      riders: telegramMembers,
    });
  } catch (error: any) {
    console.error('Error in telegram-riders route:', error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { name, is_owner, action } = body;

    if (action === 'add_rider' && name) {
      const cleanName = name.trim().toUpperCase();
      try {
        await supabase.from('telegram_riders').upsert({
          telegram_id: `manual_${Date.now()}`,
          name: cleanName,
          is_owner: !!is_owner,
          updated_at: new Date().toISOString(),
        });
      } catch (e) {
        console.warn('Fallback adding rider to shift_settings:', e);
      }
      return NextResponse.json({ ok: true, name: cleanName });
    }

    return NextResponse.json({ error: 'Action non valida' }, { status: 400 });
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
