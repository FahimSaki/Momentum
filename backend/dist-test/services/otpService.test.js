"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = require("node:test");
const strict_1 = __importDefault(require("node:assert/strict"));
const otpService_1 = require("./otpService");
const originalEnv = process.env.NODE_ENV;
const originalLog = { log: console.log, error: console.error, warn: console.warn };
// The service logs on every call; keep test output readable.
(0, node_test_1.beforeEach)(() => {
    console.log = () => { };
    console.error = () => { };
    console.warn = () => { };
});
(0, node_test_1.afterEach)(() => {
    console.log = originalLog.log;
    console.error = originalLog.error;
    console.warn = originalLog.warn;
    if (originalEnv === undefined)
        delete process.env.NODE_ENV;
    else
        process.env.NODE_ENV = originalEnv;
});
(0, node_test_1.test)('generateOTP always returns six digits', () => {
    for (let i = 0; i < 2000; i++) {
        strict_1.default.match((0, otpService_1.generateOTP)(), /^\d{6}$/);
    }
});
(0, node_test_1.test)('a successful send persists the code with its expiry, then reports sent', async () => {
    const calls = [];
    let persisted;
    let sentCode;
    const before = Date.now();
    const result = await (0, otpService_1.generateAndSendOtp)({
        persist: async (code, expiresAt) => { calls.push('persist'); persisted = { code, expiresAt }; },
        send: async (code) => { calls.push('send'); sentCode = code; },
        expiryMs: 5 * 60 * 1000,
        logContext: 'test@example.com (unit test)',
    });
    strict_1.default.deepEqual(calls, ['persist', 'send']);
    strict_1.default.equal(result.sent, true);
    strict_1.default.equal(persisted?.code, result.code);
    strict_1.default.equal(sentCode, result.code);
    const expiresIn = persisted.expiresAt.getTime() - before;
    strict_1.default.ok(expiresIn >= 5 * 60 * 1000 && expiresIn < 5 * 60 * 1000 + 5000);
});
(0, node_test_1.test)('a failed send outside development reports sent: false but keeps the persisted code', async () => {
    process.env.NODE_ENV = 'production';
    let persistedCode;
    const result = await (0, otpService_1.generateAndSendOtp)({
        persist: async (code) => { persistedCode = code; },
        send: async () => { throw new Error('smtp down'); },
        expiryMs: 1000,
        logContext: 'test@example.com (unit test)',
    });
    strict_1.default.equal(result.sent, false);
    strict_1.default.equal(persistedCode, result.code);
});
(0, node_test_1.test)('a failed send in development counts as delivered so flows can be completed locally', async () => {
    process.env.NODE_ENV = 'development';
    const result = await (0, otpService_1.generateAndSendOtp)({
        persist: async () => { },
        send: async () => { throw new Error('no gmail credentials'); },
        expiryMs: 1000,
        logContext: 'test@example.com (unit test)',
    });
    strict_1.default.equal(result.sent, true);
});
(0, node_test_1.test)('a persist failure is not swallowed and nothing is sent', async () => {
    let sendCalled = false;
    await strict_1.default.rejects((0, otpService_1.generateAndSendOtp)({
        persist: async () => { throw new Error('db down'); },
        send: async () => { sendCalled = true; },
        expiryMs: 1000,
        logContext: 'test@example.com (unit test)',
    }), /db down/);
    strict_1.default.equal(sendCalled, false);
});
