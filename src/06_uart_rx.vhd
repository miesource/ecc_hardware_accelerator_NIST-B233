
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY uart_rx IS
    GENERIC (
        CLK_FREQ_HZ : INTEGER := 50_000_000;
        BAUD_RATE   : INTEGER := 115_200
    );
    PORT (
        clk      : IN  STD_LOGIC;
        rst_n    : IN  STD_LOGIC;
        rx_line  : IN  STD_LOGIC;
        rx_valid : OUT STD_LOGIC;
        rx_data  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END ENTITY uart_rx;

ARCHITECTURE rtl OF uart_rx IS

    CONSTANT CLKS_PER_BIT     : INTEGER := CLK_FREQ_HZ / BAUD_RATE;
    CONSTANT CLKS_PER_HALFBIT : INTEGER := CLKS_PER_BIT / 2;

    SIGNAL rx_sync_0, rx_sync_1 : STD_LOGIC;

    TYPE state_t IS (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    SIGNAL state : state_t;

    SIGNAL data_r  : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL bit_idx : INTEGER RANGE 0 TO 7;
    SIGNAL clk_cnt : INTEGER RANGE 0 TO CLKS_PER_BIT-1;

BEGIN

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            rx_sync_0 <= '1';
            rx_sync_1 <= '1';
        ELSIF RISING_EDGE(clk) THEN
            rx_sync_0 <= rx_line;
            rx_sync_1 <= rx_sync_0;
        END IF;
    END PROCESS;

    PROCESS (clk, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state    <= IDLE;
            data_r   <= (OTHERS => '0');
            bit_idx  <= 0;
            clk_cnt  <= 0;
            rx_valid <= '0';
        ELSIF RISING_EDGE(clk) THEN
            rx_valid <= '0';

            CASE state IS
                WHEN IDLE =>
                    IF rx_sync_1 = '0' THEN
                        clk_cnt <= 0;
                        state   <= START_BIT;
                    END IF;

                WHEN START_BIT =>
                    IF clk_cnt = CLKS_PER_HALFBIT-1 THEN
                        IF rx_sync_1 = '0' THEN
                            clk_cnt <= 0;
                            bit_idx <= 0;
                            state   <= DATA_BITS;
                        ELSE
                            state <= IDLE;
                        END IF;
                    ELSE
                        clk_cnt <= clk_cnt + 1;
                    END IF;

                WHEN DATA_BITS =>
                    IF clk_cnt = CLKS_PER_BIT-1 THEN
                        clk_cnt         <= 0;
                        data_r(bit_idx) <= rx_sync_1;
                        IF bit_idx = 7 THEN
                            state <= STOP_BIT;
                        ELSE
                            bit_idx <= bit_idx + 1;
                        END IF;
                    ELSE
                        clk_cnt <= clk_cnt + 1;
                    END IF;

                WHEN STOP_BIT =>
                    IF clk_cnt = CLKS_PER_BIT-1 THEN
                        rx_data  <= data_r;
                        rx_valid <= '1';
                        clk_cnt  <= 0;
                        state    <= IDLE;
                    ELSE
                        clk_cnt <= clk_cnt + 1;
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
