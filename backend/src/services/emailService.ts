import { Resend } from 'resend';

// ── Lazy singleton ────────────────────────────────────────────────────────────
let _resend: Resend | null = null;

function getResend(): Resend {
    if (_resend) return _resend;
    const apiKey = process.env.RESEND_API_KEY?.trim();
    if (!apiKey) {
        throw new Error(
            'RESEND_API_KEY is not set.\n' +
            '  → Sign up at resend.com → API Keys → add RESEND_API_KEY to your Render env vars.'
        );
    }
    _resend = new Resend(apiKey);
    return _resend;
}

// ── Startup check ─────────────────────────────────────────────────────────────
// Called from index.ts after dotenv.config(). Shows pass/fail in Render logs.
export const verifyEmailTransporter = async (): Promise<void> => {
    const apiKey = process.env.RESEND_API_KEY?.trim();
    const fromAddr = process.env.EMAIL_FROM?.trim() ?? '(EMAIL_FROM not set — defaulting to onboarding@resend.dev)';
    if (apiKey) {
        console.log(`✅ Email service ready (Resend API) — sending as ${fromAddr}`);
    } else {
        console.error('❌ Email service NOT configured: RESEND_API_KEY is missing');
        console.error('   → resend.com → API Keys → add RESEND_API_KEY to Render env vars');
        console.error('   → Emails (verification codes, 2FA) will fail until this is set');
    }
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function from(): string {
    // NOTE: onboarding@resend.dev only sends to your own Resend account email.
    // For sending to real users you must verify a domain at resend.com/domains
    // and set EMAIL_FROM=Momentum <noreply@yourdomain.com> in Render env vars.
    return process.env.EMAIL_FROM?.trim() || 'Momentum <onboarding@resend.dev>';
}

function codeBlock(code: string): string {
    return `<div style="font-size:36px;font-weight:bold;color:#6366F1;letter-spacing:12px;padding:20px 24px;text-align:center;background:#F5F3FF;border-radius:12px;margin:20px 0;font-family:monospace;">${code}</div>`;
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

// ── Senders ───────────────────────────────────────────────────────────────────

export const sendVerificationEmail = async (
    to: string,
    name: string,
    code: string
): Promise<void> => {
    const { error } = await getResend().emails.send({
        from: from(),
        to,
        subject: 'Verify your Momentum account',
        html: baseTemplate(
            `Welcome, ${name}!`,
            `<p style="color:#444;font-size:15px;">Enter this code to verify your email address:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">This code expires in <strong>24 hours</strong>.</p>`
        ),
    });
    if (error) throw new Error(error.message);
};

export const send2FACode = async (
    to: string,
    name: string,
    code: string
): Promise<void> => {
    const { error } = await getResend().emails.send({
        from: from(),
        to,
        subject: 'Your Momentum sign-in code',
        html: baseTemplate(
            `Sign-in code for ${name}`,
            `<p style="color:#444;font-size:15px;">Use this code to complete your sign-in:</p>
             ${codeBlock(code)}
             <p style="color:#999;font-size:13px;">This code expires in <strong>10 minutes</strong>. Do not share it.</p>`
        ),
    });
    if (error) throw new Error(error.message);
};