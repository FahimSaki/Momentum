import { randomInt } from 'crypto';

export function generateOTP(): string {
    return randomInt(100000, 999999).toString();
}

interface GenerateAndSendOtpOptions {
    /** Persists the generated code + expiry (e.g. a findByIdAndUpdate call,
     *  or setting fields on an in-memory document before it's saved). */
    persist: (code: string, expiresAt: Date) => Promise<void>;
    /** Sends the code by email. */
    send: (code: string) => Promise<void>;
    /** How long the code is valid for. */
    expiryMs: number;
    /** Logged on success/failure — typically the recipient's email plus a
     *  short label for which flow this is (e.g. "user@x.com (2FA login)"). */
    logContext: string;
}

/**
 * The shape shared by every OTP flow in this app (registration, resend,
 * login/Google 2FA, forgot password, password change, account deletion):
 * generate a code, persist it with an expiry, then try to email it.
 *
 * Callers decide what a send failure means for their response — some flows
 * (new registration) log and continue since the account is still usable
 * without the email arriving; others (resend, forgot-password) must fail
 * the request since the code is the user's only way forward. That's why
 * this returns `sent` rather than throwing on email failure: the caller
 * inspects it and decides.
 */
export async function generateAndSendOtp(
    options: GenerateAndSendOtpOptions
): Promise<{ code: string; sent: boolean }> {
    const { persist, send, expiryMs, logContext } = options;
    const code = generateOTP();
    const expiresAt = new Date(Date.now() + expiryMs);

    await persist(code, expiresAt);

    try {
        await send(code);
        console.log(`✅ OTP sent to ${logContext}`);
        return { code, sent: true };
    } catch (err: any) {
        console.error(`❌ Failed to send OTP to ${logContext}:`, err?.message ?? err);
        return { code, sent: false };
    }
}