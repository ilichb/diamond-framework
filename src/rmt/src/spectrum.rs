//! Symmetric spectra: the dense eigensolver M5 needs, and a second independent
//! one used to check it (plan §5.6).
//!
//! The detector needs three order statistics of a dense symmetric matrix — the
//! largest (`s[-1]`), the smallest (`s[0]`, reported negated as `−λ_min`) and the
//! second largest (`s[-2]`, the statistic the paper's `W`/`A_sym` rows use) — and
//! never an eigenvector. That is what makes the cheap exact path available:
//!
//! 1. [`tridiagonalize`] reduces the dense matrix to symmetric tridiagonal form
//!    with Householder reflections (the `tred2` reduction, *Numerical Recipes*
//!    2nd ed. §11.2, with the eigenvector accumulation dropped); `≈4n³/3` flops,
//!    and the only part whose cost grows with `n`;
//! 2. [`kth_largest`] bisects on the Sturm sequence of that tridiagonal
//!    (`O(n)` per step, ~60 steps for `f64`), returning any order statistic to
//!    the bisection tolerance — no shifts, no deflation, no iteration order to
//!    get wrong.
//!
//! [`jacobi_eigenvalues`] is the reference: the classic cyclic Jacobi algorithm
//! (quadratically convergent sweeps) computing the *whole* spectrum, affordable
//! only for small `n`. Two independent implementations agreeing on random
//! matrices is the check that the fast one is not silently wrong — the same
//! shape as M4c deciding `D-M4-0` on two variants instead of one estimate.

/// Householder reduction of a dense symmetric matrix to tridiagonal form.
///
/// `a` is `n × n`, row-major, symmetric, and is destroyed. On return `d[i]` is
/// the diagonal and `e[i]` the off-diagonal *above* row `i` (`e[0] = 0`), i.e.
/// the tridiagonal is `T[i][i] = d[i]`, `T[i][i±1] = e[i]`.
///
/// The transformation is the textbook one, applied block by block: at step `k`
/// the Householder vector `v` maps the column `x = A[k+1.., k]` onto
/// `α·e₁`, and the similarity `A ← (I − 2vvᵀ)A(I − 2vvᵀ)` is applied to the
/// trailing block as a rank-2 update, `B ← B − vwᵀ − wvᵀ` with
/// `w = 2Bv − 2(vᵀBv)v`. Two invariants make a transcription error impossible to
/// miss, and both are asserted in the tests: the trace and the Frobenius norm are
/// preserved (`Σd = tr A`, `Σd² + 2Σe² = ‖A‖_F²`).
pub fn tridiagonalize(n: usize, a: &mut [f64], d: &mut [f64], e: &mut [f64]) {
    assert_eq!(a.len(), n * n);
    assert_eq!(d.len(), n);
    assert_eq!(e.len(), n);
    d.fill(0.0);
    e.fill(0.0);
    if n == 0 {
        return;
    }
    let mut v = vec![0.0; n];
    let mut w = vec![0.0; n];
    for k in 0..n.saturating_sub(2) {
        let m = n - k - 1;
        let mut norm2 = 0.0;
        for (i, vi) in v[..m].iter_mut().enumerate() {
            *vi = a[(k + 1 + i) * n + k];
            norm2 += *vi * *vi;
        }
        let norm = norm2.sqrt();
        if norm == 0.0 {
            continue;
        }
        let alpha = if v[0] >= 0.0 { -norm } else { norm };
        v[0] -= alpha;
        let vnorm = v[..m].iter().map(|t| t * t).sum::<f64>().sqrt();
        for vi in v[..m].iter_mut() {
            *vi /= vnorm;
        }
        // p = 2·B·v, then w = p − (vᵀp)·v.
        for (i, wi) in w[..m].iter_mut().enumerate() {
            let row = (k + 1 + i) * n + k + 1;
            *wi = 2.0 * (0..m).map(|j| a[row + j] * v[j]).sum::<f64>();
        }
        let vp: f64 = (0..m).map(|i| v[i] * w[i]).sum();
        for i in 0..m {
            w[i] -= vp * v[i];
        }
        // B ← B − v·wᵀ − w·vᵀ.
        for i in 0..m {
            for j in 0..m {
                a[(k + 1 + i) * n + (k + 1 + j)] -= v[i] * w[j] + w[i] * v[j];
            }
        }
        // Row and column k: x ↦ α·e₁ fixes both by symmetry.
        a[k * n + (k + 1)] = alpha;
        a[(k + 1) * n + k] = alpha;
        for i in (k + 2)..n {
            a[k * n + i] = 0.0;
            a[i * n + k] = 0.0;
        }
    }
    for i in 0..n {
        d[i] = a[i * n + i];
    }
    for i in 1..n {
        e[i] = a[i * n + (i - 1)];
    }
}

