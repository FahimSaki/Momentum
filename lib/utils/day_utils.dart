/// Calendar-day helpers.
///
/// The server stores a completion day as a "day stamp": the UTC-midnight
/// value of a calendar date (2026-10-03 is 2026-10-03T00:00:00Z). A stamp
/// names a date, not a moment, so it must be read through its UTC parts.
/// Converting it to local time first moves it to the neighbouring date for
/// anyone west of UTC.
library;

/// Minutes the device is ahead of UTC right now (UTC+6 is 360). Sent to the
/// backend so a completion lands on the user's own calendar date.
int deviceUtcOffsetMinutes() => DateTime.now().timeZoneOffset.inMinutes;

/// Reads a server day stamp as the calendar date it names (local midnight).
DateTime dayStampToDate(DateTime stamp) {
  final utc = stamp.toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// Writes a calendar date in the server's day-stamp form, for sending or caching.
DateTime dateToDayStamp(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime localToday() => dateOnly(DateTime.now());

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
