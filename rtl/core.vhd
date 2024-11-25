library ieee;

use ieee.std_logic_1164.all;

use work.dlx_config.all;
use work.types_amba4.all;
use work.tlm_interface_package.all;
use work.control_word_package.all;

entity core is
    generic(
        NBIT                : integer;

        -- branch target buffer parameters
        CFG_BTB_NSETS           : integer;
        CFG_BTB_NWAYS           : integer;

        -- ALU parameters
        ADDER_BIT_PER_BLOCK : integer
    );
    port(
        i_clk          : in  std_logic;
        i_nrst         : in  std_logic;

        -- MPU interface
        i_mpu_flags1   : in std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
        i_mpu_flags2   : in std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
        o_mpu_addr1    : out std_logic_vector(NBIT - 1 downto 0);
        o_mpu_addr2    : out std_logic_vector(NBIT - 1 downto 0);

        -- AXI interface between L1 cache and system bus
        i_l1_cache_master_in  : in  axi4_master_in_type;
        o_l1_cache_master_out : out axi4_master_out_type
    );
end entity core;

architecture rtl of core is
    -- control unit output
    signal controls                   : controls_t;

    -- PC register
    signal pc_reg                     : std_logic_vector(NBIT-1 downto 0);

    -- fetch stage busy output
    signal fetch_busy                 : std_logic;
    -- memory stage busy output
    signal memory_busy                : std_logic;

    -- BPU outputs (from fetch stage)
    signal bpu_predicted_pc           : std_logic_vector(NBIT-1 downto 0);
    signal bpu_misprediction          : std_logic;

    -- connection between fetch stage and MMU
    signal fetch_to_l1_cache : fetch_to_l1_cache_t;
    signal l1_cache_to_fetch : l1_cache_to_fetch_t;

    -- connection between fetch and decode stage
    signal fetch_to_decode : fetch_to_decode_t;
    signal decode_to_fetch : decode_to_fetch_t;

    -- forwardings to decode stage
    signal forwardings_to_decode : forwardings_to_decode_t;

    -- connection between decode stage and register file
    signal decode_to_rf : decode_to_rf_t;
    signal rf_to_decode : rf_to_decode_t;

    -- connection between decode and execute stage
    signal decode_to_execute : decode_to_execute_t;

    -- forwardings to execute stage
    signal forwardings_to_execute : forwardings_to_execute_t;

    -- connection between execute and memory stage
    signal execute_to_memory : execute_to_memory_t;

    -- connection between memory stage and MMU
    signal memory_to_l1_cache : memory_to_l1_cache_t;
    signal l1_cache_to_memory : l1_cache_to_memory_t;

    -- connection between memory and writeback stage
    signal memory_to_writeback : memory_to_writeback_t;

    -- connection between writeback stage and register file
    signal writeback_to_rf : writeback_to_rf_t;

    -- connection between datapath and control unit
    signal datapath_to_control_unit : datapath_to_control_unit_t;
