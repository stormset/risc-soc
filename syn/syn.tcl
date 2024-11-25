# configurations and paths
set top_name "dlx_soc_top"
set design_source_path "./sources.f"
set constraints_file_path "dlx_constraints.sdc"
set reports_dir_path "./reports"

# read design file paths from sources file
set f [open $design_source_path]
set design_sources [split [read $f] "\n"]
close $f

# analyze and elaborate sources
analyze -format vhdl $design_sources
elaborate -library work $top_name 

# set wire load model
set_wire_load_model -name 5K_hvratio_1_4

# source constraints file
source $constraints_file_path

# compile design
compile_ultra -no_autoungroup -gate_clock -timing_high_effort_script

# write reports
file mkdir $reports_dir_path
report_timing -input_pins -capacitance -transition_time -nets -significant_digits 4 -nosplit -nworst 10 -max_paths 300 > ${reports_dir_path}/${top_name}_timing.rpt
report_area -hierarchy -nosplit > ${reports_dir_path}/${top_name}_area.rpt
report_power -nosplit -hier > ${reports_dir_path}/${top_name}_power.rpt
report_clock_gating -nosplit > ${reports_dir_path}/${top_name}_clock_gating.rpt

# write mapped netlist and constraints file (used in further physical design steps)
write -hierarchy -f verilog -output "${top_name}_postsyn_netlist.v"
write_sdc "${top_name}.sdc"

# write sdf report (for timing accurate gate-level simulations)
write_sdf "${top_name}.sdf"
