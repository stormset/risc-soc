library ieee;

use ieee.std_logic_1164.all;

use work.dlx_config.all;
use work.utils_package.all;
use work.tlm_interface_package.all;
use work.types_amba4.all;

entity dlx_soc_top is
    generic(
        RAM_INIT_FILE : string
    );
    port(
        i_clk  : in  std_logic;
        i_nrst : in  std_logic
    );
end entity dlx_soc_top;

architecture rtl of dlx_soc_top is
    -- bus #0 connections
    signal master_inputs  : bus0_xmst_in_vector;
    signal master_outputs : bus0_xmst_out_vector;
    signal slave_configs  : bus0_xslv_cfg_vector;
    signal slave_inputs   : bus0_xslv_in_vector;
    signal slave_outputs  : bus0_xslv_out_vector;

    -- MPU connections
    signal mpu_addr1  : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    signal mpu_addr2  : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    signal mpu_flags1 : std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
    signal mpu_flags2 : std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
begin

    -- AXI crossbar for bus #0
    axi_crossbar0 : entity work.axi_crossbar
        generic map(
            async_reset => false
        )
        port map(
            i_clk           => i_clk,
            i_nrst          => i_nrst,

            i_slave_configs => slave_configs,

            i_slave_outs    => slave_outputs,
            o_slave_ins     => slave_inputs,

            i_master_outs   => master_outputs,
            o_master_ins    => master_inputs
        );        

    -- SRAM (internal firmware RAM) - mapped @ 0x00000000..0x00007fff (32 KiB)
    --     INIT_FILE: file that contains firmware to be loaded for simulation
    sram : entity work.axi4_sram
        generic map(
            XADDR         => 16#00000#,
            XMASK         => 16#ffff8#,
            ADDRESS_WIDTH => 15,
            INIT_FILE     => RAM_INIT_FILE
        )    
        port map(
            i_clk          => i_clk,
            i_nrst         => i_nrst,

            o_slave_config => slave_configs(0),

            i_slave_in     => slave_inputs(0),

            o_slave_out    => slave_outputs(0)
        );

    -- memory protection unit (static configuration for now, later should be through CSR)
    memory_protection_unit0 : entity work.memory_protection_unit port map (
        i_clk    => i_clk,
        i_nrst   => i_nrst,

        i_addr1  => mpu_addr1,
        i_addr2  => mpu_addr2,

        o_flags1 => mpu_flags1,
        o_flags2 => mpu_flags2
    );

    -- core #0
    core0: entity work.core
        generic map(
            NBIT                => CFG_ADDR_BITS,
            CFG_BTB_NSETS           => CFG_BTB_NSETS,
            CFG_BTB_NWAYS           => CFG_BTB_NWAYS,
            ADDER_BIT_PER_BLOCK => CFG_SKLANSKY_ADDER_BIT_PER_BLOCK
        )    
        port map(
            i_clk                 => i_clk,
            i_nrst                => i_nrst,

            i_mpu_flags1          => mpu_flags1,
            i_mpu_flags2          => mpu_flags2,
            o_mpu_addr1           => mpu_addr1,
            o_mpu_addr2           => mpu_addr2,

            i_l1_cache_master_in  => master_inputs(0),
            o_l1_cache_master_out => master_outputs(0)
        );
end architecture rtl;
