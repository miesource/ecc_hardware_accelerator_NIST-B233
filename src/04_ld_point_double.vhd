
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY ld_point_double IS
    PORT (
        clk    : IN  STD_LOGIC;
        rst_n  : IN  STD_LOGIC;
        start  : IN  STD_LOGIC;
        x1_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        y1_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        z1_in  : IN  UNSIGNED(W-1 DOWNTO 0);
        busy   : OUT STD_LOGIC;
        done   : OUT STD_LOGIC;
        x3_out : OUT UNSIGNED(W-1 DOWNTO 0);
        y3_out : OUT UNSIGNED(W-1 DOWNTO 0);
        z3_out : OUT UNSIGNED(W-1 DOWNTO 0)
    );
END ENTITY ld_point_double;

ARCHITECTURE rtl OF ld_point_double IS

    TYPE state_t IS (
        IDLE,
        ST_S_U,
        ST_MUL1_START,
        ST_Z3,
        ST_MUL2_START, ST_MUL2_WAIT,
        ST_U2_X3,
        ST_S2,
        ST_MUL3_START, ST_MUL3_WAIT,
        ST_MUL4_START, ST_MUL4_WAIT,
        ST_Y3,
        DONE_ST
    );
    SIGNAL state : state_t;

    SIGNAL x1_r, z1_r : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL s_r, u_r, t_r, z3_r, u2_r, s2_r, x3_r, term1_r, y3_r : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL mul_start : STD_LOGIC;
    SIGNAL mul_busy, mul_done : STD_LOGIC;
    SIGNAL mul_a, mul_b, mul_product : UNSIGNED(W-1 DOWNTO 0);

BEGIN

    MULT : ENTITY work.gf2m_mult_serial
        PORT MAP (clk, rst_n, mul_start, mul_a, mul_b, mul_busy, mul_done, mul_product);

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state     <= IDLE;
            mul_start <= '0';
            done      <= '0';
            x1_r <= (OTHERS => '0'); z1_r <= (OTHERS => '0');
            s_r <= (OTHERS => '0'); u_r <= (OTHERS => '0'); t_r <= (OTHERS => '0');
            z3_r <= (OTHERS => '0');
            u2_r <= (OTHERS => '0'); s2_r <= (OTHERS => '0'); x3_r <= (OTHERS => '0');
            term1_r <= (OTHERS => '0'); y3_r <= (OTHERS => '0');
            x3_out <= (OTHERS => '0'); y3_out <= (OTHERS => '0'); z3_out <= (OTHERS => '0');
        ELSIF RISING_EDGE(clk) THEN
            mul_start <= '0';
            done      <= '0';

            CASE state IS
                WHEN IDLE =>
                    IF start = '1' THEN
                        x1_r  <= x1_in;
                        z1_r  <= z1_in;
                        s_r   <= gf_square(x1_in);
                        u_r   <= gf_square(x1_in) XOR y1_in;
                        state <= ST_S_U;
                    END IF;

                WHEN ST_S_U =>
                    mul_a     <= x1_r;
                    mul_b     <= z1_r;
                    mul_start <= '1';
                    state     <= ST_MUL1_START;

                WHEN ST_MUL1_START =>
                    IF mul_done = '1' THEN
                        t_r   <= mul_product;
                        state <= ST_Z3;
                    END IF;

                WHEN ST_Z3 =>
                    z3_r  <= gf_square(t_r);
                    state <= ST_MUL2_START;

                WHEN ST_MUL2_START =>
                    mul_a     <= u_r;
                    mul_b     <= t_r;
                    mul_start <= '1';
                    state     <= ST_MUL2_WAIT;

                WHEN ST_MUL2_WAIT =>
                    IF mul_done = '1' THEN
                        t_r   <= mul_product;
                        state <= ST_U2_X3;
                    END IF;

                WHEN ST_U2_X3 =>
                    u2_r  <= gf_square(u_r);
                    x3_r  <= gf_square(u_r) XOR t_r XOR mul_a2(z3_r);
                    state <= ST_S2;

                WHEN ST_S2 =>
                    s2_r  <= gf_square(s_r);
                    state <= ST_MUL3_START;

                WHEN ST_MUL3_START =>
                    mul_a     <= z3_r XOR t_r;
                    mul_b     <= x3_r;
                    mul_start <= '1';
                    state     <= ST_MUL3_WAIT;

                WHEN ST_MUL3_WAIT =>
                    IF mul_done = '1' THEN
                        term1_r <= mul_product;
                        state   <= ST_MUL4_START;
                    END IF;

                WHEN ST_MUL4_START =>
                    mul_a     <= s2_r;
                    mul_b     <= z3_r;
                    mul_start <= '1';
                    state     <= ST_MUL4_WAIT;

                WHEN ST_MUL4_WAIT =>
                    IF mul_done = '1' THEN
                        y3_r  <= term1_r XOR mul_product;
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
