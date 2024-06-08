# For the blinky design.
# The only requirement here is that synthesis passes.

create_clock -period 10 -name clk [get_ports clk]

# For the time being accept suboptimal timing.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

set_property PACKAGE_PIN P20 [get_ports {enable}]
set_property PACKAGE_PIN F19 [get_ports {clk}]
set_property PACKAGE_PIN E21 [get_ports {reset}]
set_property PACKAGE_PIN M17 [get_ports {out[0]}]
set_property PACKAGE_PIN R17 [get_ports {out[1]}]
set_property PACKAGE_PIN T18 [get_ports {out[2]}]
set_property PACKAGE_PIN K16 [get_ports {out[3]}]
set_property PACKAGE_PIN E22 [get_ports {out[4]}]
set_property PACKAGE_PIN P21 [get_ports {out[5]}]
set_property PACKAGE_PIN F20 [get_ports {out[6]}]
set_property PACKAGE_PIN E20 [get_ports {out[7]}]

set_property IOSTANDARD LVCMOS33 [all_outputs]
set_property IOSTANDARD LVCMOS33 [all_inputs]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

