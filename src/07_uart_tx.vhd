
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY uart_tx IS
    GENERIC (
        CLK_FREQ_HZ : INTEGER := 50_000_000;
        BAUD_RATE   : INTEGER := 115_200
    );
    PORT (
        clk      : IN  STD_LOGIC;
        rst_n    : IN  STD_LOGIC;
        tx_start : IN  STD_LOGIC;
        data_in  : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
        tx_busy  : OUT STD_LOGIC;
        tx_line  : OUT STD_LOGIC
    );
END ENTITY uart_tx;

ARCHITECTURE rtl OF uart_tx IS

    CONSTANT CLKS_PER_BIT : INTEGER := CLK_FREQ_HZ / BAUD_RATE;

    TYPE state_t IS (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    SIGNAL state : state_t;

    SIGNAL data_r  : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL bit_idx : INTEGER RANGE 0 TO 7;
    SIGNAL clk_cnt : INTEGER RANGE 0 TO CLKS_PER_BIT-1;

BEGIN

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state   <= IDLE;
            data_r  <= (OTHERS => '0');
            bit_idx <= 0;
            clk_cnt <= 0;
            tx_line <= '1';
        ELSIF RISING_EDGE(clk) THEN
            CASE state IS
                WHEN IDLE =>
                    tx_line <= '1';
                    IF tx_start = '1' THEN
                        data_r  <= data_in;
                        clk_cnt <= 0;
                        state   <= START_BIT;
                    END IF;

                WHEN START_BIT =>
                    tx_line <= '0';
                    IF clk_cnt = CLKS_PER_BIT-1 THEN
                        clk_cnt <= 0;
                        bit_idx <= 0;
                        state   <= DATA_BITS;
                    ELSE
                        clk_cnt <= clk_cnt + 1;
                    END IF;

                WHEN DATA_BITS =>
                    tx_line <= data_r(bit_idx);
                    IF clk_cnt = CLKS_PER_BIT-1 THEN
                        clk_cnt <= 0;
                        IF bit_idx = 7 THEN
                            state <= STOP_BIT;
                        ELSE
                            bit_idx <= bit_idx + 1;
                        END IF;
                    ELSE
                        clk_cnt <= clk_cnt + 1;
                    END IF;

                WHEN STOP_BIT =>
                    tx_line <= '1';
                    IF clk_cnt = CLKS_PER_BIT-1 THEN
                        clk_cnt <= 0;
                        state   <= IDLE;
                    ELSE
                        clk_cnt <= clk_cnt + 1;
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

    tx_busy <= '0' WHEN state = IDLE ELSE '1';

END ARCHITECTURE rtl;
