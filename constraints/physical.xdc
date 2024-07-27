# Copyright 2024 M. I. E. ARDJOUNE
# SPDX-License-Identifier: Apache-2.0

set_property -dict { PACKAGE_PIN U22   IOSTANDARD LVCMOS33 } [get_ports { clk_in1_0 }]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports { clk_in1_0 }]

set_property -dict { PACKAGE_PIN P4  IOSTANDARD LVCMOS33 } [get_ports { ext_reset_in_0 }]
set_false_path -from [get_ports { ext_reset_in_0 }]

set_property -dict { PACKAGE_PIN E26   IOSTANDARD LVCMOS33 } [get_ports { TXD_0 }]
set_property -dict { PACKAGE_PIN E25   IOSTANDARD LVCMOS33 } [get_ports { RXD_0 }]

set_false_path -to   [get_ports { TXD_0 }]
set_false_path -from [get_ports { RXD_0 }]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

