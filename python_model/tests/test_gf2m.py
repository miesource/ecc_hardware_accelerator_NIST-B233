# Copyright 2024 M. I. E. ARDJOUNE
# SPDX-License-Identifier: Apache-2.0

import random
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from ecc_gf2m import gf2m

def test_reduction_poly_degree():
    assert gf2m.deg(gf2m.REDUCTION_POLY) == 233

def test_add_is_involution():
    a, b = 0x1234, 0x5678
    assert gf2m.gf_add(gf2m.gf_add(a, b), b) == a

def test_mul_identity_and_zero():
    a = 0xABCDEF
    assert gf2m.gf_mul(a, 1) == a
    assert gf2m.gf_mul(a, 0) == 0

def test_square_equals_self_mul():
    random.seed(0)
    for _ in range(30):
        a = random.getrandbits(233)
        assert gf2m.gf_square(a) == gf2m.gf_mul(a, a)

def test_inversion_methods_agree_and_are_correct():
    random.seed(1)
    for _ in range(30):
        a = random.getrandbits(233) | 1
        inv_fermat = gf2m.gf_inv_fermat(a)
        inv_it = gf2m.gf_inv_itoh_tsujii(a)
        assert inv_fermat == inv_it
        assert gf2m.gf_mul(a, inv_fermat) == 1

def test_multiplication_known_vector():
    X = gf2m.from_hex(
        "17232ba853a7e731af129f22ff4149563a419c26bf50a4c9d6eefad6125"
    )
    Y = gf2m.from_hex(
        "1db537dece819b7f70f555a67c427a8cd9bf18aeb9b56e0c11056fae6a3"
    )
    expected = 1232761663023842701192332416837059201183844051351072756030583524702510
    assert gf2m.gf_mul(X, Y) == expected

def test_division_known_vector():
    X = gf2m.from_hex(
        "17232ba853a7e731af129f22ff4149563a419c26bf50a4c9d6eefad6125"
    )
    Y = gf2m.from_hex(
        "1db537dece819b7f70f555a67c427a8cd9bf18aeb9b56e0c11056fae6a3"
    )
    expected = 2570922841623211019099852390574171267277165253035607709456926323351571
    assert gf2m.gf_div(X, Y) == expected

