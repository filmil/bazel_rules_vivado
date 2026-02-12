create_clock -add -name clk -period 5.0 -waveform {0 2.5} [get_ports {clk}];

set_property CONFIG_VOLTAGE 3.3 [current_design];
set_property CFGBVS VCCO [current_design];

set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 } [get_ports { clk }];
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { reset }];
set_property -dict { PACKAGE_PIN K14 IOSTANDARD LVCMOS33 } [get_ports {output[0]}];

# This is bad, but we don't care for this design.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

