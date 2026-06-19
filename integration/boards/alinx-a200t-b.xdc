# For the blinky design.
# The only requirement here is that synthesis passes.

create_clock -period 10 -name clk [get_ports clk]
set_property PACKAGE_PIN R4 [get_ports {clk}]

# For the time being accept suboptimal timing.
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_IBUF]

set_property PACKAGE_PIN W7 [get_ports {reset}]

set_property PACKAGE_PIN W5 [get_ports {out}]

set_property IOSTANDARD LVCMOS33 [all_outputs]
set_property IOSTANDARD LVCMOS33 [all_inputs]

set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

