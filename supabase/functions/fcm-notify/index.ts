import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// ============================================================
// إشعارات Firebase الفورية للإدارة (حضور / تأخر / غياب تلقائي)
// ------------------------------------------------------------
// نداء:  POST /fcm-notify   (verify_jwt = false)
// جسم الطلب:
//   { "title": "...", "body": "...", "role": "admin" }
// ------------------------------------------------------------
// الاعتماديات:
//   secrets: n/a  (SUPABASE_SERVICE_ROLE_KEY يوفرها المنصة تلقائياً)
//   يجب تفعيل FCM HTTP v1 عبر مرجع خدمة Firebase + مفتاح الخدمة:
//     secrets: GOOGLE_APPLICATION_CREDENTIALS (JSON service account)
//             FIREBASE_PROJECT_ID
//     Supabase → Edge Functions → settings → Secret
// ============================================================

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const FIREBASE_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

// توقيع JWT (RS256) يدوياً بدون مكتبات خارجية
async function createServiceAccountJwt(
  credentials: Record<string, any>,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: credentials.client_email,
    scope: FIREBASE_SCOPE,
    aud: credentials.token_uri,
    iat: now,
    exp: now + 3600,
  };
  const b64 = (o: any) =>
    btoa(JSON.stringify(o))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBinary(credentials.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const unsigned = `${b64(header)}.${b64(claims)}`;
  const sig = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsigned),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
  return `${unsigned}.${sigB64}`;
}

function pemToBinary(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const bin = atob(body);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function sendFcm(token: string, title: string, body: string) {
  const credsRaw = Deno.env.get('GOOGLE_APPLICATION_CREDENTIALS');
  if (!credsRaw) return;
  const creds = JSON.parse(credsRaw);
  const accessToken = await createServiceAccountJwt(creds);
  const projectId =
    Deno.env.get('FIREBASE_PROJECT_ID') ?? creds.project_id;
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          android: {
            priority: 'high',
            notification: { channel_id: 'iqra_alerts', sound: 'default' },
          },
          apns: { payload: { aps: { sound: 'default' } } },
        },
      }),
    },
  );
  if (!res.ok) {
    console.error('FCM send failed', res.status, await res.text());
  }
}

Deno.serve(async (req) => {
  try {
    const payload = await req.json();
    const { title, body, role } = payload;

    const query = supabase
      .from('users')
      .select('fcm_token')
      .not('fcm_token', 'is', null)
      .eq('is_active', true);
    if (role && role !== 'all') query.eq('role', role);
    const { data, error } = await query;
    if (error) return json(500, error.message);
    const tokens = (data ?? [])
      .map((u) => u.fcm_token as string)
      .filter((t) => t && t.length > 10);
    if (!tokens.length) return json(200, { sent: 0 });

    let sent = 0;
    for (const t of tokens) {
      await sendFcm(t, title ?? '', body ?? '');
      sent++;
    }
    return json(200, { sent });
  } catch (e) {
    console.error(e);
    return json(500, String(e));
  }
});

function json(status: number, data: any) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}