/// Number of eigenvalues of the tridiagonal `(d, e)` strictly below `x` — the
/// Sturm sequence count.
///
/// A zero pivot is replaced by a tiny negative value, the standard guard
/// (*Numerical Recipes* §11.4): it keeps the recursion going and counts the pivot
/// once, which is what the count convention requires.
#[must_use]
pub fn sturm_count(d: &[f64], e: &[f64], x: f64) -> usize {
    let n = d.len();
    let mut count = 0;
    let mut q = d[0] - x;
    if q < 0.0 {
        count += 1;
    } else if q == 0.0 {
        q = -f64::MIN_POSITIVE;
        count += 1;
    }
    for i in 1..n {
        q = if e[i] == 0.0 {
            d[i] - x
        } else {
            d[i] - x - e[i] * e[i] / q
        };
        if q < 0.0 {
            count += 1;
        }
    }
    count
}

/// The `k`-th largest eigenvalue of the tridiagonal `(d, e)`, `k ≥ 1`.
///
/// Exact to the bisection tolerance `1e-13·‖T‖`, far below the four decimals the
/// sealed tables quote.
#[must_use]
pub fn kth_largest(d: &[f64], e: &[f64], k: usize) -> f64 {
    let n = d.len();
    assert!(k >= 1 && k <= n, "k = {k} is out of 1..={n}");
    // |λ| ≤ ‖T‖_∞ ≤ max_i (|d_i| + |e_i| + |e_{i+1}|).
    let mut bound = 0.0f64;
    for i in 0..n {
        let next = if i + 1 < n { e[i + 1].abs() } else { 0.0 };
        bound = bound.max(d[i].abs() + e[i].abs() + next);
    }
    if bound == 0.0 {
        return 0.0;
    }
    // The k-th largest is the (n - k + 1)-th smallest; bisect for the point where
    // the Sturm count reaches it.
    let target = n - k + 1;
    let tolerance = 1e-13 * bound;
    let mut lo = -bound;
    let mut hi = bound;
    for _ in 0..200 {
        let mid = 0.5 * (lo + hi);
        if sturm_count(d, e, mid) < target {
            lo = mid;
        } else {
            hi = mid;
        }
        if hi - lo <= tolerance {
            break;
        }
    }
    0.5 * (lo + hi)
}

