
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY gf2m_mult_serial_tb IS
END ENTITY gf2m_mult_serial_tb;

ARCHITECTURE sim OF gf2m_mult_serial_tb IS
    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL rst_n : STD_LOGIC;
    SIGNAL start : STD_LOGIC := '0';
    SIGNAL a_in, b_in, product : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL busy, done : STD_LOGIC;
    SIGNAL errors : INTEGER := 0;
BEGIN

    UUT : ENTITY work.gf2m_mult_serial
        PORT MAP (clk, rst_n, start, a_in, b_in, busy, done, product);

    clk <= NOT clk AFTER 5 ns;

    STIM : PROCESS
        PROCEDURE run_case(a, b, expected : UNSIGNED(W-1 DOWNTO 0); name : STRING) IS
        BEGIN
            WAIT UNTIL RISING_EDGE(clk);
            a_in <= a;
            b_in <= b;
            start <= '1';
            WAIT UNTIL RISING_EDGE(clk);
            start <= '0';
            WAIT UNTIL done = '1';
            WAIT UNTIL RISING_EDGE(clk);
            IF product = expected THEN
                REPORT "[PASS] " & name;
            ELSE
                REPORT "[FAIL] " & name SEVERITY ERROR;
                errors <= errors + 1;
            END IF;
        END PROCEDURE;
    BEGIN
        rst_n <= '0';
        start <= '0';
        a_in  <= (OTHERS => '0');
        b_in  <= (OTHERS => '0');
        WAIT FOR 30 ns;
        rst_n <= '1';

        run_case(
            233X"17232ba853a7e731af129f22ff4149563a419c26bf50a4c9d6eefad6125",
            233X"1db537dece819b7f70f555a67c427a8cd9bf18aeb9b56e0c11056fae6a3",
            233X"02db9c59a4bbf539e65d0174b12a0c30657655eeacb017a3d4466d2392e",
            "X*Y"
        );

        run_case(233X"ABCDEF", TO_UNSIGNED(1, W), 233X"ABCDEF", "a*1 == a");
        run_case(233X"ABCDEF", TO_UNSIGNED(0, W), TO_UNSIGNED(0, W), "a*0 == 0");

        run_case(
            233X"17232ba853a7e731af129f22ff4149563a419c26bf50a4c9d6eefad6125",
            233X"17232ba853a7e731af129f22ff4149563a419c26bf50a4c9d6eefad6125",
            233X"113bcafec38a1e9f284bec901039e7f0d4bc3b7a1ebd2526abed8419d34",
            "X*X == X^2"
        );

        IF errors = 0 THEN
            REPORT "ALL TESTS PASSED (gf2m_mult_serial)";
        ELSE
            REPORT INTEGER'IMAGE(errors) & " TEST(S) FAILED (gf2m_mult_serial)" SEVERITY ERROR;
        END IF;

        STD.ENV.STOP;
        WAIT;
    END PROCESS;

END ARCHITECTURE sim;
