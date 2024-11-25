

<h1 style="margin-bottom: 0px;">
DLX System-On-Chip
</h1>
<h3 style="padding: 0px; margin: 0px;">

</h3>
<br>

Full **ASIC** design flow of a **SoC**, with a **RISC** core implementing the **DLX ISA**, an **AMBA AXI4 System Bus**,
**L1 Cache**, **Memory Protection Unit** and a **ROM**.

### Features
The **DLX** ("Deluxe") is a **RISC** processor architecture. It is essentially a modernized Stanford MIPS CPU. It has a 32-bit load/store architecture and the classic five stage RISC pipeline (fetch, decode, execute, memory, writeback). This implementation applies this core in an SoC environment and offers the following features:

- **Speculative execution** with **Set-Associative Branch Target Buffer** and 2 cc. branch delay slot
- Operand forwarding
- Hazard handling
- **Sklansky Tree** based parallel prefix adder (with adjustable **sparsity** to achieve desired **PPA**-tradeoffs)
- **Radix-4 Booth Multiplier**
- **Level-1 Cache subsystem** (4-way, 32KB both instruction and data cahce, LRU replacement policy, pipelined access supporting multiple outstanding requests; adapted from [River CPU](https://github.com/sergeykhbr/riscv_vhdl))
- **AMBA AXI4 System Bus** (an AXI Crossbar supports the mapping of slave devices; adapted from [River CPU](https://github.com/sergeykhbr/riscv_vhdl))
- Internal SRAM array for First-Stage Boot Loader (32KB @ `0x0000000 - 0x00007fff`)
- **Memory Protection Unit**
- Full subsystem verification using **UVM** (not yet available, as workshop activities are ongoing)
- **Hardening**, **Design for Test** (not yet available, as workshop activities are ongoing)

### Upcoming Features
- Fast context switch support with [**windowed register file**](rtl/windowed_register_file)
- Multi-core support with cache coherence (AMBA ACE protocol)
- External SPI Flash support
___

## Simulation flow
The simulation flow is fully automated with TCL scripts, from compiling your assembly program, loading it into the boot
ROM and showing the relevant waveforms. Simply follow these steps:

```bash
# Go into the simulation related directory
$ cd sim

# Run your favourite HDL simulator (ModelSim and Xcelium were tested)
$ vsim &

# Run TCL script `sim.do` inside your simulator:
# this takes as #1 argument the assembly file to be compiled and loaded into the boot ROM
$ do sim.do ./benchmarks/factorial.asm
```

## Sythesis flow
The synthesis is automated with TCL scripts, however it leaves more room for the user to play with the parameters to achieve the targeted PPA goals.

A script to optimize leakage power consumption is also [included](syn/leakage_power_optimizer.tcl), and can be run after synthesis. It swaps library cells with their respective HVT/SVT counterparts on non-critical paths in an incremental manner.

Special care needs to be taken compiling the memory arrays (for caches, queues etc.) used in the SoC (see: [memories folder](rtl/memories)). This can be carried out by an open source RAM compiler
like [OpenRAM](https://openram.org),

```bash
# Go into the synthesis related directory
$ cd syn

# Run Synopsis Design Vision
$ design_vision &

# Run synthesis script
$ source syn.tcl
```
___

## Project structure
The directory map of the project:

```
.
└── rtl                                # design sources
    ├── alu                            # arithmetic logic unit
    ├── axi_sram                       # SRAM array with AXI4 slave interface
    ├── barrel_shifter                 # barrel shifter
    ├── booth_multiplier               # radix-4 booth multiplier
    ├── common                         # RTL designs used in multiple designs
    ├── l1_cache                       # L1 cache subsystem
    ├── memories                       # memory elements used in the design (see note at `Sythesis flow`)
    ├── memory_protection_unit         # memory protection unit (with read, write, execute, cacheable flags)
    ├── packages                       # packages
        ├── dlx_config.vhd             # parameters of the SoC: BTB, cache, system bus, etc.
        ├── control_word_package.vhd   # ISA-related types, constants
        ├── tlm_interface_package.vhd  # interfaces between various subsystems/units
        ├── types_amba4.vhd            # AMBA related types, constants
        ├── utils_package.vhd          # utility functions
    ├── register_file                  # register bank
    ├── sklansky_tree_adder            # parallel prefix adder
    ├── system_bus                     # system bus related designs
    ├── dlx_soc_top.vhd                # TOP level design of the SoC
    ├── core.vhd                       # core implementing the DLX ISA
    ├── fetch.vhd                      # fetch pipeline stage
    ├── decode.vhd                     # decode pipeline stage
    ├── execute.vhd                    # execute pipeline stage
    ├── memory.vhd                     # memory pipeline stage
    ├── writeback.vhd                  # writeback pipeline stage
    ├── branch_target_buffer.vhd       # branch target buffer
    ├── control_unit.vhd               # control unit
└── sim                                # simulation sources
    ├── assembler                      # assembler written in PERL
    ├── benchmarks                     # assembly files for benchmarking
    ├── ram_images                     # compiled RAM images of the benchmark codes
└── syn                                # synthesis sources
    ├── dlx_constraints.sdc            # synthesis constraints
    ├── leakage_power_optimizer.tcl    # script to optimize leakage power
    ├── sources.f                      # source file list
    ├── syn.tcl                        # synthesis script
```
