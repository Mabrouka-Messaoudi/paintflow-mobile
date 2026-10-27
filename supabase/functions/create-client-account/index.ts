// Creates a login account for a client and links it to their project.
// Only the painter (role = 'admin') may call it.
// The service-role key stays on the server and never reaches the app.

import { createClient } from 'npm:@supabase/supabase-js@2';

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

  // 2. Validate input
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'طلب غير صالح' }, 400);
  }
  const clientId = String(body.client_id ?? '');
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');

  if (!clientId) return json({ error: 'الحريف غير محدد' }, 400);
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json({ error: 'البريد الإلكتروني غير صحيح' }, 400);
  }
  if (password.length < 8) {
    return json({ error: 'كلمة السر يجب أن تكون 8 أحرف على الأقل' }, 400);
  }

  // 3. The client must exist and must not have an account yet
  const { data: client } = await admin
    .from('clients')
    .select('id, full_name, user_id')
    .eq('id', clientId)
    .maybeSingle();
  if (!client) return json({ error: 'الحريف غير موجود' }, 404);
  if (client.user_id) {
    return json({ error: 'هذا الحريف لديه حساب بالفعل' }, 409);
  }

  // 4. Create the auth user, already confirmed
  const { data: created, error: createErr } = await admin.auth.admin
    .createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: client.full_name },
    });
  if (createErr || !created.user) {
    const taken = (createErr?.message ?? '').toLowerCase().includes('already');
    return json(
      {
        error: taken
          ? 'هذا البريد مستعمل في حساب آخر'
          : `تعذّر إنشاء الحساب: ${createErr?.message}`,
      },
      taken ? 409 : 500,
    );
  }

  // 5. Link the account to the client; undo the user if linking fails
  const { error: linkErr } = await admin
    .from('clients')
    .update({ user_id: created.user.id, email })
    .eq('id', clientId);
  if (linkErr) {
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: `تعذّر ربط الحساب: ${linkErr.message}` }, 500);
  }

  return json({ user_id: created.user.id, email });
});
