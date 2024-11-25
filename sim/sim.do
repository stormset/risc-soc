# this script carries out the simulation flow
# command line arguments:
#     unnamed argument #1: assembly file path to be compiled and 

# SRAM size (32 KiB)
quietly set SRAM_SIZE 32768
quietly set DATA_BUS_BYTES 4

# assembly file path from argument #1
quietly set asm_path $1
quietly set assembler_output "[file rootname [file tail $asm_path]].mem"

# compile assembly file (parameter) and prepare RAM image for simulation
puts "Compiling assembly and preparing RAM image file..."
exec "./assembler/prepare_ram_image.sh" $asm_path [expr { $SRAM_SIZE / $DATA_BUS_BYTES }]

# compile DLX SoC design source files
puts "Compiling SoC design sources..."
vcom -source -F ./sources.f

# compile testbench
puts "Compiling testbench..."
vcom ./tb_dlx_soc.vhd

# start simulation and configure wave viewer
puts "Starting simulation..."
vsim work.tb_dlx_soc -gRAM_INIT_FILE=$assembler_output -do ./wave.do

# run simulation
puts "Running simulation..."
run 3000 ns

# go to active cursor on wave window
quietly wave cursor see
