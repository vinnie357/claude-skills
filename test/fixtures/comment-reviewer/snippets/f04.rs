/// Applies `delta` to `balance_cents` and returns the resulting balance.
/// In a release build, `i64` addition overflow wraps via two's complement
/// instead of panicking — an out-of-range `delta` silently corrupts the
/// balance rather than raising an error.
pub fn apply_delta(balance_cents: i64, delta: i64) -> i64 {
    balance_cents + delta
}
