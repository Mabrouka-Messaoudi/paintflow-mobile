// Deletes a client completely: photos in storage, the project row
// (payments and purchases cascade) and the client's login account.
// Only the painter (role = 'admin') may call it.

import { createClient } from 'npm:@supabase/supabase-js@2';

const BUCKET = 'receipts';

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  // 1. The caller must be signed in as the painter (admin)
  const jwt = req.headers.get('Authorization')?.replace('Bearer ', '');
  if (!jwt) return json({ error: 'غير مصرّح' }, 401);

  const { data: { user }, error: userErr } = await admin.auth.getUser(jwt);
  if (userErr || !user) return json({ error: 'غير مصرّح' }, 401);

  const { data: profile } = await admin
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single();
  if (profile?.role !== 'admin') {
    return json({ error: 'هذه العملية خاصة بالدهان' }, 403);
  }

  // 2. Input
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'طلب غير صالح' }, 400);
  }
  const clientId = String(body.client_id ?? '');
  if (!clientId) return json({ error: 'الحريف غير محدد' }, 400);

  const { data: client } = await admin
    .from('clients')
    .select('id, user_id')
    .eq('id', clientId)
    .maybeSingle();
  if (!client) return json({ error: 'الحريف غير موجود' }, 404);

  // 3. Photos (stored under "<client_id>/...")
  const { data: files } = await admin.storage
    .from(BUCKET)
    .list(clientId, { limit: 1000 });
  if (files && files.length > 0) {
    await admin.storage
      .from(BUCKET)
      .remove(files.map((f) => `${clientId}/${f.name}`));
  }

  // 4. The project row — payments and purchases go with it (on delete cascade)
  const { error: delErr } = await admin
    .from('clients')
    .delete()
    .eq('id', clientId);
  if (delErr) {
    return json({ error: `تعذّر حذف الحريف: ${delErr.message}` }, 500);
  }

  // 5. The login account, if any
  if (client.user_id) {
    const { error: authErr } = await admin.auth.admin.deleteUser(
      client.user_id,
    );
    if (authErr) {
      return json({
        ok: true,
        warning: 'حُذف الحريف، لكن تعذّر حذف حساب دخوله',
      });
    }
  }

  return json({ ok: true });
});
