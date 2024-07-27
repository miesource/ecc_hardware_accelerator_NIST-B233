
-- Copyright 2024 M. I. E. ARDJOUNE
-- SPDX-License-Identifier: Apache-2.0

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.gf2m_pkg.ALL;

ENTITY ecc_uart_top_tb IS
END ENTITY ecc_uart_top_tb;

ARCHITECTURE sim OF ecc_uart_top_tb IS

    CONSTANT CLK_FREQ_HZ  : INTEGER := 400_000;
    CONSTANT BAUD_RATE    : INTEGER := 100_000;
    CONSTANT CLK_PERIOD   : TIME    := 10 ns;
    CONSTANT CLKS_PER_BIT : INTEGER := CLK_FREQ_HZ / BAUD_RATE;
    CONSTANT NBYTES       : INTEGER := (W + 7) / 8;

    CONSTANT BIT_PERIOD : TIME := CLK_PERIOD * CLKS_PER_BIT;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL ext_reset_in_0 : STD_LOGIC;
    SIGNAL txd_0 : STD_LOGIC;
    SIGNAL rxd_0 : STD_LOGIC;

    SIGNAL errors : INTEGER := 0;

BEGIN

    clk <= NOT clk AFTER CLK_PERIOD/2;

    UUT : ENTITY work.ecc_uart_top
        GENERIC MAP (CLK_FREQ_HZ => CLK_FREQ_HZ, BAUD_RATE => BAUD_RATE)
        PORT MAP (
            clk_in1_0 => clk, ext_reset_in_0 => ext_reset_in_0,
            TXD_0 => txd_0, RXD_0 => rxd_0
        );

    STIM : PROCESS

        PROCEDURE uart_send_byte(b : STD_LOGIC_VECTOR(7 DOWNTO 0)) IS
        BEGIN
            rxd_0 <= '0'; WAIT FOR BIT_PERIOD;
            FOR i IN 0 TO 7 LOOP
                rxd_0 <= b(i);
                WAIT FOR BIT_PERIOD;
            END LOOP;
            rxd_0 <= '1'; WAIT FOR BIT_PERIOD;
        END PROCEDURE;

        PROCEDURE uart_recv_byte(b : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)) IS
        BEGIN
            WAIT UNTIL txd_0 = '0';
            WAIT FOR BIT_PERIOD * 1.5;
            FOR i IN 0 TO 7 LOOP
                b(i) := txd_0;
                WAIT FOR BIT_PERIOD;
            END LOOP;
        END PROCEDURE;

        PROCEDURE send_scalar(k : UNSIGNED(W-1 DOWNTO 0)) IS
            VARIABLE padded : STD_LOGIC_VECTOR(8*NBYTES-1 DOWNTO 0);
        BEGIN
            padded := STD_LOGIC_VECTOR(RESIZE(k, 8*NBYTES));
            FOR i IN NBYTES-1 DOWNTO 0 LOOP
                uart_send_byte(padded(8*i+7 DOWNTO 8*i));
            END LOOP;
        END PROCEDURE;

        PROCEDURE recv_response(status : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
                                 qx, qy : OUT UNSIGNED(W-1 DOWNTO 0)) IS
            VARIABLE qx_padded, qy_padded : STD_LOGIC_VECTOR(8*NBYTES-1 DOWNTO 0);
            VARIABLE byte_v : STD_LOGIC_VECTOR(7 DOWNTO 0);
        BEGIN
            uart_recv_byte(byte_v);
            status := byte_v;
            FOR i IN NBYTES-1 DOWNTO 0 LOOP
                uart_recv_byte(byte_v);
                qx_padded(8*i+7 DOWNTO 8*i) := byte_v;
            END LOOP;
            FOR i IN NBYTES-1 DOWNTO 0 LOOP
                uart_recv_byte(byte_v);
                qy_padded(8*i+7 DOWNTO 8*i) := byte_v;
            END LOOP;
            qx := UNSIGNED(qx_padded(W-1 DOWNTO 0));
            qy := UNSIGNED(qy_padded(W-1 DOWNTO 0));
        END PROCEDURE;

        PROCEDURE run_case(k, exp_x, exp_y : UNSIGNED(W-1 DOWNTO 0); name : STRING) IS
            VARIABLE status : STD_LOGIC_VECTOR(7 DOWNTO 0);
            VARIABLE qx, qy : UNSIGNED(W-1 DOWNTO 0);
        BEGIN
            send_scalar(k);
            recv_response(status, qx, qy);
            IF status /= X"00" THEN
                REPORT "[FAIL] " & name & ": unexpected status byte" SEVERITY ERROR;
                errors <= errors + 1;
            ELSIF qx /= exp_x OR qy /= exp_y THEN
                REPORT "[FAIL] " & name SEVERITY ERROR;
                errors <= errors + 1;
            ELSE
                REPORT "[PASS] " & name;
            END IF;
        END PROCEDURE;

        PROCEDURE run_infinity_case(k : UNSIGNED(W-1 DOWNTO 0); name : STRING) IS
            VARIABLE status : STD_LOGIC_VECTOR(7 DOWNTO 0);
            VARIABLE qx, qy : UNSIGNED(W-1 DOWNTO 0);
        BEGIN
            send_scalar(k);
            recv_response(status, qx, qy);
            IF status /= X"01" THEN
                REPORT "[FAIL] " & name & ": expected status 01 (infinity)" SEVERITY ERROR;
                errors <= errors + 1;
            ELSIF qx /= TO_UNSIGNED(0, W) OR qy /= TO_UNSIGNED(0, W) THEN
                REPORT "[FAIL] " & name & ": expected zeroed Qx/Qy alongside infinity status" SEVERITY ERROR;
                errors <= errors + 1;
            ELSE
                REPORT "[PASS] " & name & ": status=01, Qx=Qy=0 as documented";
            END IF;
        END PROCEDURE;

    BEGIN
        ext_reset_in_0 <= '1';
        rxd_0 <= '1';
        FOR i IN 0 TO 4 LOOP
            WAIT UNTIL RISING_EDGE(clk);
        END LOOP;
        ext_reset_in_0 <= '0';
        FOR i IN 0 TO 4 LOOP
            WAIT UNTIL RISING_EDGE(clk);
        END LOOP;

        run_case(
            TO_UNSIGNED(5, W),
            233X"194ed0ca60c85e59e7c4b69f30c6304a9f485f45032b871c4a23ffec8c1",
            233X"0a52f9459c2fab39c214061e272e1e115e1e01a98e4f09cd5a85d2698c6",
            "k=5 over real UART framing"
        );

        run_case(
            TO_UNSIGNED(12345, W),
            233X"171cdbf80d4cf050fafeea2b01039d6ae34aca712ff64ec8037a8496138",
            233X"13449a47f49a1f7bfbafa5ed0d36958e5f36d3be206adf07262f79bc2e1",
            "k=12345 over real UART framing (back-to-back, no reset)"
        );

        run_infinity_case(TO_UNSIGNED(0, W), "k=0 -> point at infinity (back-to-back, no reset)");

        IF errors = 0 THEN
            REPORT "PASS: ecc_uart_top_tb - all scalars round-tripped correctly over UART.";
        ELSE
            REPORT "FAIL: ecc_uart_top_tb - " & INTEGER'IMAGE(errors) & " case(s) failed." SEVERITY ERROR;
        END IF;

        STD.ENV.STOP;
        WAIT;
    END PROCESS;

    WATCHDOG : PROCESS
    BEGIN
        WAIT FOR 200 ms;
        REPORT "FAIL: ecc_uart_top_tb - watchdog timeout, design never completed." SEVERITY ERROR;
        STD.ENV.STOP;
        WAIT;
    END PROCESS;

END ARCHITECTURE sim;
