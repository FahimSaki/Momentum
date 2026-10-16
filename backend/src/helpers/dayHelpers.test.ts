import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseUtcOffset, localDayStamp, endOfLocalDay } from './dayHelpers';

const HOUR = 3_600_000;

test('parseUtcOffset accepts valid whole-minute offsets', () => {
    assert.equal(parseUtcOffset(360), 360);
    assert.equal(parseUtcOffset('360'), 360);
    assert.equal(parseUtcOffset(-300), -300);
    assert.equal(parseUtcOffset(0), 0);
});

test('parseUtcOffset accepts the extreme real-world offsets', () => {
    assert.equal(parseUtcOffset(-720), -720);
    assert.equal(parseUtcOffset(840), 840);
});

test('parseUtcOffset falls back to UTC for missing or invalid input', () => {
    for (const bad of [undefined, null, '', '   ', 'abc', NaN, Infinity, 1.5, {}, [], true]) {
        assert.equal(parseUtcOffset(bad), 0, `expected 0 for ${String(bad)}`);
    }
});

test('parseUtcOffset rejects offsets outside UTC-12 to UTC+14', () => {
    assert.equal(parseUtcOffset(841), 0);
    assert.equal(parseUtcOffset(-721), 0);
});

test('localDayStamp returns the UTC date when the offset is zero', () => {
    const stamp = localDayStamp(new Date('2026-10-03T23:59:59.999Z'), 0);
    assert.equal(stamp.toISOString(), '2026-10-03T00:00:00.000Z');
});

test('localDayStamp moves forward a day for users ahead of UTC', () => {
    // 20:00 UTC is 02:00 the next day in UTC+6 (Dhaka).
    const stamp = localDayStamp(new Date('2026-10-03T20:00:00Z'), 360);
    assert.equal(stamp.toISOString(), '2026-10-04T00:00:00.000Z');
});

test('localDayStamp stays on the previous day for users behind UTC', () => {
    // 02:00 UTC is 21:00 the previous day in UTC-5.
    const stamp = localDayStamp(new Date('2026-10-04T02:00:00Z'), -300);
    assert.equal(stamp.toISOString(), '2026-10-03T00:00:00.000Z');
});

test('localDayStamp flips exactly at local midnight', () => {
    const before = localDayStamp(new Date('2026-10-03T17:59:59.999Z'), 360);
    const at = localDayStamp(new Date('2026-10-03T18:00:00.000Z'), 360);
    assert.equal(before.toISOString(), '2026-10-03T00:00:00.000Z');
    assert.equal(at.toISOString(), '2026-10-04T00:00:00.000Z');
});

test('endOfLocalDay is local midnight expressed as an instant', () => {
    const stamp = new Date('2026-10-03T00:00:00Z');
    assert.equal(endOfLocalDay(stamp, 360).toISOString(), '2026-10-03T18:00:00.000Z');
    assert.equal(endOfLocalDay(stamp, -300).toISOString(), '2026-10-04T05:00:00.000Z');
    assert.equal(endOfLocalDay(stamp, 0).toISOString(), '2026-10-04T00:00:00.000Z');
});

test('endOfLocalDay and localDayStamp agree for every real offset', () => {
    const offsets = [-720, -480, -300, 0, 60, 330, 345, 360, 540, 765, 840];
    const instants = [
        new Date('2026-01-01T00:00:00Z'),
        new Date('2026-10-03T12:34:56Z'),
        new Date('2026-12-31T23:59:59.999Z'),
    ];
    for (const offset of offsets) {
        for (const instant of instants) {
            const stamp = localDayStamp(instant, offset);
            const end = endOfLocalDay(stamp, offset);
            assert.ok(end.getTime() > instant.getTime(), `end after instant (offset ${offset})`);
            assert.ok(end.getTime() - instant.getTime() <= 24 * HOUR, `within 24h (offset ${offset})`);
            // The last millisecond still belongs to the same local day, the next one does not.
            assert.equal(localDayStamp(new Date(end.getTime() - 1), offset).getTime(), stamp.getTime());
            assert.equal(localDayStamp(end, offset).getTime(), stamp.getTime() + 24 * HOUR);
        }
    }
});