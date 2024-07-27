# Copyright 2024 M. I. E. ARDJOUNE
# SPDX-License-Identifier: Apache-2.0

from .gf2m import from_hex

M = 233

A = from_hex(
    "000000000000000000000000000000000000000000000000000000000001"
)
A2 = 1

B = from_hex(
    "0066647ede6c332c7f8c0923bb58213b333b20e9ce4281fe115f7d8f90ad"
)

GX = from_hex(
    "00fac9dfcbac8313bb2139f1bb755fef65bc391f8b36f8f8eb7371fd558b"
)
GY = from_hex(
    "01006a08a41903350678e58528bebf8a0beff867a7ca36716f7e01f81052"
)

N = int(
    "01000000000000000000000000000013e974e72f8a6922031d2603cfe0d7", 16
)

H = 2

