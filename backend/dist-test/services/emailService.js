"use strict";
// Uses Gmail REST API over HTTPS 
// No extra npm packages needed: Node 18+ has native fetch.
// No SMTP, no nodemailer.
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendPasswordChangeCode = exports.sendPasswordResetCode = exports.sendAccountDeletionCode = exports.send2FACode = exports.sendVerificationEmail = exports.verifyEmailTransporter = void 0;
// Access-token cache 
// Tokens expire in 1 hour; cache and refresh lazily.
let _tokenCache = null;
async function getAccessToken() {
    const now = Date.now();
    if (_tokenCache && _tokenCache.expiresAt > now + 60000) {
        return _tokenCache.token;
    }
    const params = new URLSearchParams({
        client_id: process.env.GMAIL_CLIENT_ID,
        client_secret: process.env.GMAIL_CLIENT_SECRET,
        refresh_token: process.env.GMAIL_REFRESH_TOKEN,
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
    const data = await res.json();
    _tokenCache = {
        token: data.access_token,
        expiresAt: now + data.expires_in * 1000,
    };
    return data.access_token;
}
// Core send 
async function sendMail(to, subject, html) {
    const from = process.env.EMAIL_FROM;
    if (!from)
        throw new Error('EMAIL_FROM env var is required');
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
// Startup health check (called from index.ts) 
const verifyEmailTransporter = async () => {
    const required = [
        'GMAIL_CLIENT_ID',
        'GMAIL_CLIENT_SECRET',
        'GMAIL_REFRESH_TOKEN',
        'EMAIL_FROM',
    ];
    const missing = required.filter((k) => !process.env[k]);
    if (missing.length) {
        console.warn(' Email disabled — missing env vars:', missing.join(', '));
        return;
    }
    try {
        await getAccessToken();
        console.log(`Gmail OAuth2 ready — sending as ${process.env.EMAIL_FROM}`);
    }
    catch (err) {
        console.error('Gmail OAuth2 token refresh failed:', err?.message ?? err);
        console.error('   Double-check GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN');
    }
};
exports.verifyEmailTransporter = verifyEmailTransporter;
// Template helpers 
function codeBlock(code) {
    return `<div style="
      font-size:36px;font-weight:bold;color:#6366F1;letter-spacing:12px;
      padding:20px 24px;text-align:center;background:#F5F3FF;
      border-radius:12px;margin:20px 0;font-family:monospace;"
    >${code}</div>`;
}
function baseTemplate(title, body) {
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
// Public senders 
const sendVerificationEmail = async (to, name, code) => {
    await sendMail(to, 'Verify your Momentum account', baseTemplate(`Welcome, ${name}!`, `<p style="color:#444;font-size:15px;">Enter this code to verify your email address:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">Expires in <strong>5 minutes</strong>.</p>`));
};
exports.sendVerificationEmail = sendVerificationEmail;
const send2FACode = async (to, name, code) => {
    await sendMail(to, 'Your Momentum sign-in code', baseTemplate(`Sign-in code for ${name}`, `<p style="color:#444;font-size:15px;">Use this code to complete your sign-in:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">Expires in <strong>10 minutes</strong>. Do not share it.</p>`));
};
exports.send2FACode = send2FACode;
const sendAccountDeletionCode = async (to, name, code) => {
    await sendMail(to, 'Confirm account deletion — Momentum', baseTemplate(`Confirm account deletion, ${name}`, `<p style="color:#444;font-size:15px;">Enter this code to permanently delete your Momentum account. This removes your tasks, team memberships, and account data.</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">Expires in <strong>10 minutes</strong>. If you didn't request this, ignore this email — your account will remain unchanged.</p>`));
};
exports.sendAccountDeletionCode = sendAccountDeletionCode;
const sendPasswordResetCode = async (to, name, code) => {
    await sendMail(to, 'Reset your Momentum password', baseTemplate(`Reset your password, ${name}`, `<p style="color:#444;font-size:15px;">Enter this code to reset your password:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">Expires in <strong>10 minutes</strong>. If you didn't request this, you can ignore this email — your password will remain unchanged.</p>`));
};
exports.sendPasswordResetCode = sendPasswordResetCode;
const sendPasswordChangeCode = async (to, name, code) => {
    await sendMail(to, 'Confirm your password change — Momentum', baseTemplate(`Confirm password change, ${name}`, `<p style="color:#444;font-size:15px;">Enter this code to confirm your new password:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">Expires in <strong>10 minutes</strong>. If you didn't request this, please secure your account immediately — someone may have your password.</p>`));
};
exports.sendPasswordChangeCode = sendPasswordChangeCode;
