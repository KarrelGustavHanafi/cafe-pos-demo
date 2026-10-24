/// Asia/Jakarta (WIB) calendar helpers.
///
/// Reporting days are the business's days, not the device's. A visitor opening
/// the public demo from UTC-5 must still see the same daily totals as the cafe
/// in Jakarta, so every date bucket is derived from the WIB wall clock.
///
/// Indonesia has no daylight saving and WIB is UTC+7 year-round, so a fixed
/// offset is exact here - no tz database required.
///
/// Instants are left untouched: [Order.createdAt] stays a real instant. Only
/// the *bucketing* uses the Jakarta calendar.
library;

const Duration jakartaOffset = Duration(hours: 7);

/// The current Jakarta wall-clock time.
///
/// The returned value is UTC-flagged but carries WIB components (year..
/// minute), so it is only meaningful for its components - never compare it to
/// a real instant. Reports use it solely to derive the cafe's calendar date.
DateTime jakartaNow() => DateTime.now().toUtc().add(jakartaOffset);

/// The calendar date of [moment] in Jakarta, as a date-only [DateTime].
///
/// Both sides of every date comparison go through this, so an order and a
/// report window can never be bucketed on different calendars.
DateTime jakartaDate(DateTime moment) {
  final wib = moment.toUtc().add(jakartaOffset);
  return DateTime(wib.year, wib.month, wib.day);
}
