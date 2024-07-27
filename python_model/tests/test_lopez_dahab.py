# Copyright 2024 M. I. E. ARDJOUNE
# SPDX-License-Identifier: Apache-2.0

import random
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from ecc_gf2m import curve
from ecc_gf2m.affine_ref import (
    AffinePoint,
    is_on_curve,
    add as aff_add,
    double as aff_double,
    negate,
    scalar_mult as aff_scalar_mult,
    O,
)
from ecc_gf2m import lopez_dahab as ld

G = AffinePoint(curve.GX, curve.GY)

def test_generator_is_on_curve():
    assert is_on_curve(G)

def test_ld_double_matches_affine_double():
    g2_affine = aff_double(G)
    g2_ld = ld.to_affine(ld.ld_double(ld.to_ld(G)))
    assert g2_affine == g2_ld
    assert is_on_curve(g2_ld)

def test_ld_add_matches_affine_add():
    g2 = aff_double(G)
    g3_affine = aff_add(G, g2)
    g3_ld = ld.to_affine(ld.ld_add(ld.to_ld(G), ld.to_ld(g2)))
    assert g3_affine == g3_ld
    assert is_on_curve(g3_ld)

def test_scalar_mult_matches_affine_reference_random_scalars():
    random.seed(7)
    for _ in range(10):
        k = random.randrange(1, curve.N)
        assert aff_scalar_mult(k, G) == ld.scalar_mult(k, G)

def test_order_times_generator_is_infinity():
    assert ld.scalar_mult(curve.N, G).is_infinity()
    assert aff_scalar_mult(curve.N, G).is_infinity()

def test_n_minus_1_times_generator_is_negation():
    assert ld.scalar_mult(curve.N - 1, G) == negate(G)

def test_naive_scalar_mult_breaks_as_documented():
    import pytest

    with pytest.raises(ValueError):
        ld.scalar_mult_naive(12345, G)

def test_known_answer_scalar_mult_vectors():
    vectors = {
        2: (
            "845fd61638bac7d9e109a67a1f7047dc0fd9a5488a8468364bdc592aad",
            "1b1420774abba2587c83900984765a8a85d776325fc39cc7823d734660",
        ),
        3: (
            "80f50a330911bd753a76364595b9f0158c4d02a85cc0e3fb6ea0aef9ff",
            "17a49033f12eb52675e98e6432cc27104bd5c42bcbe3daf76901c9b8743",
        ),
        5: (
            "194ed0ca60c85e59e7c4b69f30c6304a9f485f45032b871c4a23ffec8c1",
            "a52f9459c2fab39c214061e272e1e115e1e01a98e4f09cd5a85d2698c6",
        ),
        12345: (
            "171cdbf80d4cf050fafeea2b01039d6ae34aca712ff64ec8037a8496138",
            "13449a47f49a1f7bfbafa5ed0d36958e5f36d3be206adf07262f79bc2e1",
        ),
    }
    for k, (xh, yh) in vectors.items():
        R = ld.scalar_mult(k, G)
        assert R.x == int(xh, 16)
        assert R.y == int(yh, 16)

    Rm1 = ld.scalar_mult(curve.N - 1, G)
    assert Rm1.x == curve.GX
    assert Rm1.y == int(
        "1faa3d76fb58026bd59dc7493cbe0656e53c1782cfcce89840d700545d9", 16
    )

def test_naive_y_conversion_is_wrong_in_general():
    doubled = ld.ld_double(ld.to_ld(G))
    correct = ld.to_affine(doubled)
    naive = ld.to_affine_naive(doubled)
    assert doubled.Z != 1
    assert correct.y != naive.y

