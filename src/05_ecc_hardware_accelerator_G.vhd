
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY ecc_hardware_accelerator_G IS
    GENERIC (
        KBITS : INTEGER := W
    );
    PORT (
        clk    : IN  STD_LOGIC;
        rst_n  : IN  STD_LOGIC;
        start  : IN  STD_LOGIC;
        k_in   : IN  UNSIGNED(KBITS-1 DOWNTO 0);
        k_len  : IN  INTEGER RANGE 0 TO KBITS;
        px_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        py_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        busy   : OUT STD_LOGIC;
        done   : OUT STD_LOGIC;
        result_is_infinity : OUT STD_LOGIC;
        qx_out : OUT UNSIGNED(W-1 DOWNTO 0);
        qy_out : OUT UNSIGNED(W-1 DOWNTO 0)
    );
END ENTITY ecc_hardware_accelerator_G;

ARCHITECTURE rtl OF ecc_hardware_accelerator_G IS

    TYPE state_t IS (
        IDLE,
        BIT_LOOP_DBL_START, BIT_LOOP_DBL_WAIT,
        BIT_LOOP_ADD_START, BIT_LOOP_ADD_WAIT,
        BIT_LOOP_NEXT,
        CONVERT_ZINV_START, CONVERT_ZINV_WAIT,
        CONVERT_ZINV2,
        CONVERT_MULX_START,
        CONVERT_MULY_START,
        DONE_ST
    );
    SIGNAL state : state_t;

    SIGNAL px_r, py_r : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL k_r : UNSIGNED(KBITS-1 DOWNTO 0);
    SIGNAL bit_idx : INTEGER RANGE 0 TO KBITS-1;

    SIGNAL xacc, yacc, zacc : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL pd_start, pd_busy, pd_done : STD_LOGIC;
    SIGNAL pd_x3, pd_y3, pd_z3 : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL pa_start, pa_busy, pa_done : STD_LOGIC;
    SIGNAL pa_x3, pa_y3, pa_z3 : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL inv_start, inv_busy, inv_done : STD_LOGIC;
    SIGNAL inv_out : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL mul_start, mul_busy, mul_done : STD_LOGIC;
    SIGNAL mul_a, mul_b, mul_product : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL zinv_r, zinv2_r : UNSIGNED(W-1 DOWNTO 0);