/// All eigenvalues of a dense symmetric matrix, by cyclic Jacobi rotations.
///
/// The reference implementation: `O(n³)` per sweep, `8`–`12` sweeps, so it is
/// used in tests as a cross-check of [`kth_largest`], never in the calibration
/// loop.
#[must_use]
pub fn jacobi_eigenvalues(n: usize, a: &mut [f64]) -> Vec<f64> {
    assert_eq!(a.len(), n * n);
    if n == 0 {
        return Vec::new();
    }
    let norm = a.iter().fold(0.0f64, |m, x| m.max(x.abs()));
    let threshold = 1e-15 * norm;
    for _ in 0..100 {
        let mut off = 0.0;
        for p in 0..n {
            for q in (p + 1)..n {
                off += a[p * n + q] * a[p * n + q];
            }
        }
        if off.sqrt() <= threshold {
            break;
        }
        for p in 0..n.saturating_sub(1) {
            for q in (p + 1)..n {
                let apq = a[p * n + q];
                if apq.abs() <= threshold {
                    continue;
                }
                let theta = (a[q * n + q] - a[p * n + p]) / (2.0 * apq);
                let t = if theta == 0.0 {
                    1.0
                } else {
                    theta.signum() / (theta.abs() + (theta * theta + 1.0).sqrt())
                };
                let c = 1.0 / (t * t + 1.0).sqrt();
                let s = t * c;
                // A ← Gᵀ A G for the (p, q) rotation.
                for k in 0..n {
                    let akp = a[k * n + p];
                    let akq = a[k * n + q];
                    a[k * n + p] = c * akp - s * akq;
                    a[k * n + q] = s * akp + c * akq;
                }
                for k in 0..n {
                    let apk = a[p * n + k];
                    let aqk = a[q * n + k];
                    a[p * n + k] = c * apk - s * aqk;
                    a[q * n + k] = s * apk + c * aqk;
                }
            }
        }
    }
    (0..n).map(|i| a[i * n + i]).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row_major(n: usize, f: impl Fn(usize, usize) -> f64) -> Vec<f64> {
        let mut a = vec![0.0; n * n];
        for i in 0..n {
            for j in 0..n {
                a[i * n + j] = f(i, j);
            }
        }
        a
    }

    fn assert_close(got: f64, want: f64, tol: f64, what: &str) {
        assert!(
            (got - want).abs() <= tol,
            "{what}: got {got}, want {want} (tol {tol})"
        );
    }

    fn tridiagonal(dense: &[f64], n: usize) -> (Vec<f64>, Vec<f64>) {
        let mut t = dense.to_vec();
        let (mut d, mut e) = (vec![0.0; n], vec![0.0; n]);
        tridiagonalize(n, &mut t, &mut d, &mut e);
        (d, e)
    }

    /// The two solvers must agree on the three statistics the detector uses.
    fn cross_check(n: usize, dense: &[f64]) {
        let mut for_jacobi = dense.to_vec();
        let mut all = jacobi_eigenvalues(n, &mut for_jacobi);
        all.sort_by(f64::total_cmp);
        let (d, e) = tridiagonal(dense, n);
        let tol = 1e-9 * dense.iter().fold(1.0f64, |m, x| m.max(x.abs()));
        assert_close(kth_largest(&d, &e, 1), all[n - 1], tol, "λ_max");
        assert_close(kth_largest(&d, &e, n), all[0], tol, "λ_min");
        assert_close(kth_largest(&d, &e, 2), all[n - 2], tol, "s[-2]");
    }

    fn modularity_of(adjacency: &[f64], n: usize) -> Vec<f64> {
        let deg: Vec<f64> = (0..n)
            .map(|i| (0..n).map(|j| adjacency[i * n + j]).sum())
            .collect();
        let two_m: f64 = deg.iter().sum();
        let mut b = adjacency.to_vec();
        for i in 0..n {
            for j in 0..n {
                b[i * n + j] -= deg[i] * deg[j] / two_m;
            }
        }
        b
    }

    #[test]
    fn two_by_two_is_analytic() {
        let (d, e) = tridiagonal(&[1.0, 2.0, 2.0, 1.0], 2);
        assert_close(kth_largest(&d, &e, 1), 3.0, 1e-11, "λ_max");
        assert_close(kth_largest(&d, &e, 2), -1.0, 1e-11, "λ_min");
    }

    /// The reduction is a similarity, so both invariants must survive it; a
    /// transcription error in the Householder step shows up here immediately.
    #[test]
    fn reduction_preserves_trace_and_frobenius_norm() {
        let mut seed = 0x9e37_79b9_7f4a_7c15u64;
        let mut next = move || {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            (seed >> 11) as f64 / (1u64 << 53) as f64 - 0.5
        };
        for n in [2usize, 3, 8, 25] {
            let mut a = vec![0.0; n * n];
            for i in 0..n {
                for j in i..n {
                    let v = next();
                    a[i * n + j] = v;
                    a[j * n + i] = v;
                }
            }
            let trace: f64 = (0..n).map(|i| a[i * n + i]).sum();
            let frob2: f64 = a.iter().map(|x| x * x).sum();
            let (d, e) = tridiagonal(&a, n);
            assert_close(d.iter().sum(), trace, 1e-10, "trace");
            let reduced: f64 = d.iter().map(|x| x * x).sum::<f64>()
                + 2.0 * e[1..].iter().map(|x| x * x).sum::<f64>();
            assert_close(reduced, frob2, 1e-10, "Frobenius norm");
        }
    }

    #[test]
    fn diagonal_matrix_returns_its_diagonal() {
        let n = 7;
        let a = row_major(n, |i, j| if i == j { i as f64 - 3.0 } else { 0.0 });
        cross_check(n, &a);
        let (d, e) = tridiagonal(&a, n);
        assert_close(kth_largest(&d, &e, 1), 3.0, 1e-11, "λ_max");
        assert_close(kth_largest(&d, &e, 2), 2.0, 1e-11, "s[-2]");
    }

    #[test]
    fn cycle_graph_is_analytic() {
        // C_n is 2-regular, spec(A) = {2cos(2πk/n)}; with B = A − (2/n)J,
        // spec(B) = {0} ∪ (spec(A) without the Perron value 2).
        let n = 12;
        let a = row_major(n, |i, j| {
            if (i + 1) % n == j || (i + n - 1) % n == j {
                1.0
            } else {
                0.0
            }
        });
        cross_check(n, &a);
        let (d, e) = tridiagonal(&modularity_of(&a, n), n);
        let lambda2 = 2.0 * (2.0 * std::f64::consts::PI / n as f64).cos();
        assert_close(kth_largest(&d, &e, 1), lambda2, 1e-12, "λ_max(B) = λ₂(C_n)");
        assert_close(kth_largest(&d, &e, n), -2.0, 1e-12, "λ_min(B)");
    }

    #[test]
    fn complete_graph_modularity_is_minus_one() {
        // K_n: A = J − I is (n−1)-regular, so spec(B) = {0} ∪ {−1}^(n−1).
        let n = 9;
        let a = row_major(n, |i, j| if i == j { 0.0 } else { 1.0 });
        cross_check(n, &a);
        let (d, e) = tridiagonal(&modularity_of(&a, n), n);
        assert_close(kth_largest(&d, &e, 1), 0.0, 1e-12, "λ_max(B)");
        assert_close(kth_largest(&d, &e, n), -1.0, 1e-12, "λ_min(B)");
    }

    #[test]
    fn sturm_count_is_monotone_and_saturates() {
        let n = 6;
        let a = row_major(n, |i, j| if i == j { 0.0 } else { 1.0 });
        let (d, e) = tridiagonal(&a, n);
        assert_eq!(sturm_count(&d, &e, -10.0), 0);
        assert_eq!(sturm_count(&d, &e, 10.0), n);
        assert!(sturm_count(&d, &e, -10.0) <= sturm_count(&d, &e, 0.0));
    }

    #[test]
    fn random_matrices_cross_check_both_solvers() {
        // A deterministic LCG keeps the test reproducible without a dependency.
        let mut seed = 0x2545_f491_4f6c_dd1du64;
        let mut next = move || {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            (seed >> 11) as f64 / (1u64 << 53) as f64 - 0.5
        };
        for n in [3usize, 5, 10, 31] {
            let mut a = vec![0.0; n * n];
            for i in 0..n {
                for j in i..n {
                    let v = next();
                    a[i * n + j] = v;
                    a[j * n + i] = v;
                }
            }
            cross_check(n, &a);
        }
    }
}
