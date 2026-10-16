"use strict";
// Per-user calendar days.
//
// A "day stamp" is the UTC-midnight Date of a calendar date: 2026-10-03 is
// stored as 2026-10-03T00:00:00Z. It names a date, not a moment, so readers
// must take its UTC year/month/day and never convert it to local time.
//
// The date a completion belongs to is the completing user's own local date,
// worked out from the UTC offset their device sends with the request.
Object.defineProperty(exports, "__esModule", { value: true });
exports.endOfLocalDay = exports.localDayStamp = exports.parseUtcOffset = void 0;
const MINUTE_MS = 60000;
const MIN_OFFSET = -720; // UTC-12:00
const MAX_OFFSET = 840; // UTC+14:00
/** Minutes ahead of UTC (UTC+6 is 360). Missing or invalid input means UTC,
 *  which is what clients that predate this field implicitly assumed. */
const parseUtcOffset = (value) => {
    const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
    return typeof n === 'number' && Number.isInteger(n) && n >= MIN_OFFSET && n <= MAX_OFFSET ? n : 0;
};
exports.parseUtcOffset = parseUtcOffset;
/** The day stamp of the calendar date that `instant` falls on at `offsetMinutes`. */
const localDayStamp = (instant, offsetMinutes) => {
    const shifted = new Date(instant.getTime() + offsetMinutes * MINUTE_MS);
    return new Date(Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()));
};
exports.localDayStamp = localDayStamp;
/** The instant the local day named by `dayStamp` ends for someone at `offsetMinutes`. */
const endOfLocalDay = (dayStamp, offsetMinutes) => new Date(dayStamp.getTime() + 24 * 60 * MINUTE_MS - offsetMinutes * MINUTE_MS);
exports.endOfLocalDay = endOfLocalDay;
