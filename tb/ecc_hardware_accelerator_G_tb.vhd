
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY ecc_hardware_accelerator_G_tb IS
END ENTITY ecc_hardware_accelerator_G_tb;

ARCHITECTURE sim OF ecc_hardware_accelerator_G_tb IS

    CONSTANT KBITS : INTEGER := W;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL rst_n : STD_LOGIC;
    SIGNAL start : STD_LOGIC := '0';
    SIGNAL k_in  : UNSIGNED(KBITS-1 DOWNTO 0);
    SIGNAL k_len : INTEGER RANGE 0 TO KBITS;
    SIGNAL px_in, py_in : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL busy, done, result_is_infinity : STD_LOGIC;
    SIGNAL qx_out, qy_out : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL errors : INTEGER := 0;

    CONSTANT GX : UNSIGNED(W-1 DOWNTO 0) :=
        233X"0fac9dfcbac8313bb2139f1bb755fef65bc391f8b36f8f8eb7371fd558b";
    CONSTANT GY : UNSIGNED(W-1 DOWNTO 0) :=
        233X"1006a08a41903350678e58528bebf8a0beff867a7ca36716f7e01f81052";

BEGIN

    DUT : ENTITY work.ecc_hardware_accelerator_G
        GENERIC MAP (KBITS => KBITS)
        PORT MAP (
            clk => clk, rst_n => rst_n, start => start,
            k_in => k_in, k_len => k_len, px_in => px_in, py_in => py_in,
            busy => busy, done => done, result_is_infinity => result_is_infinity,
            qx_out => qx_out, qy_out => qy_out
        );

    clk <= NOT clk AFTER 5 ns;

    STIM : PROCESS
        PROCEDURE run_case(k : UNSIGNED(KBITS-1 DOWNTO 0); len : INTEGER;
                            exp_x, exp_y : UNSIGNED(W-1 DOWNTO 0); name : STRING) IS
        BEGIN
            WAIT UNTIL RISING_EDGE(clk);
            k_in  <= k;
            k_len <= len;
            px_in <= GX;
            py_in <= GY;
            start <= '1';
            WAIT UNTIL RISING_EDGE(clk);
            start <= '0';
            WAIT UNTIL done = '1';
            WAIT UNTIL RISING_EDGE(clk);
            IF result_is_infinity = '1' THEN
                REPORT "[FAIL] " & name & ": got point at infinity, expected a finite point" SEVERITY ERROR;
                errors <= errors + 1;
            ELSIF qx_out /= exp_x OR qy_out /= exp_y THEN
                REPORT "[FAIL] " & name SEVERITY ERROR;
                errors <= errors + 1;
            ELSE
                REPORT "[PASS] " & name;
            END IF;
        END PROCEDURE;
    BEGIN
        rst_n <= '0';
        start <= '0';
        k_in <= (OTHERS => '0'); k_len <= 0;
        px_in <= (OTHERS => '0'); py_in <= (OTHERS => '0');
        WAIT FOR 30 ns;
        rst_n <= '1';

        run_case(TO_UNSIGNED(2, KBITS), 2,
            233X"0845fd61638bac7d9e109a67a1f7047dc0fd9a5488a8468364bdc592aad",
            233X"01b1420774abba2587c83900984765a8a85d776325fc39cc7823d734660",
            "2*G");

        run_case(TO_UNSIGNED(3, KBITS), 2,
            233X"080f50a330911bd753a76364595b9f0158c4d02a85cc0e3fb6ea0aef9ff",
            233X"017a49033f12eb52675e98e6432cc27104bd5c42bcbe3daf76901c9b8743",
            "3*G");

        run_case(TO_UNSIGNED(5, KBITS), 3,
            233X"194ed0ca60c85e59e7c4b69f30c6304a9f485f45032b871c4a23ffec8c1",
            233X"0a52f9459c2fab39c214061e272e1e115e1e01a98e4f09cd5a85d2698c6",
            "5*G");

        run_case(TO_UNSIGNED(12345, KBITS), 14,
            233X"171cdbf80d4cf050fafeea2b01039d6ae34aca712ff64ec8037a8496138",
            233X"13449a47f49a1f7bfbafa5ed0d36958e5f36d3be206adf07262f79bc2e1",
            "12345*G");

        WAIT UNTIL RISING_EDGE(clk);
        k_in <= (OTHERS => '0'); k_len <= 0; px_in <= GX; py_in <= GY;
        start <= '1';
        WAIT UNTIL RISING_EDGE(clk);
        start <= '0';
        WAIT UNTIL done = '1';
        WAIT UNTIL RISING_EDGE(clk);
        IF result_is_infinity = '0' THEN
            REPORT "[FAIL] 0*G: expected point at infinity" SEVERITY ERROR;
            errors <= errors + 1;
        ELSE
            REPORT "[PASS] 0*G: point at infinity";
        END IF;

        IF errors = 0 THEN
            REPORT "ALL TESTS PASSED (ecc_hardware_accelerator_G)";
        ELSE
            REPORT INTEGER'IMAGE(errors) & " TEST(S) FAILED (ecc_hardware_accelerator_G)" SEVERITY ERROR;
        END IF;

        STD.ENV.STOP;
        WAIT;
    END PROCESS;

END ARCHITECTURE sim;
