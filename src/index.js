/**
 * Sesi — Push Relay Worker
 * ------------------------
 * Firebase Cloud Functions-un əvəzinə: tətbiq Firestore-a yazandan dərhal
 * sonra bu Worker-ə HTTP sorğu göndərir, Worker isə Google-un FCM v1 API-si
 * ilə push bildirişi göndərir. Tamamilə pulsuz (Blaze planı tələb etmir).
 *
 * Təhlükəsizlik: yalnız düzgün `Authorization: Bearer <WORKER_AUTH_SECRET>`
 * başlığı olan sorğular qəbul edilir — əks halda istənilən kəs bu Worker-i
 * tapıb sənin Firebase layihən adından push göndərə bilərdi.
 */

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const authHeader = request.headers.get("Authorization") || "";
    if (authHeader !== `Bearer ${env.WORKER_AUTH_SECRET}`) {
      return new Response("Unauthorized", { status: 401 });
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return new Response("Invalid JSON", { status: 400 });
    }

    const { token, title, body, data, android, apns } = payload;
    if (!token) {
      return new Response("Missing 'token'", { status: 400 });
    }

    try {
      const accessToken = await getAccessToken(env);
      const message = buildMessage({ token, title, body, data, android, apns });

      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ message }),
        }
      );

      const resultText = await fcmRes.text();
      if (!fcmRes.ok) {
        return new Response(`FCM xətası: ${resultText}`, { status: 502 });
      }
      return new Response(resultText, {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    } catch (err) {
      return new Response(`Worker xətası: ${err.message}`, { status: 500 });
    }
  },

  /**
   * Gündəlik işə düşür (wrangler.toml-dakı [triggers] crons ilə qurulur).
   * "Gəzinti Tarixçəsi" — 2 həftədən köhnə URL yazılarını Firestore-dan
   * silir. Bilərəkdən YALNIZ `browsingHistory/*\/urls` kolleksiyasını
   * hədəfləyir (sharedNotifications/urgentCalls-a toxunmur).
   */
  async scheduled(event, env, ctx) {
    ctx.waitUntil(cleanupOldBrowsingHistory(env));
  },
};

async function cleanupOldBrowsingHistory(env) {
  const accessToken = await getAccessToken(env);
  const cutoff = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString();
  const baseUrl = `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents`;

  const queryRes = await fetch(`${baseUrl}:runQuery`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "urls", allDescendants: true }],
        where: {
          fieldFilter: {
            field: { fieldPath: "capturedAt" },
            op: "LESS_THAN",
            value: { timestampValue: cutoff },
          },
        },
        limit: 500,
      },
    }),
  });

  if (!queryRes.ok) {
    console.error("Firestore sorğusu uğursuz oldu:", await queryRes.text());
    return;
  }

  const results = await queryRes.json();
  const docNames = (results || [])
    .filter((r) => r.document && r.document.name)
    .map((r) => r.document.name);

  if (docNames.length === 0) return;

  await Promise.all(
    docNames.map((name) =>
      fetch(`https://firestore.googleapis.com/v1/${name}`, {
        method: "DELETE",
        headers: { Authorization: `Bearer ${accessToken}` },
      })
    )
  );

  console.log(`${docNames.length} köhnə gəzinti yazısı silindi.`);
}

function buildMessage({ token, title, body, data, android, apns }) {
  const message = { token };

  if (title || body) {
    message.notification = { title: title || "", body: body || "" };
  }

  if (data) {
    // FCM v1 API bütün data dəyərlərinin string olmasını tələb edir
    message.data = Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    );
  }

  message.android = android || {
    priority: "HIGH",
    notification: {
      channelId: "couple_high",
      sound: "default",
      color: "#9D7CF5",
    },
  };

  if (apns) message.apns = apns;

  return message;
}

// ── Google OAuth2 access token (service account JWT-bearer axını) ─────────
// Worker izolatları arası bir qədər keşlənir ki, hər sorğuda yenidən JWT
// imzalamaq lazım gəlməsin (Google token-ı 1 saat etibarlıdır).
let cachedToken = null;
let cachedExpiry = 0;

async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedExpiry - 60 > now) {
    return cachedToken;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const claim = {
    iss: env.FIREBASE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const b64url = (obj) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, "-")
      .replace(/\//g, "_")
      .replace(/=+$/, "");

  const unsigned = `${b64url(header)}.${b64url(claim)}`;
  const key = await importPrivateKey(env.FIREBASE_PRIVATE_KEY);
  const signature = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(unsigned)
  );
  const jwt = `${unsigned}.${arrayBufferToBase64Url(signature)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenJson = await tokenRes.json();
  if (!tokenRes.ok) {
    throw new Error(`Token mübadiləsi uğursuz: ${JSON.stringify(tokenJson)}`);
  }

  cachedToken = tokenJson.access_token;
  cachedExpiry = now + tokenJson.expires_in;
  return cachedToken;
}

async function importPrivateKey(pem) {
  const pemContents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
}

function arrayBufferToBase64Url(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
