
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY ecc_uart_top IS
    GENERIC (
        CLK_FREQ_HZ : INTEGER := 50_000_000;
        BAUD_RATE   : INTEGER := 115_200
    );
    PORT (
        clk_in1_0      : IN  STD_LOGIC;
        ext_reset_in_0 : IN  STD_LOGIC;
        TXD_0          : OUT STD_LOGIC;
        RXD_0          : IN  STD_LOGIC
    );
END ENTITY ecc_uart_top;

ARCHITECTURE rtl OF ecc_uart_top IS

    SIGNAL rst_sync : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL rst_n    : STD_LOGIC;

    SIGNAL tx_start, tx_busy : STD_LOGIC;
    SIGNAL tx_data  : STD_LOGIC_VECTOR(7 DOWNTO 0);
    SIGNAL rx_valid : STD_LOGIC;
    SIGNAL rx_data  : STD_LOGIC_VECTOR(7 DOWNTO 0);

    CONSTANT GX : UNSIGNED(W-1 DOWNTO 0) :=
        233X"0fac9dfcbac8313bb2139f1bb755fef65bc391f8b36f8f8eb7371fd558b";
    CONSTANT GY : UNSIGNED(W-1 DOWNTO 0) :=
        233X"1006a08a41903350678e58528bebf8a0beff867a7ca36716f7e01f81052";

    CONSTANT NBYTES   : INTEGER := (W + 7) / 8;
    CONSTANT PAD_BITS : INTEGER := 8*NBYTES - W;

    SIGNAL ecc_start, ecc_busy, ecc_done, ecc_inf : STD_LOGIC;
    SIGNAL ecc_qx, ecc_qy : UNSIGNED(W-1 DOWNTO 0);

    SIGNAL k_latched : UNSIGNED(W-1 DOWNTO 0);

    TYPE state_t IS (RX_K, RUN_ECC, LOAD_RESPONSE, TX_BYTE_START, TX_BYTE_WAIT);
    SIGNAL state : state_t;

    SIGNAL rx_byte_cnt : INTEGER RANGE 0 TO NBYTES;
    SIGNAL rx_shift      : STD_LOGIC_VECTOR(8*NBYTES-1 DOWNTO 0);
    SIGNAL rx_shift_next : STD_LOGIC_VECTOR(8*NBYTES-1 DOWNTO 0);

    CONSTANT RESP_BYTES : INTEGER := 1 + 2*NBYTES;
    SIGNAL tx_shift      : STD_LOGIC_VECTOR(8*RESP_BYTES-1 DOWNTO 0);
    SIGNAL tx_byte_cnt   : INTEGER RANGE 0 TO RESP_BYTES;

BEGIN

    PROCESS (clk_in1_0, ext_reset_in_0)
    BEGIN
        IF ext_reset_in_0 = '1' THEN
            rst_sync <= "11";
        ELSIF RISING_EDGE(clk_in1_0) THEN
            rst_sync <= rst_sync(0) & '0';
        END IF;
    END PROCESS;
    rst_n <= NOT rst_sync(1);

    U_UART_TX : ENTITY work.uart_tx
        GENERIC MAP (CLK_FREQ_HZ => CLK_FREQ_HZ, BAUD_RATE => BAUD_RATE)
        PORT MAP (
            clk => clk_in1_0, rst_n => rst_n,
            tx_start => tx_start, data_in => tx_data,
            tx_busy => tx_busy, tx_line => TXD_0
        );

    U_UART_RX : ENTITY work.uart_rx
        GENERIC MAP (CLK_FREQ_HZ => CLK_FREQ_HZ, BAUD_RATE => BAUD_RATE)
        PORT MAP (
            clk => clk_in1_0, rst_n => rst_n,
            rx_line => RXD_0, rx_valid => rx_valid, rx_data => rx_data
        );

    U_ECC : ENTITY work.ecc_hardware_accelerator_G
        GENERIC MAP (KBITS => W)
        PORT MAP (
            clk => clk_in1_0, rst_n => rst_n,
            start => ecc_start,
            k_in => k_latched,
            k_len => W,
            px_in => GX, py_in => GY,
            busy => ecc_busy, done => ecc_done,
            result_is_infinity => ecc_inf,
            qx_out => ecc_qx, qy_out => ecc_qy
        );

    rx_shift_next <= rx_shift(8*NBYTES-9 DOWNTO 0) & rx_data;

    PROCESS (clk_in1_0, rst_n)
    BEGIN
        IF rst_n = '0' THEN
            state       <= RX_K;
            rx_byte_cnt <= 0;
            rx_shift    <= (OTHERS => '0');
            k_latched   <= (OTHERS => '0');
            ecc_start   <= '0';
            tx_shift    <= (OTHERS => '0');
            tx_byte_cnt <= 0;
            tx_start    <= '0';
            tx_data     <= (OTHERS => '0');
        ELSIF RISING_EDGE(clk_in1_0) THEN
            ecc_start <= '0';
            tx_start  <= '0';

            CASE state IS
                WHEN RX_K =>
                    IF rx_valid = '1' THEN
                        rx_shift <= rx_shift_next;
                        IF rx_byte_cnt = NBYTES-1 THEN
                            rx_byte_cnt <= 0;
                            k_latched   <= UNSIGNED(rx_shift_next(W-1 DOWNTO 0));
                            ecc_start   <= '1';
                            state       <= RUN_ECC;
                        ELSE
                            rx_byte_cnt <= rx_byte_cnt + 1;
                        END IF;
                    END IF;

                WHEN RUN_ECC =>
                    IF ecc_done = '1' THEN
                        state <= LOAD_RESPONSE;
                    END IF;

                WHEN LOAD_RESPONSE =>
                    IF ecc_inf = '1' THEN
                        tx_shift <= X"01" &
                                    STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8*NBYTES)) &
                                    STD_LOGIC_VECTOR(TO_UNSIGNED(0, 8*NBYTES));
                    ELSE
                        tx_shift <= X"00" &
                                    STD_LOGIC_VECTOR(TO_UNSIGNED(0, PAD_BITS)) & STD_LOGIC_VECTOR(ecc_qx) &
                                    STD_LOGIC_VECTOR(TO_UNSIGNED(0, PAD_BITS)) & STD_LOGIC_VECTOR(ecc_qy);
                    END IF;
                    tx_byte_cnt <= 0;
                    state       <= TX_BYTE_START;

                WHEN TX_BYTE_START =>
                    tx_data  <= tx_shift(8*RESP_BYTES-1 DOWNTO 8*RESP_BYTES-8);
                    tx_start <= '1';
                    state    <= TX_BYTE_WAIT;

                WHEN TX_BYTE_WAIT =>
                    IF tx_busy = '1' THEN
                        NULL;
                    ELSIF tx_start = '0' THEN
                        tx_shift <= tx_shift(8*RESP_BYTES-9 DOWNTO 0) & X"00";
                        IF tx_byte_cnt = RESP_BYTES-1 THEN
                            state <= RX_K;
                        ELSE
                            tx_byte_cnt <= tx_byte_cnt + 1;
                            state       <= TX_BYTE_START;
                        END IF;
                    END IF;

            END CASE;
        END IF;
    END PROCESS;

END ARCHITECTURE rtl;
