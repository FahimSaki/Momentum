"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = require("node:test");
const strict_1 = __importDefault(require("node:assert/strict"));
const dayHelpers_1 = require("./dayHelpers");
const HOUR = 3600000;
(0, node_test_1.test)('parseUtcOffset accepts valid whole-minute offsets', () => {
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(360), 360);
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)('360'), 360);
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(-300), -300);
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(0), 0);
});
(0, node_test_1.test)('parseUtcOffset accepts the extreme real-world offsets', () => {
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(-720), -720);
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(840), 840);
});
(0, node_test_1.test)('parseUtcOffset falls back to UTC for missing or invalid input', () => {
    for (const bad of [undefined, null, '', '   ', 'abc', NaN, Infinity, 1.5, {}, [], true]) {
        strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(bad), 0, `expected 0 for ${String(bad)}`);
    }
});
(0, node_test_1.test)('parseUtcOffset rejects offsets outside UTC-12 to UTC+14', () => {
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(841), 0);
    strict_1.default.equal((0, dayHelpers_1.parseUtcOffset)(-721), 0);
});
(0, node_test_1.test)('localDayStamp returns the UTC date when the offset is zero', () => {
    const stamp = (0, dayHelpers_1.localDayStamp)(new Date('2026-10-03T23:59:59.999Z'), 0);
    strict_1.default.equal(stamp.toISOString(), '2026-10-03T00:00:00.000Z');
});
(0, node_test_1.test)('localDayStamp moves forward a day for users ahead of UTC', () => {
    // 20:00 UTC is 02:00 the next day in UTC+6 (Dhaka).
    const stamp = (0, dayHelpers_1.localDayStamp)(new Date('2026-10-03T20:00:00Z'), 360);
    strict_1.default.equal(stamp.toISOString(), '2026-10-04T00:00:00.000Z');
});
(0, node_test_1.test)('localDayStamp stays on the previous day for users behind UTC', () => {
    // 02:00 UTC is 21:00 the previous day in UTC-5.
    const stamp = (0, dayHelpers_1.localDayStamp)(new Date('2026-10-04T02:00:00Z'), -300);
    strict_1.default.equal(stamp.toISOString(), '2026-10-03T00:00:00.000Z');
});
(0, node_test_1.test)('localDayStamp flips exactly at local midnight', () => {
    const before = (0, dayHelpers_1.localDayStamp)(new Date('2026-10-03T17:59:59.999Z'), 360);
    const at = (0, dayHelpers_1.localDayStamp)(new Date('2026-10-03T18:00:00.000Z'), 360);
    strict_1.default.equal(before.toISOString(), '2026-10-03T00:00:00.000Z');
    strict_1.default.equal(at.toISOString(), '2026-10-04T00:00:00.000Z');
});
(0, node_test_1.test)('endOfLocalDay is local midnight expressed as an instant', () => {
    const stamp = new Date('2026-10-03T00:00:00Z');
    strict_1.default.equal((0, dayHelpers_1.endOfLocalDay)(stamp, 360).toISOString(), '2026-10-03T18:00:00.000Z');
    strict_1.default.equal((0, dayHelpers_1.endOfLocalDay)(stamp, -300).toISOString(), '2026-10-04T05:00:00.000Z');
    strict_1.default.equal((0, dayHelpers_1.endOfLocalDay)(stamp, 0).toISOString(), '2026-10-04T00:00:00.000Z');
});
(0, node_test_1.test)('endOfLocalDay and localDayStamp agree for every real offset', () => {
    const offsets = [-720, -480, -300, 0, 60, 330, 345, 360, 540, 765, 840];
    const instants = [
        new Date('2026-01-01T00:00:00Z'),
        new Date('2026-10-03T12:34:56Z'),
        new Date('2026-12-31T23:59:59.999Z'),
    ];
    for (const offset of offsets) {
        for (const instant of instants) {
            const stamp = (0, dayHelpers_1.localDayStamp)(instant, offset);
            const end = (0, dayHelpers_1.endOfLocalDay)(stamp, offset);
            strict_1.default.ok(end.getTime() > instant.getTime(), `end after instant (offset ${offset})`);
            strict_1.default.ok(end.getTime() - instant.getTime() <= 24 * HOUR, `within 24h (offset ${offset})`);
            // The last millisecond still belongs to the same local day, the next one does not.
            strict_1.default.equal((0, dayHelpers_1.localDayStamp)(new Date(end.getTime() - 1), offset).getTime(), stamp.getTime());
            strict_1.default.equal((0, dayHelpers_1.localDayStamp)(end, offset).getTime(), stamp.getTime() + 24 * HOUR);
        }
    }
});
