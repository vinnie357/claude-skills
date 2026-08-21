/// Parses `input` as an RFC 3339 timestamp, returned in UTC.
/// `input` must carry an explicit offset; RFC 3339 allows omitting it, and
/// reading an offsetless value as local time shifts ledger entries silently.
pub fn parse_timestamp(input: &str) -> Result<DateTime<Utc>, ParseError> {
    DateTime::parse_from_rfc3339(input).map(|dt| dt.with_timezone(&Utc))
}
