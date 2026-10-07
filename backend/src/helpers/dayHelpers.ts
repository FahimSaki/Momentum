// Per-user calendar days.
//
// A "day stamp" is the UTC-midnight Date of a calendar date: 2026-10-03 is
// stored as 2026-10-03T00:00:00Z. It names a date, not a moment, so readers
// must take its UTC year/month/day and never convert it to local time.
//
// The date a completion belongs to is the completing user's own local date,
// worked out from the UTC offset their device sends with the request.

const MINUTE_MS = 60_000;
const MIN_OFFSET = -720; // UTC-12:00
const MAX_OFFSET = 840;  // UTC+14:00

/** Minutes ahead of UTC (UTC+6 is 360). Missing or invalid input means UTC,
 *  which is what clients that predate this field implicitly assumed. */
export const parseUtcOffset = (value: unknown): number => {
    const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
    return typeof n === 'number' && Number.isInteger(n) && n >= MIN_OFFSET && n <= MAX_OFFSET ? n : 0;
};

/** The day stamp of the calendar date that `instant` falls on at `offsetMinutes`. */
export const localDayStamp = (instant: Date, offsetMinutes: number): Date => {
    const shifted = new Date(instant.getTime() + offsetMinutes * MINUTE_MS);
    return new Date(Date.UTC(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate()));
};