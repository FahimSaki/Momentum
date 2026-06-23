import nodemailer from 'nodemailer';

// ── Lazy singleton transporter ────────────────────────────────────────────────
// Created on first use, NOT at module load time.
// This ensures dotenv.config() in index.ts has already run before we read
// process.env values — otherwise both are undefined and nodemailer throws
// "Missing credentials for PLAIN".
let _transporter: nodemailer.Transporter | null = null;

function getTransporter(): nodemailer.Transporter {
    if (_transporter) return _transporter;

    const user = process.env.EMAIL_USER?.trim();
    const pass = process.env.EMAIL_APP_PASSWORD?.replace(/\s/g, '');

    if (!user || !pass) {
        throw new Error(
            `Email credentials missing.\n` +
            `  EMAIL_USER="${user ?? 'undefined'}"\n` +
            `  EMAIL_APP_PASSWORD="${pass ? '[set]' : 'undefined'}"\n` +
            `  → Add both to your local backend/.env file for development.\n` +
            `  → Verify both are set in the Render dashboard for production.`
        );
    }

    _transporter = nodemailer.createTransport({
        host: 'smtp.gmail.com',
        port: 465,  // was 587 with STARTTLS
        secure: true,          // SSL — more reliable on Render than STARTTLS (port 587)
        auth: { user, pass },
        family: 4,             // IPv4 only, avoids IPv6 issues on some Render instances
        connectionTimeout: 15000,
        greetingTimeout: 10000,
        socketTimeout: 15000,
        tls: { rejectUnauthorized: true },
    } as nodemailer.TransportOptions);

    return _transporter;
}

// ── Startup verification ──────────────────────────────────────────────────────
// Called from index.ts after dotenv.config() and MongoDB connect.
// Shows pass/fail in Render logs immediately on every deploy.
export const verifyEmailTransporter = async (): Promise<void> => {
    try {
        await getTransporter().verify();
        console.log(`✅ Email transporter ready — sending as ${process.env.EMAIL_USER}`);
    } catch (err: any) {
        console.error('❌ Email transporter FAILED:');
        console.error('  ', err?.message ?? err);
        console.error('');
        console.error('  Checklist:');
        console.error('  1. EMAIL_USER   = your full Gmail address');
        console.error('  2. EMAIL_APP_PASSWORD = 16-char App Password, NO spaces');
        console.error('     → myaccount.google.com/security → 2-Step Verification → App passwords');
        console.error('  3. Gmail 2-Step Verification must be ON');
        console.error('  4. Check for leading/trailing spaces in the Render env var field');
    }
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function from(): string {
    return process.env.EMAIL_FROM?.trim() || `Momentum <${process.env.EMAIL_USER?.trim()}>`;
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
// Both throw on failure — callers must catch and handle (done in authController).

export const sendVerificationEmail = async (
    to: string,
    name: string,
    code: string
): Promise<void> => {
    await getTransporter().sendMail({
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
};

export const send2FACode = async (
    to: string,
    name: string,
    code: string
): Promise<void> => {
    await getTransporter().sendMail({
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
};