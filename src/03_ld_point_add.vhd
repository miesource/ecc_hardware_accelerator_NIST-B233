
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY ld_point_add IS
    PORT (
        clk    : IN  STD_LOGIC;
        rst_n  : IN  STD_LOGIC;
        start  : IN  STD_LOGIC;
        x1_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        y1_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        x2_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        y2_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        z2_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        busy   : OUT STD_LOGIC;
        done   : OUT STD_LOGIC;
        x3_out : OUT UNSIGNED(W-1 DOWNTO 0);
        y3_out : OUT UNSIGNED(W-1 DOWNTO 0);
        z3_out : OUT UNSIGNED(W-1 DOWNTO 0)
    );
END ENTITY ld_point_add;

ARCHITECTURE rtl OF ld_point_add IS

    TYPE state_t IS (
        IDLE,
        ST_MUL1_START,
        ST_MUL2_START,
        ST_MUL3_START, ST_MUL3_WAIT,
        ST_Z3,
        ST_MUL4_START, ST_MUL4_WAIT,
        ST_MUL5_START, ST_MUL5_WAIT,
        ST_MUL6_START,
        ST_X3,
        ST_MUL7_START, ST_MUL7_WAIT,
        ST_MUL8_START,
        ST_Y3,
        DONE_ST
    );
    SIGNAL state : state_t;

    SIGNAL x1_r, y1_r, x2_r, y2_r, z2_r : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL u_r, s_r, t_r, z3_r, v_r, c_r, x3_r, tu_r, y3_r : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL mul_start : STD_LOGIC;
    SIGNAL mul_busy, mul_done : STD_LOGIC;
    SIGNAL mul_a, mul_b, mul_product : UNSIGNED(W-1 DOWNTO 0);

BEGIN

    MULT : ENTITY work.gf2m_mult_serial
        PORT MAP (clk, rst_n, mul_start, mul_a, mul_b, mul_busy, mul_done, mul_product);

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state <= IDLE;
            mul_start <= '0';
            done <= '0';
            x1_r <= (OTHERS => '0'); y1_r <= (OTHERS => '0');
            x2_r <= (OTHERS => '0'); y2_r <= (OTHERS => '0'); z2_r <= (OTHERS => '0');
            u_r <= (OTHERS => '0'); s_r <= (OTHERS => '0'); t_r <= (OTHERS => '0');
            z3_r <= (OTHERS => '0'); v_r <= (OTHERS => '0'); c_r <= (OTHERS => '0');
            x3_r <= (OTHERS => '0'); tu_r <= (OTHERS => '0'); y3_r <= (OTHERS => '0');
            x3_out <= (OTHERS => '0'); y3_out <= (OTHERS => '0'); z3_out <= (OTHERS => '0');
        ELSIF RISING_EDGE(clk) THEN
            mul_start <= '0';
            done      <= '0';

            CASE state IS
                WHEN IDLE =>
                    IF start = '1' THEN
                        x1_r <= x1_in; y1_r <= y1_in;
                        x2_r <= x2_in; y2_r <= y2_in; z2_r <= z2_in;
                        c_r  <= x1_in XOR y1_in;
                        mul_a <= gf_square(z2_in);
                        mul_b <= y1_in;
                        mul_start <= '1';
                        state <= ST_MUL1_START;
                    END IF;

                WHEN ST_MUL1_START =>
                    IF mul_done = '1' THEN
                        u_r   <= mul_product XOR y2_r;
                        mul_a <= z2_r;
                        mul_b <= x1_r;
                        mul_start <= '1';
                        state <= ST_MUL2_START;
                    END IF;

                WHEN ST_MUL2_START =>
                    IF mul_done = '1' THEN
                        s_r   <= mul_product XOR x2_r;
                        mul_a <= z2_r;
                        state <= ST_MUL3_START;
                    END IF;

                WHEN ST_MUL3_START =>
                    mul_b     <= s_r;
                    mul_start <= '1';
                    state     <= ST_MUL3_WAIT;

                WHEN ST_MUL3_WAIT =>
                    IF mul_done = '1' THEN
                        t_r   <= mul_product;
                        state <= ST_Z3;
                    END IF;

                WHEN ST_Z3 =>
                    z3_r  <= gf_square(t_r);
                    state <= ST_MUL4_START;

                WHEN ST_MUL4_START =>
                    mul_a     <= z3_r;
                    mul_b     <= x1_r;
                    mul_start <= '1';
                    state     <= ST_MUL4_WAIT;

                WHEN ST_MUL4_WAIT =>
                    IF mul_done = '1' THEN
                        v_r   <= mul_product;
                        state <= ST_MUL5_START;
                    END IF;

                WHEN ST_MUL5_START =>
                    mul_a     <= t_r;
                    mul_b     <= u_r XOR gf_square(s_r) XOR mul_a2(t_r);
                    mul_start <= '1';
                    state     <= ST_MUL5_WAIT;

                WHEN ST_MUL5_WAIT =>
                    IF mul_done = '1' THEN
                        x3_r  <= gf_square(u_r) XOR mul_product;
                        mul_a <= t_r;
                        mul_b <= u_r;
                        mul_start <= '1';
                        state <= ST_MUL6_START;
                    END IF;

                WHEN ST_MUL6_START =>
                    IF mul_done = '1' THEN
                        tu_r  <= mul_product;
                        state <= ST_X3;
                    END IF;

                WHEN ST_X3 =>
                    state <= ST_MUL7_START;

                WHEN ST_MUL7_START =>
                    mul_a     <= v_r XOR x3_r;
                    mul_b     <= tu_r XOR z3_r;
                    mul_start <= '1';
                    state     <= ST_MUL7_WAIT;

                WHEN ST_MUL7_WAIT =>
                    IF mul_done = '1' THEN
                        y3_r  <= mul_product;
                        mul_a <= gf_square(z3_r);
                        mul_b <= c_r;
                        mul_start <= '1';
                        state <= ST_MUL8_START;
                    END IF;

                WHEN ST_MUL8_START =>
                    IF mul_done = '1' THEN
                        y3_r  <= y3_r XOR mul_product;
                        state <= ST_Y3;
                    END IF;

                WHEN ST_Y3 =>
                    x3_out <= x3_r;
                    y3_out <= y3_r;
                    z3_out <= z3_r;
                    state  <= DONE_ST;

                WHEN DONE_ST =>
                    done  <= '1';
                    state <= IDLE;

            END CASE;
        END IF;
    END PROCESS;

    busy <= '0' WHEN state = IDLE ELSE '1';

END ARCHITECTURE rtl;
