# Copyright 2024 M. I. E. ARDJOUNE
# SPDX-License-Identifier: Apache-2.0

from __future__ import annotations

M_DEGREE = 233
REDUCTION_POLY = (1 << 233) | (1 << 74) | 1

def deg(a: int) -> int:
    return a.bit_length() - 1

def gf_add(a: int, b: int) -> int:
    return a ^ b

def gf_mul(a: int, b: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    result = 0
    top_bit = 1 << m
    while a:
        if a & 1:
            result ^= b
        a >>= 1
        b <<= 1
        if b & top_bit:
            b ^= modulus
    return result

def gf_square(a: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    spread = 0
    i = 0
    while a:
        if a & 1:
            spread |= 1 << (2 * i)
        a >>= 1
        i += 1
    return _reduce(spread, modulus, m)

def _reduce(value: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    while deg(value) >= m:
        value ^= modulus << (deg(value) - m)
    return value

def gf_frobenius(a: int, k: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    for _ in range(k):
        a = gf_square(a, modulus, m)
    return a

def gf_pow(a: int, e: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    if e < 0:
        raise ValueError("negative exponent")
    result = 1
    base = a
    while e:
        if e & 1:
            result = gf_mul(result, base, modulus, m)
        base = gf_square(base, modulus, m)
        e >>= 1
    return result

def gf_inv_fermat(a: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    if a == 0:
        raise ZeroDivisionError("division by zero in GF(2^m)")
    return gf_pow(a, (1 << m) - 2, modulus, m)

def gf_inv_itoh_tsujii(a: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    if a == 0:
        raise ZeroDivisionError("division by zero in GF(2^m)")

    e = m - 1
    bits = bin(e)[2:]

    s = a
    k = 1
    for bit in bits[1:]:
        s = gf_mul(gf_frobenius(s, k, modulus, m), s, modulus, m)
        k *= 2
        if bit == "1":
            s = gf_mul(gf_frobenius(s, 1, modulus, m), a, modulus, m)
            k += 1
    assert k == e
    return gf_frobenius(s, 1, modulus, m)

gf_inv = gf_inv_itoh_tsujii

def gf_div(a: int, b: int, modulus: int = REDUCTION_POLY, m: int = M_DEGREE) -> int:
    return gf_mul(a, gf_inv(b, modulus, m), modulus, m)

def to_hex(a: int, nbits: int = M_DEGREE) -> str:
    return format(a, "0%dx" % ((nbits + 3) // 4))

def from_hex(s: str) -> int:
    return int(s, 16)