BEGIN

    PD : ENTITY work.ld_point_double
        PORT MAP (
            clk => clk, rst_n => rst_n,
            start => pd_start,
            x1_in => xacc, y1_in => yacc, z1_in => zacc,
            busy => pd_busy, done => pd_done,
            x3_out => pd_x3, y3_out => pd_y3, z3_out => pd_z3
        );

    PA : ENTITY work.ld_point_add
        PORT MAP (
            clk => clk, rst_n => rst_n,
            start => pa_start,
            x1_in => px_r, y1_in => py_r,
            x2_in => xacc, y2_in => yacc, z2_in => zacc,
            busy => pa_busy, done => pa_done,
            x3_out => pa_x3, y3_out => pa_y3, z3_out => pa_z3
        );

    INV : ENTITY work.gf2m_inverse
        PORT MAP (
            clk => clk, rst_n => rst_n,
            start => inv_start,
            a_in => zacc,
            busy => inv_busy, done => inv_done,
            inv_out => inv_out
        );

    MULT : ENTITY work.gf2m_mult_serial
        PORT MAP (
            clk => clk, rst_n => rst_n,
            start => mul_start,
            a_in => mul_a, b_in => mul_b,
            busy => mul_busy, done => mul_done,
            product => mul_product
        );

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state <= IDLE;
            pd_start <= '0'; pa_start <= '0'; inv_start <= '0'; mul_start <= '0';
            done <= '0';
            result_is_infinity <= '0';
            px_r <= (OTHERS => '0'); py_r <= (OTHERS => '0');
            k_r <= (OTHERS => '0'); bit_idx <= 0;
            xacc <= (OTHERS => '0'); yacc <= (OTHERS => '0'); zacc <= (OTHERS => '0');
            zinv_r <= (OTHERS => '0'); zinv2_r <= (OTHERS => '0');
            qx_out <= (OTHERS => '0'); qy_out <= (OTHERS => '0');
        ELSIF RISING_EDGE(clk) THEN
            pd_start  <= '0';
            pa_start  <= '0';
            inv_start <= '0';
            mul_start <= '0';
            done      <= '0';

            CASE state IS
                WHEN IDLE =>
                    IF start = '1' THEN
                        px_r <= px_in;
                        py_r <= py_in;
                        k_r  <= k_in;
                        IF k_len = 0 THEN
                            result_is_infinity <= '1';
                            qx_out <= (OTHERS => '0');
                            qy_out <= (OTHERS => '0');
                            state  <= DONE_ST;
                        ELSE
                            bit_idx <= k_len - 1;
                            xacc <= (OTHERS => '0'); yacc <= (OTHERS => '0'); zacc <= (OTHERS => '0');
                            result_is_infinity <= '0';
                            state <= BIT_LOOP_DBL_START;
                        END IF;
                    END IF;

                WHEN BIT_LOOP_DBL_START =>
                    pd_start <= '1';
                    state    <= BIT_LOOP_DBL_WAIT;

                WHEN BIT_LOOP_DBL_WAIT =>
                    IF pd_done = '1' THEN
                        xacc <= pd_x3;
                        yacc <= pd_y3;
                        zacc <= pd_z3;
                        IF k_r(bit_idx) = '1' THEN
                            IF pd_z3 = TO_UNSIGNED(0, W) THEN
                                xacc  <= px_r;
                                yacc  <= py_r;
                                zacc  <= TO_UNSIGNED(1, W);
                                state <= BIT_LOOP_NEXT;
                            ELSE
                                state <= BIT_LOOP_ADD_START;
                            END IF;
                        ELSE
                            state <= BIT_LOOP_NEXT;
                        END IF;
                    END IF;

                WHEN BIT_LOOP_ADD_START =>
                    pa_start <= '1';
                    state    <= BIT_LOOP_ADD_WAIT;

                WHEN BIT_LOOP_ADD_WAIT =>
                    IF pa_done = '1' THEN
                        xacc  <= pa_x3;
                        yacc  <= pa_y3;
                        zacc  <= pa_z3;
                        state <= BIT_LOOP_NEXT;
                    END IF;

                WHEN BIT_LOOP_NEXT =>
                    IF bit_idx = 0 THEN
                        state <= CONVERT_ZINV_START;
                    ELSE
                        bit_idx <= bit_idx - 1;
                        state   <= BIT_LOOP_DBL_START;
                    END IF;

                WHEN CONVERT_ZINV_START =>
                    IF zacc = TO_UNSIGNED(0, W) THEN
                        result_is_infinity <= '1';
                        state <= DONE_ST;
                    ELSE
                        inv_start <= '1';
                        state     <= CONVERT_ZINV_WAIT;
                    END IF;

                WHEN CONVERT_ZINV_WAIT =>
                    IF inv_done = '1' THEN
                        zinv_r <= inv_out;
                        state  <= CONVERT_ZINV2;
                    END IF;

                WHEN CONVERT_ZINV2 =>
                    zinv2_r   <= gf_square(zinv_r);
                    mul_a     <= xacc;
                    mul_b     <= zinv_r;
                    mul_start <= '1';
                    state     <= CONVERT_MULX_START;

                WHEN CONVERT_MULX_START =>
                    IF mul_done = '1' THEN
                        qx_out <= mul_product;
                        mul_a  <= yacc;
                        mul_b  <= zinv2_r;
                        mul_start <= '1';
                        state  <= CONVERT_MULY_START;
                    END IF;

                WHEN CONVERT_MULY_START =>
                    IF mul_done = '1' THEN
                        qy_out <= mul_product;
                        state  <= DONE_ST;
                    END IF;

                WHEN DONE_ST =>
                    done  <= '1';
                    state <= IDLE;

            END CASE;
        END IF;
    END PROCESS;

    busy <= '0' WHEN state = IDLE ELSE '1';

END ARCHITECTURE rtl;