begin
    -- L1 cache
    l1_cache: entity work.axi_l1_cache
        port map(
            i_clk                => i_clk,
            i_nrst               => i_nrst,

            i_mpu_flags1         => i_mpu_flags1,
            i_mpu_flags2         => i_mpu_flags2,
            o_mpu_addr1          => o_mpu_addr1,
            o_mpu_addr2          => o_mpu_addr2,

            i_fetch_to_l1_cache  => fetch_to_l1_cache,
            o_l1_cache_to_fetch  => l1_cache_to_fetch,

            i_memory_to_l1_cache => memory_to_l1_cache,
            o_l1_cache_to_memory => l1_cache_to_memory,

            i_master_in          => i_l1_cache_master_in,
            o_master_out         => o_l1_cache_master_out
        );

    -- registers
    pc: process(i_clk)
    begin
        if i_nrst = '0' then
            pc_reg <= CFG_RESET_ADDRESS;
        elsif rising_edge(i_clk) then
            if controls.hazard_control.FE.stall_PC = '0' then
                pc_reg <= bpu_predicted_pc;
            end if;
        end if;
    end process;

    register_file: entity work.register_file
        generic map(
            ADDR_WIDTH => CFG_RF_ADDR_WIDTH,
            DATA_WIDTH => NBIT
        )    
        port map(
            i_clk      => i_clk,
            i_nrst     => i_nrst,

            i_addr_rd1 => decode_to_rf.read_address_1,
            i_addr_rd2 => decode_to_rf.read_address_2,

            i_wr_en    => writeback_to_rf.write_enable,
            i_addr_wr  => writeback_to_rf.write_address,
            i_data_wr  => writeback_to_rf.write_data,

            o_data1    => rf_to_decode.read_data_1,
            o_data2    => rf_to_decode.read_data_2
        );

    -- fetch stage
    fetch: entity work.fetch
        generic map(
            NBIT      => NBIT,
            CFG_BTB_NSETS => CFG_BTB_NSETS,
            CFG_BTB_NWAYS => CFG_BTB_NWAYS
        )
        port map(
            i_clk               => i_clk,
            i_nrst              => i_nrst,

            i_pc                => pc_reg,

            i_decode_to_fetch   => decode_to_fetch,

            i_l1_cache_to_fetch => l1_cache_to_fetch,

            i_hazard_control    => controls.hazard_control.FE,

            o_fetch_to_l1_cache => fetch_to_l1_cache,

            o_fetch_to_decode   => fetch_to_decode,

            o_bpu_predicted_pc  => bpu_predicted_pc,
            o_bpu_misprediction => bpu_misprediction,

            o_fetch_busy        => fetch_busy
        );

    -- decode stage
    forwardings_to_decode <= (
        npc_MEM          => execute_to_memory.npc,
        alu_out_MEM      => execute_to_memory.execution_unit_out,
        writeback_out_WB => writeback_to_rf.write_data
    );
    decode: entity work.decode
        generic map(
            NBIT => NBIT
        )
        port map(
            i_clk               => i_clk,
            i_nrst              => i_nrst,

            i_fetch_to_decode   => fetch_to_decode,

            i_rf_to_decode      => rf_to_decode,

            i_control           => controls.control_word.ID,

            i_hazard_control    => controls.hazard_control.ID,

            i_forwardings       => forwardings_to_decode,

            o_decode_to_rf      => decode_to_rf,

            o_decode_to_fetch   => decode_to_fetch,

            o_decode_to_execute => decode_to_execute
        );

    -- execute stage
    forwardings_to_execute <= (
        alu_out_MEM      => execute_to_memory.execution_unit_out,
        writeback_out_WB => writeback_to_rf.write_data
    );
    execute: entity work.execute
        generic map(
            NBIT                => NBIT,
            ADDER_BIT_PER_BLOCK => ADDER_BIT_PER_BLOCK
        )
        port map(
            i_clk               => i_clk,
            i_nrst              => i_nrst,

            i_decode_to_execute => decode_to_execute,

            i_control           => controls.control_word.EXE,

            i_hazard_control    => controls.hazard_control.EXE,

            i_forwardings       => forwardings_to_execute,

            o_execute_to_memory => execute_to_memory
        );

    -- memory stage
    memory: entity work.memory
        generic map(
            NBIT => NBIT
        )
        port map(
            i_clk                 => i_clk,
            i_nrst                => i_nrst,

            i_execute_to_memory   => execute_to_memory,

            i_l1_cache_to_memory  => l1_cache_to_memory,

            i_control             => controls.control_word.MEM,

            i_hazard_control      => controls.hazard_control.MEM,

            o_memory_to_l1_cache  => memory_to_l1_cache,

            o_memory_to_writeback => memory_to_writeback,

            o_busy                => memory_busy
        );

    -- writeback stage
    writeback: entity work.writeback
        generic map(
            NBIT => NBIT
        )
        port map(
            i_clk                 => i_clk,
            i_nrst                => i_nrst,

            i_memory_to_writeback => memory_to_writeback,

            i_control             => controls.control_word.WB,

            i_hazard_control      => controls.hazard_control.WB,

            o_writeback_to_rf     => writeback_to_rf
        );

    -- control unit
    datapath_to_control_unit <= (
        -- signals from IF stage
        fetch_busy     => fetch_busy,

        -- signals from ID stage
        instruction_ID => fetch_to_decode.instruction,
        mispredict_ID  => bpu_misprediction,

        -- signals from EXE stage
        rs1_EXE        => decode_to_execute.rs1_address,
        rs2_EXE        => decode_to_execute.rs2_address,
        rd_EXE         => decode_to_execute.rd_address,

        -- signals from MEM stage
        memory_busy    => memory_busy,
        rd_MEM         => execute_to_memory.rd_address,

        -- signals from WB stage
        rd_WB          => memory_to_writeback.rd_address
    );
    control_unit: entity work.control_unit
        port map(
            i_clk        => i_clk,
            i_nrst       => i_nrst,
            datapath_in  => datapath_to_control_unit,
            controls_out => controls
        );
end architecture rtl;
