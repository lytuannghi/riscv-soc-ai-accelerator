# SkyWater 130nm Reference Timing Constraints (Portable Template)
create_clock -name core_clk -period 20.00 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks core_clk]
set_input_delay  2.00 -clock core_clk [all_inputs]
set_output_delay 2.00 -clock core_clk [all_outputs]
set_load 0.05 [all_outputs]
