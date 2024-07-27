# Copyright 2024 M. I. E. ARDJOUNE
# SPDX-License-Identifier: Apache-2.0

import argparse
import sys
import os

try:
    import serial
except ImportError:
    print("This script needs python3-serial", file=sys.stderr)
    sys.exit(1)

W = 233
NBYTES = (W + 7) // 8
BAUD_RATE = 115_200

def k_to_bytes(k: int) -> bytes:
    if k < 0 or k >= (1 << W):
        raise ValueError(f"k must fit in {W} bits (got {k})")
    return k.to_bytes(NBYTES, byteorder="big")

def bytes_to_int(b: bytes) -> int:
    return int.from_bytes(b, byteorder="big")

def query(port: str, k: int, timeout: float = 5.0):
    with serial.Serial(port, BAUD_RATE, timeout=timeout) as ser:
        ser.write(k_to_bytes(k))
        ser.flush()

        response = ser.read(1 + 2 * NBYTES)
        if len(response) != 1 + 2 * NBYTES:
            raise TimeoutError(
                f"expected {1 + 2*NBYTES} bytes, got {len(response)} "
                "(check wiring, baud rate, and that the bitstream is loaded)"
            )

        status = response[0]
        qx = bytes_to_int(response[1:1 + NBYTES])
        qy = bytes_to_int(response[1 + NBYTES:1 + 2 * NBYTES])
        return (status == 0x01), qx, qy

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("port", help="serial port /dev/ttyUSB0")
    ap.add_argument("k", type=int, help="scalar to multiply by G")
    ap.add_argument("--check", action="store_true",
                     help="cross-verify against python_model/ instead of just printing")
    args = ap.parse_args()

    is_inf, qx, qy = query(args.port, args.k)

    if is_inf:
        print(f"k = {args.k}: point at infinity")
    else:
        print(f"k = {args.k}:")
        print(f"  x = {hex(qx)}")
        print(f"  y = {hex(qy)}")

    if args.check:
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python_model"))
        from ecc_gf2m import curve
        from ecc_gf2m.affine_ref import AffinePoint
        from ecc_gf2m import lopez_dahab as ld

        G = AffinePoint(curve.GX, curve.GY)
        expected = ld.scalar_mult(args.k, G)

        if is_inf != expected.is_infinity():
            print("MISMATCH: infinity flag disagrees with python_model")
            sys.exit(1)
        if not is_inf and (qx != expected.x or qy != expected.y):
            print("MISMATCH: FPGA result disagrees with python_model")
            print(f"  python_model x = {hex(expected.x)}")
            print(f"  python_model y = {hex(expected.y)}")
            sys.exit(1)
        print("OK: matches python_model")

if __name__ == "__main__":
    main()

