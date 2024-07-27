
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

PACKAGE gf2m_pkg IS

    CONSTANT W : INTEGER := 233;

    CONSTANT REDUCTION_LOW : UNSIGNED(W-1 DOWNTO 0) :=
        (74 => '1', 0 => '1', OTHERS => '0');

    CONSTANT A2 : UNSIGNED(W-1 DOWNTO 0) := TO_UNSIGNED(1, W);

    FUNCTION xtimes(p : UNSIGNED(W-1 DOWNTO 0)) RETURN UNSIGNED;

    FUNCTION gf_square(a : UNSIGNED(W-1 DOWNTO 0)) RETURN UNSIGNED;

    FUNCTION mul_a2(x : UNSIGNED(W-1 DOWNTO 0)) RETURN UNSIGNED;

END PACKAGE gf2m_pkg;

PACKAGE BODY gf2m_pkg IS

    FUNCTION xtimes(p : UNSIGNED(W-1 DOWNTO 0)) RETURN UNSIGNED IS
        VARIABLE shifted : UNSIGNED(W DOWNTO 0);
    BEGIN
        shifted := p & '0';
        IF shifted(W) = '1' THEN
            RETURN shifted(W-1 DOWNTO 0) XOR REDUCTION_LOW;
        ELSE
            RETURN shifted(W-1 DOWNTO 0);
        END IF;
    END FUNCTION;

    FUNCTION gf_square(a : UNSIGNED(W-1 DOWNTO 0)) RETURN UNSIGNED IS
        VARIABLE wide : UNSIGNED(2*W-2 DOWNTO 0);
    BEGIN
        wide := (OTHERS => '0');
        FOR i IN 0 TO W-1 LOOP
            wide(2*i) := a(i);
        END LOOP;
        FOR i IN 2*W-2 DOWNTO W LOOP
            IF wide(i) = '1' THEN
                wide(i)      := '0';
                wide(i-W)    := wide(i-W)    XOR '1';
                wide(i-W+74) := wide(i-W+74) XOR '1';
            END IF;
        END LOOP;
        RETURN wide(W-1 DOWNTO 0);
    END FUNCTION;

    FUNCTION mul_a2(x : UNSIGNED(W-1 DOWNTO 0)) RETURN UNSIGNED IS
        VARIABLE zero : UNSIGNED(W-1 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        IF A2 = TO_UNSIGNED(1, W) THEN
            RETURN x;
        ELSE
            RETURN zero;
        END IF;
    END FUNCTION;

END PACKAGE BODY gf2m_pkg;
