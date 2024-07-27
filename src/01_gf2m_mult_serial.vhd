
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY gf2m_mult_serial IS
    PORT (
        clk     : IN  STD_LOGIC;
        rst_n   : IN  STD_LOGIC;
        start   : IN  STD_LOGIC;
        a_in    : IN  UNSIGNED(W-1 DOWNTO 0);
        b_in    : IN  UNSIGNED(W-1 DOWNTO 0);
        busy    : OUT STD_LOGIC;
        done    : OUT STD_LOGIC;
        product : OUT UNSIGNED(W-1 DOWNTO 0)
    );
END ENTITY gf2m_mult_serial;

ARCHITECTURE rtl OF gf2m_mult_serial IS

    TYPE state_t IS (IDLE, RUN, DONE_ST);
    SIGNAL state : state_t;

    SIGNAL a_r, b_r, c_r : UNSIGNED(W-1 DOWNTO 0);
    SIGNAL cnt : INTEGER RANGE 0 TO W-1;

BEGIN

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state   <= IDLE;
            a_r     <= (OTHERS => '0');
            b_r     <= (OTHERS => '0');
            c_r     <= (OTHERS => '0');
            cnt     <= 0;
            done    <= '0';
            product <= (OTHERS => '0');
        ELSIF RISING_EDGE(clk) THEN
            done <= '0';
            CASE state IS
                WHEN IDLE =>
                    IF start = '1' THEN
                        IF a_in(0) = '1' THEN
                            c_r <= b_in;
                        ELSE
                            c_r <= (OTHERS => '0');
                        END IF;
                        b_r   <= xtimes(b_in);
                        a_r   <= SHIFT_RIGHT(a_in, 1);
                        cnt   <= 1;
                        state <= RUN;
                    END IF;

                WHEN RUN =>
                    IF a_r(0) = '1' THEN
                        c_r <= c_r XOR b_r;
                    END IF;

                    IF cnt = W-1 THEN
                        state <= DONE_ST;
                    ELSE
                        b_r <= xtimes(b_r);
                        a_r <= SHIFT_RIGHT(a_r, 1);
                        cnt <= cnt + 1;
                    END IF;

                WHEN DONE_ST =>
                    product <= c_r;
                    done    <= '1';
                    state   <= IDLE;

            END CASE;
        END IF;
    END PROCESS;

    busy <= '0' WHEN state = IDLE ELSE '1';

END ARCHITECTURE rtl;
