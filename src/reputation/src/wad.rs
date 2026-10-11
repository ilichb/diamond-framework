//! The WAD arithmetic of `AVIPValidatorManager.collateralFor`.
//!
//! §5.7 puts it plainly: M2 already ships the deployed reader of `C_R`, so M6's
//! obligation is **parity with it**, not a second decision. Solidity evaluates
//!
//! ```text
//! collateralFor(norm)    = (CR_INF * norm) / (ONE + norm)      // 256-bit, floors
//! requiredStakeFor(norm) = max(S_MIN, THETA - collateralFor(norm))
//! ```
//!
//! and the intermediate is 256-bit: `CR_INF · norm` for a large `norm` needs more
//! than 128 bits, so a `u128` multiply would silently wrap. This module carries the
//! product as four 64-bit limbs and divides it by the denominator with binary long
//! division — the value the EVM computes, computed without the EVM.
//!
//! `fixtures/wad_vectors.txt` holds the same expressions evaluated in Python's
//! arbitrary-precision integers, and the frozen contract's own Foundry tests pin
//! the two values at `r = Θ_R = 0.5`:
//! `collateralFor(5e17) = 266666666666666666`,
//! `requiredStakeFor(5e17) = 733333333333333334`.

/// The WAD unit, `1e18` (`AVIPValidatorManager.ONE`).
pub const ONE: u128 = 1_000_000_000_000_000_000;

/// `Θ`: the admission threshold (`AVIPValidatorManager.THETA`).
pub const THETA: u128 = ONE;

/// `C_R^∞ = 0.8` (`AVIPValidatorManager.CR_INF`).
pub const CR_INF: u128 = 800_000_000_000_000_000;

/// `S_min = 0.2` (`AVIPValidatorManager.S_MIN`).
pub const S_MIN: u128 = 200_000_000_000_000_000;

/// `Θ_R = 0.5`: the norm threshold above which admission is allowed.
pub const THETA_R: u128 = 500_000_000_000_000_000;

/// The largest norm this reader accepts: `ONE + norm <= 2¹²⁷ − 1`, the widest
/// divisor [`div_256_by_u128`] can shift without overflowing.
///
/// Reputation norms are `O(1)` WAD, so the bound is nowhere near binding in the
/// deployed domain (`Θ_R` is `5e17`, and this is `1.7e38`); it is stated as a
/// constant so that the refusal is a statement about the domain rather than
/// about an internal shift.
pub const MAX_NORM: u128 = (u128::MAX >> 1) - ONE;

/// `collateralFor(norm)`, in WAD, with the EVM's 256-bit intermediate.
///
/// # Panics
/// If `norm > MAX_NORM` — see [`MAX_NORM`].
#[must_use]
pub fn collateral_for(norm: u128) -> u128 {
    assert!(norm <= MAX_NORM, "a WAD norm is at most {MAX_NORM}");
    mul_div_256(CR_INF, norm, ONE + norm)
}

/// `requiredStakeFor(norm) = max{S_min, Θ − C_R(norm)}`.
///
/// With the deployed constants the clamp never binds for a finite `norm`:
/// `Θ − C_R(r) > Θ − C_R^∞ = S_MIN` for every finite `r` because the closed form
/// is strictly concave and saturates only in the limit. The `max` is M2's safety
/// net, and the saturation test below is what keeps that reasoning honest.
#[must_use]
pub fn required_stake_for(norm: u128) -> u128 {
    let stake = THETA - collateral_for(norm);
    if stake > S_MIN { stake } else { S_MIN }
}

/// `floor(a · b / d)` with a 256-bit intermediate.
///
/// # Panics
/// If `d == 0`; if the quotient needs more than 128 bits — the WAD reader's
/// quotient never exceeds `CR_INF`; or if `d > 2¹²⁷` **and** the running
/// remainder grows to `2¹²⁷`. The deployed domain keeps `d = ONE + norm` at most
/// `2¹²⁷ − 1` ([`MAX_NORM`]), where `rem < d` makes that shift unreachable.
#[must_use]
pub fn mul_div_256(a: u128, b: u128, d: u128) -> u128 {
    assert!(d != 0, "division by zero");
    div_256_by_u128(&mul_wide(a, b), d)
}

