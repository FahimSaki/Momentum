import { test, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { generateOTP, generateAndSendOtp } from './otpService';

const originalEnv = process.env.NODE_ENV;
const originalLog = { log: console.log, error: console.error, warn: console.warn };

// The service logs on every call; keep test output readable.
beforeEach(() => {
    console.log = () => { };
    console.error = () => { };
    console.warn = () => { };
});
afterEach(() => {
    console.log = originalLog.log;
    console.error = originalLog.error;
    console.warn = originalLog.warn;
    if (originalEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = originalEnv;
});

test('generateOTP always returns six digits', () => {
    for (let i = 0; i < 2000; i++) {
        assert.match(generateOTP(), /^\d{6}$/);
    }
});

test('a successful send persists the code with its expiry, then reports sent', async () => {
    const calls: string[] = [];
    let persisted: { code: string; expiresAt: Date } | undefined;
    let sentCode: string | undefined;
    const before = Date.now();

    const result = await generateAndSendOtp({
        persist: async (code, expiresAt) => { calls.push('persist'); persisted = { code, expiresAt }; },
        send: async (code) => { calls.push('send'); sentCode = code; },
        expiryMs: 5 * 60 * 1000,
        logContext: 'test@example.com (unit test)',
    });

    assert.deepEqual(calls, ['persist', 'send']);
    assert.equal(result.sent, true);
    assert.equal(persisted?.code, result.code);
    assert.equal(sentCode, result.code);
    const expiresIn = persisted!.expiresAt.getTime() - before;
    assert.ok(expiresIn >= 5 * 60 * 1000 && expiresIn < 5 * 60 * 1000 + 5000);
});

test('a failed send outside development reports sent: false but keeps the persisted code', async () => {
    process.env.NODE_ENV = 'production';
    let persistedCode: string | undefined;

    const result = await generateAndSendOtp({
        persist: async (code) => { persistedCode = code; },
        send: async () => { throw new Error('smtp down'); },
        expiryMs: 1000,
        logContext: 'test@example.com (unit test)',
    });

    assert.equal(result.sent, false);
    assert.equal(persistedCode, result.code);
});

test('a failed send in development counts as delivered so flows can be completed locally', async () => {
    process.env.NODE_ENV = 'development';

    const result = await generateAndSendOtp({
        persist: async () => { },
        send: async () => { throw new Error('no gmail credentials'); },
        expiryMs: 1000,
        logContext: 'test@example.com (unit test)',
    });

    assert.equal(result.sent, true);
});

test('a persist failure is not swallowed and nothing is sent', async () => {
    let sendCalled = false;
    await assert.rejects(
        generateAndSendOtp({
            persist: async () => { throw new Error('db down'); },
            send: async () => { sendCalled = true; },
            expiryMs: 1000,
            logContext: 'test@example.com (unit test)',
        }),
        /db down/
    );
    assert.equal(sendCalled, false);
});