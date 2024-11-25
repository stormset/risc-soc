
set clk0_period 1.5

create_clock -name "clk0" -period $clk0_period i_clk

# timing constraints
set_max_delay -from [all_inputs] -to [all_outputs] $clk0_period

# clock gating
set_clock_gating_style -minimum_bitwidth 4 -sequential latch
