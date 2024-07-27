
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY ecc_hardware_accelerator_G_full_order_tb IS
END ENTITY ecc_hardware_accelerator_G_full_order_tb;

ARCHITECTURE sim OF ecc_hardware_accelerator_G_full_order_tb IS

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

    CONSTANT K : UNSIGNED(W-1 DOWNTO 0) :=
        233X"1000000000000000000000000000013e974e72f8a6922031d2603cfe0d6";
    CONSTANT EXP_X : UNSIGNED(W-1 DOWNTO 0) := GX;
    SIGNAL   EXP_Y : UNSIGNED(W-1 DOWNTO 0);

    CONSTANT N_ORDER : UNSIGNED(W-1 DOWNTO 0) :=
        233X"1000000000000000000000000000013e974e72f8a6922031d2603cfe0d7";

BEGIN

    EXP_Y <= GX XOR GY;

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
    BEGIN
        rst_n <= '0';
        start <= '0';
        k_in <= (OTHERS => '0'); k_len <= 0;
        px_in <= (OTHERS => '0'); py_in <= (OTHERS => '0');
        WAIT FOR 30 ns;
        rst_n <= '1';

        WAIT UNTIL RISING_EDGE(clk);
        k_in  <= K;
        k_len <= 233;
        px_in <= GX;
        py_in <= GY;
        start <= '1';
        WAIT UNTIL RISING_EDGE(clk);
        start <= '0';
        WAIT UNTIL done = '1';
        WAIT UNTIL RISING_EDGE(clk);

        IF result_is_infinity = '1' THEN
            REPORT "[FAIL] (n-1)*G: got point at infinity" SEVERITY ERROR;
            errors <= errors + 1;
        ELSIF qx_out /= EXP_X OR qy_out /= EXP_Y THEN
            REPORT "[FAIL] (n-1)*G" SEVERITY ERROR;
            errors <= errors + 1;
        ELSE
            REPORT "[PASS] (n-1)*G == -G";
        END IF;

        WAIT UNTIL RISING_EDGE(clk);
        k_in  <= N_ORDER;
        k_len <= 233;
        px_in <= GX;
        py_in <= GY;
        start <= '1';
        WAIT UNTIL RISING_EDGE(clk);
        start <= '0';
        WAIT UNTIL done = '1';
        WAIT UNTIL RISING_EDGE(clk);

        IF result_is_infinity = '0' THEN
            REPORT "[FAIL] n*G: expected point at infinity" SEVERITY ERROR;
            errors <= errors + 1;
        ELSE
            REPORT "[PASS] n*G == point at infinity";
        END IF;

        IF errors = 0 THEN
            REPORT "ALL TESTS PASSED (ecc_hardware_accelerator_G, full-order scalar)";
        ELSE
            REPORT INTEGER'IMAGE(errors) & " TEST(S) FAILED" SEVERITY ERROR;
        END IF;

        STD.ENV.STOP;
        WAIT;
    END PROCESS;

END ARCHITECTURE sim;
