
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY gf2m_inverse IS
    PORT (
        clk     : IN  STD_LOGIC;
        rst_n   : IN  STD_LOGIC;
        start   : IN  STD_LOGIC;
        a_in    : IN  UNSIGNED(W-1 DOWNTO 0);
        busy    : OUT STD_LOGIC;
        done    : OUT STD_LOGIC;
        inv_out : OUT UNSIGNED(W-1 DOWNTO 0)
    );
END ENTITY gf2m_inverse;

ARCHITECTURE rtl OF gf2m_inverse IS

    CONSTANT M_MINUS_1 : INTEGER := W - 1;
    CONSTANT NBITS      : INTEGER := 8;
    CONSTANT BITS_C : UNSIGNED(NBITS-1 DOWNTO 0) := TO_UNSIGNED(M_MINUS_1, NBITS);

    TYPE state_t IS (
        IDLE,
        DBL_FROB_START, DBL_FROB_WAIT,
        DBL_MUL_START,  DBL_MUL_WAIT,
        INCR_SQ,
        INCR_MUL_START, INCR_MUL_WAIT,
        FINAL_SQ,
        DONE_ST
    );
    SIGNAL state : state_t;

    SIGNAL a_r      : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL s_r       : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL s_frob_r  : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL k_r       : UNSIGNED(9 DOWNTO 0);
    SIGNAL frob_cnt   : UNSIGNED(9 DOWNTO 0);
    SIGNAL bit_idx   : INTEGER RANGE 0 TO NBITS-1;

    SIGNAL m_start : STD_LOGIC;
    SIGNAL mul_a, mul_b, mul_product : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL mul_busy, mul_done : STD_LOGIC;

BEGIN

    MULT : ENTITY work.gf2m_mult_serial
        PORT MAP (
            clk => clk, rst_n => rst_n,
            start => m_start, a_in => mul_a, b_in => mul_b,
            busy => mul_busy, done => mul_done, product => mul_product
        );

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state     <= IDLE;
            a_r       <= (OTHERS => '0');
            s_r       <= (OTHERS => '0');
            s_frob_r  <= (OTHERS => '0');
            k_r       <= (OTHERS => '0');
            frob_cnt  <= (OTHERS => '0');
            bit_idx   <= 0;
            m_start   <= '0';
            mul_a     <= (OTHERS => '0');
            mul_b     <= (OTHERS => '0');
            done      <= '0';
            inv_out   <= (OTHERS => '0');
        ELSIF RISING_EDGE(clk) THEN
            m_start <= '0';
            done    <= '0';

            CASE state IS
                WHEN IDLE =>
                    IF start = '1' THEN
                        a_r     <= a_in;
                        s_r     <= a_in;
                        k_r     <= TO_UNSIGNED(1, 10);
                        bit_idx <= NBITS - 2;
                        state   <= DBL_FROB_START;
                    END IF;

                WHEN DBL_FROB_START =>
                    s_frob_r <= s_r;
                    frob_cnt <= k_r;
                    state    <= DBL_FROB_WAIT;

                WHEN DBL_FROB_WAIT =>
                    IF frob_cnt = 0 THEN
                        mul_a   <= s_frob_r;
                        mul_b   <= s_r;
                        m_start <= '1';
                        state   <= DBL_MUL_START;
                    ELSE
                        s_frob_r <= gf_square(s_frob_r);
                        frob_cnt <= frob_cnt - 1;
                    END IF;

                WHEN DBL_MUL_START =>
                    IF mul_done = '1' THEN
                        s_r <= mul_product;
                        k_r <= SHIFT_LEFT(k_r, 1);
                        IF BITS_C(bit_idx) = '1' THEN
                            state <= INCR_SQ;
                        ELSE
                            state <= DBL_MUL_WAIT;
                        END IF;
                    END IF;

                WHEN DBL_MUL_WAIT =>
                    IF bit_idx = 0 THEN
                        state <= FINAL_SQ;
                    ELSE
                        bit_idx <= bit_idx - 1;
                        state   <= DBL_FROB_START;
                    END IF;

                WHEN INCR_SQ =>
                    mul_a   <= gf_square(s_r);
                    mul_b   <= a_r;
                    m_start <= '1';
                    state   <= INCR_MUL_START;

                WHEN INCR_MUL_START =>
                    IF mul_done = '1' THEN
                        s_r <= mul_product;
                        k_r <= k_r + 1;
                        state <= INCR_MUL_WAIT;
                    END IF;

                WHEN INCR_MUL_WAIT =>
                    IF bit_idx = 0 THEN
                        state <= FINAL_SQ;
                    ELSE
                        bit_idx <= bit_idx - 1;
                        state   <= DBL_FROB_START;
                    END IF;

                WHEN FINAL_SQ =>
                    inv_out <= gf_square(s_r);
                    state   <= DONE_ST;

                WHEN DONE_ST =>
                    done  <= '1';
                    state <= IDLE;

            END CASE;
        END IF;
    END PROCESS;

    busy <= '0' WHEN state = IDLE ELSE '1';

END ARCHITECTURE rtl;
