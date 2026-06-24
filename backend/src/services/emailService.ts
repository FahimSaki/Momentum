// Uses Gmail REST API over HTTPS 
// No extra npm packages needed: Node 18+ has native fetch.
// No SMTP, no nodemailer.

// ── Access-token cache ─────────────────────────────────────────────────────
// Tokens expire in 1 hour; cache and refresh lazily.
let _tokenCache: { token: string; expiresAt: number } | null = null;

async function getAccessToken(): Promise<string> {
    const now = Date.now();
    if (_tokenCache && _tokenCache.expiresAt > now + 60_000) {
        return _tokenCache.token;
    }

    const params = new URLSearchParams({
        client_id: process.env.GMAIL_CLIENT_ID!,
        client_secret: process.env.GMAIL_CLIENT_SECRET!,
        refresh_token: process.env.GMAIL_REFRESH_TOKEN!,
        grant_type: 'refresh_token',
    });

    const res = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: params.toString(),
    });

    if (!res.ok) {
        const text = await res.text();
        throw new Error(`Gmail token refresh failed (${res.status}): ${text}`);
    }

    const data = await res.json() as { access_token: string; expires_in: number };
    _tokenCache = {
        token: data.access_token,
        expiresAt: now + data.expires_in * 1000,
    };
    return data.access_token;
}

// ── Core send ──────────────────────────────────────────────────────────────
async function sendMail(to: string, subject: string, html: string): Promise<void> {
    const from = process.env.EMAIL_FROM;
    if (!from) throw new Error('EMAIL_FROM env var is required');

    const accessToken = await getAccessToken();

    // RFC 2822 raw message
    const raw = [
        `From: Momentum <${from}>`,
        `To: ${to}`,
        `Subject: ${subject}`,
        `MIME-Version: 1.0`,
        `Content-Type: text/html; charset=UTF-8`,
        ``,
        html,
    ].join('\r\n');

    // Gmail API requires URL-safe base64
    const encoded = Buffer.from(raw)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');

    const res = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ raw: encoded }),
    });

    if (!res.ok) {
        const err = await res.json();
        throw new Error(`Gmail API send failed (${res.status}): ${JSON.stringify(err)}`);
    }
}

// ── Startup health check (called from index.ts) ────────────────────────────
export const verifyEmailTransporter = async (): Promise<void> => {
    const required = [
        'GMAIL_CLIENT_ID',
        'GMAIL_CLIENT_SECRET',
        'GMAIL_REFRESH_TOKEN',
        'EMAIL_FROM',
    ];
    const missing = required.filter((k) => !process.env[k]);

    if (missing.length) {
        console.warn('⚠️  Email disabled — missing env vars:', missing.join(', '));
        return;
    }

    try {
        await getAccessToken();
        console.log(`✅ Gmail OAuth2 ready — sending as ${process.env.EMAIL_FROM}`);
    } catch (err: any) {
        console.error('❌ Gmail OAuth2 token refresh failed:', err?.message ?? err);
        console.error('   Double-check GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN');
    }
};

// ── Template helpers ───────────────────────────────────────────────────────
function codeBlock(code: string): string {
    return `<div style="
      font-size:36px;font-weight:bold;color:#6366F1;letter-spacing:12px;
      padding:20px 24px;text-align:center;background:#F5F3FF;
      border-radius:12px;margin:20px 0;font-family:monospace;"
    >${code}</div>`;
}

function baseTemplate(title: string, body: string): string {
    return `
    <div style="font-family:Arial,sans-serif;max-width:500px;margin:0 auto;padding:24px;">
      <div style="text-align:center;margin-bottom:24px;">
        <h1 style="color:#6366F1;font-size:22px;margin:0;font-weight:700;">Momentum</h1>
      </div>
      <h2 style="color:#1C1B3A;font-size:18px;font-weight:600;">${title}</h2>
      ${body}
      <p style="color:#999;font-size:12px;margin-top:32px;border-top:1px solid #eee;padding-top:16px;">
        If you didn't request this, you can safely ignore this email.
      </p>
    </div>`;
}

// ── Public senders ─────────────────────────────────────────────────────────
export const sendVerificationEmail = async (
    to: string,
    name: string,
    code: string
): Promise<void> => {
    await sendMail(
        to,
        'Verify your Momentum account',
        baseTemplate(
            `Welcome, ${name}!`,
            `<p style="color:#444;font-size:15px;">Enter this code to verify your email address:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">Expires in <strong>24 hours</strong>.</p>`
        )
    );
};

export const send2FACode = async (
    to: string,
    name: string,
    code: string
): Promise<void> => {
    await sendMail(
        to,
        'Your Momentum sign-in code',
        baseTemplate(
            `Sign-in code for ${name}`,
            `<p style="color:#444;font-size:15px;">Use this code to complete your sign-in:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">Expires in <strong>10 minutes</strong>. Do not share it.</p>`
        )
    );
};