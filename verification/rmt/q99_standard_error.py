#!/usr/bin/env python3
"""
q99_standard_error.py — Standard error of the q99 quantile estimate.

Run with: python3 -u q99_standard_error.py

Calibration constants taken from the null calibration of
`calibration_modularity_output.txt` (N = 500, d_bar = 20,
N_H0 = 2000 replicates, seed 42), for the right-tail statistic
lambda_max(B) = s[-1] of Section 5.4:

    mean = 8.7679, std = 0.1115, q99 = 9.0542

The standard error of the sample quantile q99 is

    SE = sqrt(p(1-p)/N) / f(q99),   p = 0.99, N = 2000,

where f is the normal density at the empirical z-score of q99.
The script also reports the theoretical comparison at z = 2.326
(the standard normal 99th percentile), as quoted in Section 9.4.

These are the numbers reported in Section 9.4 and in the summary
table of Section 9.6.
"""

import numpy as np

P = 0.99
N_H0 = 2000
MEAN = 8.7679      # calibration_modularity_output.txt
STD = 0.1115
Q99 = 9.0542
Z_THEORY = 2.326   # standard normal 99th percentile


def se_at(z):
    """SE of the q99 estimate assuming the normal density at z."""
    phi = np.exp(-z**2 / 2.0) / np.sqrt(2.0 * np.pi)
    f_q99 = phi / STD
    return phi, f_q99, np.sqrt(P * (1 - P) / N_H0) / f_q99


def main():
    print("=" * 78)
    print("STANDARD ERROR OF THE q99 QUANTILE (lambda_max(B), s[-1])")
    print("=" * 78)
    print()
    print(f"Calibration: mean = {MEAN}, std = {STD}, q99 = {Q99}")
    print(f"N_H0 = {N_H0} replicates, p = {P}")
    print()

    z_emp = (Q99 - MEAN) / STD
    phi, f_q99, se = se_at(z_emp)

    print("EMPIRICAL z-SCORE OF q99")
    print(f"  z_emp   = ({Q99} - {MEAN}) / {STD} = {z_emp:.6f}")
    print(f"  phi(z)  = exp(-z^2/2)/sqrt(2*pi)   = {phi:.8f}")
    print(f"  f(q99)  = phi(z)/std               = {f_q99:.8f}")
    print()
    print("STANDARD ERROR")
    print(f"  sqrt(p(1-p)/N) = {np.sqrt(P * (1 - P) / N_H0):.8f}")
    print(f"  SE             = {se:.6f}")
    print(f"  SE / q99       = {se / Q99 * 100:.4f} %")
    print(f"  CI 95%         = [{Q99 - 1.96 * se:.6f}, {Q99 + 1.96 * se:.6f}]")
    print()

    phi_t, f_t, se_t = se_at(Z_THEORY)
    print(f"THEORETICAL COMPARISON (z = {Z_THEORY})")
    print(f"  phi(z)  = {phi_t:.8f}")
    print(f"  f(q99)  = {f_t:.8f}")
    print(f"  SE      = {se_t:.6f}")
    print(f"  SE / q99 = {se_t / Q99 * 100:.4f} %")
    print()
    print("=" * 78)
    print("Section 9.4 quotes: z-score 2.568, SE 0.017 (0.186%),")
    print("CI [9.021, 9.087], theoretical value 0.103%.")
    print("=" * 78)


if __name__ == "__main__":
    main()
