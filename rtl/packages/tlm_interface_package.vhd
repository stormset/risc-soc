library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dlx_config.all;
use work.control_word_package.all;
use work.types_amba4.all;

package tlm_interface_package is

    -- AXI
    type axi4_l1_cache_in_type is record
        aw_ready : std_logic;
        w_ready  : std_logic;
        b_valid  : std_logic;
        b_resp   : std_logic_vector(1 downto 0);
        ar_ready : std_logic;
        r_valid  : std_logic;
        r_resp   : std_logic_vector(3 downto 0);
        r_data   : std_logic_vector(L1CACHE_LINE_BITS - 1 downto 0);
        r_last   : std_logic;
        -- ACE signals
        ac_valid : std_logic;
        ac_snoop : std_logic_vector(3 downto 0); -- Table C3-19
        ac_prot  : std_logic_vector(2 downto 0);
        cr_ready : std_logic;
        cd_ready : std_logic;
    end record;

    type axi4_l1_cache_out_type is record
        aw_valid : std_logic;
        aw_bits  : axi4_metadata_type;
        w_valid  : std_logic;
        w_data   : std_logic_vector(L1CACHE_LINE_BITS - 1 downto 0);
        w_last   : std_logic;
        w_strb   : std_logic_vector(L1CACHE_BYTES_PER_LINE - 1 downto 0);
        b_ready  : std_logic;
        ar_valid : std_logic;
        ar_bits  : axi4_metadata_type;
        r_ready  : std_logic;
        -- ACE signals
        ar_domain : std_logic_vector(1 downto 0); -- 00=Non-shareable (single master in domain)
        ar_snoop  : std_logic_vector(3 downto 0); -- Table C3-7:
        ar_bar    : std_logic_vector(1 downto 0); -- read barrier transaction
        aw_domain : std_logic_vector(1 downto 0);
        aw_snoop  : std_logic_vector(3 downto 0); -- Table C3-8
        aw_bar    : std_logic_vector(1 downto 0); -- write barrier transaction
        ac_ready  : std_logic;
        cr_valid  : std_logic;
        cr_resp   : std_logic_vector(4 downto 0);
        cd_valid  : std_logic;
        cd_data   : std_logic_vector(L1CACHE_LINE_BITS - 1 downto 0);
        cd_last   : std_logic;
        rack      : std_logic;
        wack      : std_logic;
    end record;

    type mmu_to_axi_memory is record
        fetch_ready  : std_logic;
        read_request : std_logic;
        read_addr    : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type axi_memory_to_l1_cache is record
        ready        : std_logic;
        read_request : std_logic;
        read_addr    : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type fetch_to_l1_cache_t is record
        fetch_ready  : std_logic;
        read_request : std_logic;
        read_addr    : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type l1_cache_to_fetch_t is record
        mmu_ready         : std_logic;
        read_data_valid   : std_logic;
        read_data_address : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        read_data         : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type fetch_to_decode_t is record
        npc          : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        instruction  : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        predicted_pc : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type decode_to_rf_t is record
        read_address_1 : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
        read_address_2 : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
    end record;

    type rf_to_decode_t is record
        read_data_1 : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        read_data_2 : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type forwardings_to_decode_t is record
        npc_MEM          : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        alu_out_MEM      : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        writeback_out_WB : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type decode_to_fetch_t is record
        stall                     : std_logic;
        npc                       : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        branch_condition          : branch_condition_t;
        branch_taken              : std_logic;
        calculated_branch_address : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        previous_prediction       : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type decode_to_execute_t is record
        npc         : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        immediate   : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        rs1_address : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
        rs1_data    : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        rs2_address : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
        rs2_data    : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        rd_address  : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
    end record;

    type forwardings_to_execute_t is record
        alu_out_MEM      : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        writeback_out_WB : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type execute_to_memory_t is record
        npc                : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        memory_data        : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        execution_unit_out : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        rd_address         : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
    end record;

    type memory_to_l1_cache_t is record
        memory_stage_ready : std_logic;
        request_valid      : std_logic;
        request_write      : std_logic;
        address            : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        write_data         : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        strobe             : std_logic_vector(CFG_ADDR_BITS/8 - 1 downto 0);
    end record;

    type l1_cache_to_memory_t is record
        mmu_ready         : std_logic;
        read_data_valid   : std_logic;
        read_data_address : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        read_data         : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type memory_to_writeback_t is record
        npc                : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        execution_unit_out : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        memory_out         : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        rd_address         : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
    end record;

    type writeback_to_rf_t is record
        write_enable  : std_logic;
        write_address : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
        write_data    : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    type rf_to_writeback_t is record
        read_data_1 : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        read_data_2 : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    end record;

    -- feedback signals from datapath to the control unit
    type datapath_to_control_unit_t is record
        -- signals from IF stage
        fetch_busy : std_logic;

        -- signals from ID stage
        instruction_ID : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        mispredict_ID  : std_logic;

        -- signals from EXE stage
        rs1_EXE : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
        rs2_EXE : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
        rd_EXE  : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);

        -- signals from MEM stage
        memory_busy : std_logic;
        rd_MEM      : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);

        -- signals from WB stage
        rd_WB : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
    end record datapath_to_control_unit_t;

end package tlm_interface_package;