/// `a · b` as four little-endian 64-bit limbs.
fn mul_wide(a: u128, b: u128) -> [u64; 4] {
    let a_lo = a as u64;
    let a_hi = (a >> 64) as u64;
    let b_lo = b as u64;
    let b_hi = (b >> 64) as u64;
    let mut acc = [0_u64; 4];
    add_at(&mut acc, u128::from(a_lo) * u128::from(b_lo), 0);
    add_at(&mut acc, u128::from(a_lo) * u128::from(b_hi), 1);
    add_at(&mut acc, u128::from(a_hi) * u128::from(b_lo), 1);
    add_at(&mut acc, u128::from(a_hi) * u128::from(b_hi), 2);
    acc
}

/// Add a 128-bit value into a 256-bit accumulator at limb `offset`.
fn add_at(acc: &mut [u64; 4], add: u128, offset: usize) {
    let mut carry = add;
    let mut i = offset;
    while carry != 0 {
        assert!(i < 4, "256-bit overflow in a WAD product");
        let sum = u128::from(acc[i]) + (carry & u128::from(u64::MAX));
        acc[i] = sum as u64;
        carry = (carry >> 64) + (sum >> 64);
        i += 1;
    }
}

/// Long division of a 256-bit number by a `u128` divisor, bit by bit from the top.
///
/// `rem < d <= 2^127` cannot overflow `rem << 1`; the assertion states that
/// precondition, and [`MAX_NORM`] is what keeps the WAD reader inside it.
fn div_256_by_u128(n: &[u64; 4], d: u128) -> u128 {
    let mut quotient: u128 = 0;
    let mut rem: u128 = 0;
    for bit in (0..256).rev() {
        assert!(rem <= (u128::MAX >> 1), "remainder shift would overflow");
        rem = (rem << 1) | u128::from((n[bit / 64] >> (bit % 64)) & 1);
        if rem >= d {
            rem -= d;
            if bit < 128 {
                quotient |= 1 << bit;
            } else {
                panic!("quotient exceeds a u128");
            }
        }
    }
    quotient
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The same expressions evaluated in Python's arbitrary-precision integers,
    /// i.e. the value the EVM's 256-bit arithmetic produces.
    const FIXTURE: &str = include_str!("../fixtures/wad_vectors.txt");

    /// `(norm, collateral, required_stake)` rows of the fixture.
    fn vectors() -> Vec<(u128, u128, u128)> {
        FIXTURE
            .lines()
            .filter(|l| !l.trim_start().starts_with('#') && !l.trim().is_empty())
            .filter_map(|l| {
                let mut fields = l.split_whitespace();
                let norm = fields.next()?;
                // the column header has no numeric first field
                if norm == "norm_wad" {
                    return None;
                }
                let collateral = fields.next().expect("a collateral column");
                let stake = fields.next().expect("a stake column");
                Some((
                    norm.parse().expect("a WAD norm"),
                    collateral.parse().expect("a WAD collateral"),
                    stake.parse().expect("a WAD stake"),
                ))
            })
            .collect()
    }

    #[test]
    fn wad_vectors_match_python_integers() {
        let rows = vectors();
        assert_eq!(rows.len(), 8, "the fixture has eight rows");
        for (norm, collateral, stake) in rows {
            assert_eq!(collateral_for(norm), collateral, "collateralFor({norm})");
            assert_eq!(required_stake_for(norm), stake, "requiredStakeFor({norm})");
        }
    }

    /// The two values the frozen contract's own Foundry tests pin.
    #[test]
    fn the_deployed_reader_pins_theta_r() {
        assert_eq!(THETA_R, 500_000_000_000_000_000);
        assert_eq!(collateral_for(THETA_R), 266_666_666_666_666_666);
        assert_eq!(required_stake_for(THETA_R), 733_333_333_333_333_334);
    }

    #[test]
    fn collateral_is_increasing_and_never_reaches_its_limit() {
        let mut previous = collateral_for(0);
        assert_eq!(previous, 0);
        for norm in [
            1_u128,
            THETA_R,
            ONE,
            4 * ONE,
            1_000 * ONE,
            1_000_000_000 * ONE,
        ] {
            let c = collateral_for(norm);
            assert!(c >= previous, "C_R must not decrease at {norm}");
            assert!(c < CR_INF, "C_R({norm}) must stay below C_R^inf");
            previous = c;
        }
        assert_eq!(collateral_for(1_000_000_000 * ONE), 799_999_999_200_000_000);
        // The limit is approached, never reached: even at the largest admissible
        // norm, `C_R` is one WAD ulp short of `C_R^∞`.
        assert_eq!(collateral_for(MAX_NORM), CR_INF - 1);
        assert!(collateral_for(MAX_NORM) > previous);
    }

    #[test]
    fn the_domain_ends_where_the_divisor_reaches_two_to_the_127() {
        assert_eq!(MAX_NORM, (u128::MAX >> 1) - ONE);
        assert_eq!(ONE + MAX_NORM, u128::MAX >> 1, "the widest safe divisor");
        assert_eq!(collateral_for(MAX_NORM), 799_999_999_999_999_999);
        assert_eq!(required_stake_for(MAX_NORM), 200_000_000_000_000_001);
    }

    #[test]
    #[should_panic(expected = "a WAD norm is at most")]
    fn a_norm_beyond_the_domain_is_refused() {
        let _ = collateral_for(MAX_NORM + 1);
    }

    #[test]
    fn the_stake_floor_never_binds_at_any_admissible_norm() {
        // The comment on `required_stake_for` claims the clamp is unreachable
        // with the deployed constants; this is what keeps that comment honest.
        for norm in [0_u128, 1, THETA_R, ONE, 1_000_000_000 * ONE, MAX_NORM] {
            let stake = required_stake_for(norm);
            assert!(stake > S_MIN, "the floor bound at {norm}");
            assert_eq!(stake, THETA - collateral_for(norm));
        }
        // Both ends of the range, pinned: the clamp is slack by 1 WAD ulp even
        // where `C_R` is closest to its asymptote.
        assert_eq!(required_stake_for(0), THETA);
        assert_eq!(required_stake_for(MAX_NORM), S_MIN + 1);
    }

    #[test]
    fn mul_div_matches_native_arithmetic_when_the_product_fits() {
        for (a, b, d) in [
            (7_u128, 3, 2),
            (CR_INF, THETA_R, ONE + THETA_R),
            (CR_INF, 1_000, ONE + 1_000),
            (u128::MAX / 4, 4, u128::MAX),
        ] {
            assert_eq!(mul_div_256(a, b, d), a * b / d, "{a}*{b}/{d}");
        }
    }

    #[test]
    fn mul_div_survives_a_product_that_overflows_u128() {
        // CR_INF * 2^127 needs 187 bits: a u128 multiply would wrap.
        assert!(CR_INF.checked_mul(1_u128 << 127).is_none());
        assert_eq!(mul_div_256(CR_INF, 1_u128 << 127, 1_u128 << 127), CR_INF);
        // 3 * 2^127 needs 129 bits, so this quotient only the wide path can get
        assert!(3_u128.checked_mul(1_u128 << 127).is_none());
        assert_eq!(mul_div_256(1_u128 << 127, 3, 1_u128 << 127), 3);
        // and it floors, like Solidity's `/`
        assert_eq!(mul_div_256(10, 10, 3), 33);
        assert_eq!(mul_div_256(100, 100, 7), 1_428);
    }

    /// The widest product the limb multiply can be handed: `(2¹²⁸ − 1)²` is
    /// `2²⁵⁶ − 2¹²⁹ + 1`, which still fits 256 bits, so `add_at`'s overflow
    /// assertion is unreachable for `u128` inputs — as it should be.
    #[test]
    fn a_product_of_two_maximal_norms_still_fits_256_bits() {
        let product = mul_wide(u128::MAX, u128::MAX);
        assert_eq!(product, [1, 0, u64::MAX - 1, u64::MAX]);
        assert!(
            u128::MAX.checked_mul(u128::MAX).is_none(),
            "not in 128 bits"
        );
    }

    /// The reader's own domain keeps `d = ONE + norm` at `2¹²⁷ − 1` or below, so
    /// the long division's `rem < d` invariant is what makes `rem << 1` safe; a
    /// divisor beyond that is where the guard becomes visible.
    #[test]
    fn every_divisor_the_reader_can_reach_keeps_the_shift_safe() {
        for norm in [0_u128, 1, THETA_R, ONE, MAX_NORM] {
            let d = ONE + norm;
            assert!(d <= u128::MAX >> 1, "the domain's widest divisor, {d}");
            let _ = mul_div_256(CR_INF, norm, d);
        }
    }

    #[test]
    #[should_panic(expected = "remainder shift would overflow")]
    fn a_divisor_wider_than_two_to_the_127_is_outside_the_precondition() {
        let _ = mul_div_256(1_u128 << 127, 2, (1_u128 << 127) + 1);
    }

    #[test]
    #[should_panic(expected = "quotient exceeds a u128")]
    fn a_quotient_that_exceeds_a_u128_is_refused() {
        // (2^128 - 1)^2 / 2^127 needs 129 bits.
        let _ = mul_div_256(u128::MAX, u128::MAX, 1_u128 << 127);
    }
}
