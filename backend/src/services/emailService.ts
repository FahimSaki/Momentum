import nodemailer from 'nodemailer';

function createTransporter() {
    return nodemailer.createTransport({
        service: 'gmail',
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_APP_PASSWORD,
        },
    });
}

function from(): string {
    return process.env.EMAIL_FROM || `Momentum <${process.env.EMAIL_USER}>`;
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

export const sendVerificationEmail = async (
    to: string,
    name: string,
    code: string
): Promise<void> => {
    const transporter = createTransporter();
    await transporter.sendMail({
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
    const transporter = createTransporter();
    await transporter.sendMail({
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