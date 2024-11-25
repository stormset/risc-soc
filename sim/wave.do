onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider clock
add wave -noupdate /tb_dlx_soc/clk
add wave -noupdate /tb_dlx_soc/nrst
add wave -noupdate -divider {IF stage}
add wave -noupdate -color Coral -label PC -radix unsigned /tb_dlx_soc/dlx/core0/pc_reg
add wave -noupdate -color Coral -label instruction /tb_dlx_soc/dlx/core0/fetch/o_fetch_to_decode.instruction
add wave -noupdate -color Coral -label btb_mispredict -radix unsigned /tb_dlx_soc/dlx/core0/control_unit/datapath_in.mispredict_ID
add wave -noupdate -divider {ID stage}
add wave -noupdate -color Orange /tb_dlx_soc/dlx/core0/control_unit/opcode_ID
add wave -noupdate -color Orange /tb_dlx_soc/dlx/core0/control_unit/func_ID
add wave -noupdate -divider {EXE stage}
add wave -noupdate -color {Medium Spring Green} -label rs1_data -radix decimal /tb_dlx_soc/dlx/core0/execute/rs1
add wave -noupdate -color {Medium Spring Green} -label rs2_data -radix decimal /tb_dlx_soc/dlx/core0/execute/rs2
add wave -noupdate -color {Medium Spring Green} -label result -radix decimal /tb_dlx_soc/dlx/core0/execute/r_next.execution_unit_out
add wave -noupdate -color {Medium Spring Green} -label immediate -radix decimal /tb_dlx_soc/dlx/core0/execute/i_decode_to_execute.immediate
add wave -noupdate -divider {MEM stage}
add wave -noupdate -color {Cadet Blue} -label request_write /tb_dlx_soc/dlx/core0/memory/o_memory_to_l1_cache.request_write
add wave -noupdate -color {Cadet Blue} -label request_address /tb_dlx_soc/dlx/core0/memory/o_memory_to_l1_cache.address
add wave -noupdate -color {Cadet Blue} -label request_write_data /tb_dlx_soc/dlx/core0/memory/o_memory_to_l1_cache.write_data
add wave -noupdate -color {Cadet Blue} -label request_strobe /tb_dlx_soc/dlx/core0/memory/o_memory_to_l1_cache.strobe
add wave -noupdate -color Aquamarine -label response_valid /tb_dlx_soc/dlx/core0/memory/i_l1_cache_to_memory.read_data_valid
add wave -noupdate -color Aquamarine -label response_address /tb_dlx_soc/dlx/core0/memory/i_l1_cache_to_memory.read_data_address
add wave -noupdate -color Aquamarine -label response_data /tb_dlx_soc/dlx/core0/memory/i_l1_cache_to_memory.read_data
add wave -noupdate -divider WB_stage
add wave -noupdate -color Violet -label write_enable /tb_dlx_soc/dlx/core0/writeback/o_writeback_to_rf.write_enable
add wave -noupdate -color Violet -label write_data /tb_dlx_soc/dlx/core0/writeback/o_writeback_to_rf.write_data
add wave -noupdate -color Violet -label write_address /tb_dlx_soc/dlx/core0/writeback/o_writeback_to_rf.write_address
add wave -noupdate -divider registers
add wave -noupdate -color Yellow -radix decimal /tb_dlx_soc/dlx/core0/register_file/registers(1)
add wave -noupdate -color Yellow -radix decimal /tb_dlx_soc/dlx/core0/register_file/registers(2)
add wave -noupdate -color Yellow -radix decimal /tb_dlx_soc/dlx/core0/register_file/registers(3)
add wave -noupdate -color Yellow -radix decimal /tb_dlx_soc/dlx/core0/register_file/registers(30)
add wave -noupdate -color Yellow -radix decimal -childformat {{/tb_dlx_soc/dlx/core0/register_file/registers(31)(31) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(30) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(29) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(28) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(27) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(26) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(25) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(24) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(23) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(22) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(21) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(20) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(19) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(18) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(17) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(16) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(15) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(14) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(13) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(12) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(11) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(10) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(9) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(8) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(7) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(6) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(5) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(4) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(3) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(2) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(1) -radix unsigned} {/tb_dlx_soc/dlx/core0/register_file/registers(31)(0) -radix unsigned}} -subitemconfig {/tb_dlx_soc/dlx/core0/register_file/registers(31)(31) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(30) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(29) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(28) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(27) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(26) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(25) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(24) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(23) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(22) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(21) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(20) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(19) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(18) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(17) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(16) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(15) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(14) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(13) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(12) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(11) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(10) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(9) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(8) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(7) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(6) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(5) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(4) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(3) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(2) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(1) {-color Yellow -height 16 -radix unsigned} /tb_dlx_soc/dlx/core0/register_file/registers(31)(0) {-color Yellow -height 16 -radix unsigned}} /tb_dlx_soc/dlx/core0/register_file/registers(31)
add wave -noupdate -divider <NULL>
add wave -noupdate -color Gray90 -label instruction_cache_hit /tb_dlx_soc/dlx/core0/l1_cache/l1_cache/i0/line_hit_o
add wave -noupdate -color Gray90 -label data_cache_hit /tb_dlx_soc/dlx/core0/l1_cache/l1_cache/d0/line_hit_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2080 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 363
configure wave -valuecolwidth 148
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {100 ns}
