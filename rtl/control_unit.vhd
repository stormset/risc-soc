library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dlx_config.all;
use work.tlm_interface_package.all;
use work.control_word_package.all;

entity control_unit is
    port(
        i_clk          : in  std_logic;
        i_nrst         : in  std_logic;
        datapath_in  : in  datapath_to_control_unit_t;
        controls_out : out controls_t
    );
end entity control_unit;

architecture rtl of control_unit is
    -- control unit outputs
    signal control_word_s   : control_word_t;
    signal hazard_control_s : hazard_control_t;

    -- delay lines for control signals
    signal cw_EXE_stage_EXE_s                                     : EXE_control_word_t;
    signal cw_MEM_stage_EXE_s, cw_MEM_stage_MEM_s                 : MEM_control_word_t;
    signal cw_WB_stage_EXE_s, cw_WB_stage_MEM_s, cw_WB_stage_WB_s : WB_control_word_t;

    -- synthesis translate_off
    signal opcode_ID : opcode_t;
    signal func_ID   : func_t;
    -- synthesis translate_on
begin
    -- lookup control signals for specific operation
    control_word_decode: process(all)
    begin
        -- synthesis translate_off
        opcode_ID <= opcode_t'val(to_integer(unsigned(datapath_in.instruction_ID(opcode_range))));
        func_ID   <= func_t'val(to_integer(unsigned(datapath_in.instruction_ID(func_range)))) when opcode_ID = OPCODE_RTYPE else FUNC_00;
        -- synthesis translate_on

        if opcode_t'val(to_integer(unsigned(datapath_in.instruction_ID(opcode_range)))) = OPCODE_RTYPE then
            control_word_s <= rtype_lut(to_integer(unsigned(datapath_in.instruction_ID(func_range))));
        else
            control_word_s <= others_lut(to_integer(unsigned(datapath_in.instruction_ID(opcode_range))));
        end if;
    end process control_word_decode;

    -- 5-stage pipeline
    pipeline: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_nrst = '0' or hazard_control_s.ID.flush = '1' then
                cw_EXE_stage_EXE_s <= NOP_cw.EXE;
                cw_MEM_stage_EXE_s <= NOP_cw.MEM;
                cw_WB_stage_EXE_s  <= NOP_cw.WB;
            elsif hazard_control_s.ID.stall = '0' then
                cw_EXE_stage_EXE_s <= control_word_s.EXE;
                cw_MEM_stage_EXE_s <= control_word_s.MEM;
                cw_WB_stage_EXE_s  <= control_word_s.WB;
            end if;

            if i_nrst = '0' or hazard_control_s.EXE.flush = '1' then
                cw_MEM_stage_MEM_s <= NOP_cw.MEM;
                cw_WB_stage_MEM_s  <= NOP_cw.WB;
            elsif hazard_control_s.EXE.stall = '0' then
                cw_MEM_stage_MEM_s <= cw_MEM_stage_EXE_s;
                cw_WB_stage_MEM_s  <= cw_WB_stage_EXE_s;
            end if;

            if i_nrst = '0' or hazard_control_s.MEM.flush = '1' then
                cw_WB_stage_WB_s   <= NOP_cw.WB;
            elsif hazard_control_s.MEM.stall = '0' then
                cw_WB_stage_WB_s   <= cw_WB_stage_MEM_s;
            end if;
        end if;
    end process pipeline;

    -- handle hazards that can't be solved by forwarding
    hazard_detection: process(all)
        variable ID_branch_uses_RF           : boolean;
        variable EXE_writes_to_register_file : boolean;
        variable EXE_is_a_store              : boolean;
        variable MEM_is_a_load               : boolean;
        variable rs1_address_ID, rs2_address_ID : std_logic_vector(CFG_RF_ADDR_WIDTH-1 downto 0);
    begin
        -- default hazard control assignments
        hazard_control_s.FE.stall_PC <= '0';
        hazard_control_s.FE.stall    <= '0';
        hazard_control_s.ID.stall    <= '0';
        hazard_control_s.EXE.stall   <= '0';
        hazard_control_s.MEM.stall   <= '0';
        hazard_control_s.WB.stall    <= '0';

        hazard_control_s.FE.flush    <= '0';
        hazard_control_s.ID.flush    <= '0';
        hazard_control_s.EXE.flush   <= '0';
        hazard_control_s.MEM.flush   <= '0';
        hazard_control_s.WB.flush    <= '0';

        -- get rs1, rs2 addresses from instruction in ID stage
        rs1_address_ID := datapath_in.instruction_ID(rs1_range);
        rs2_address_ID := datapath_in.instruction_ID(rs2_range);

        -- instruction in DECODE stage uses register file output
        ID_branch_uses_RF := (control_word_s.ID.branch_target    = reg or
                              control_word_s.ID.branch_condition = equal_zero or
                              control_word_s.ID.branch_condition = not_equal_zero);

        -- instruction in EXECUTE stage writes back to register file
        EXE_writes_to_register_file := (cw_WB_stage_EXE_s.rf_write_enable = '1');

        -- instruction in EXECUTE stage is a store instruction
        EXE_is_a_store := (cw_MEM_stage_EXE_s.memory_write_enable = '1');

        -- instruction in MEMORY stage is a load instruction
        MEM_is_a_load := (cw_WB_stage_MEM_s.rf_write_enable = '1' and cw_WB_stage_MEM_s.writeback_selection = memory_out);

        -- RAW HAZARD 1: branch instruction in ID needs register that is going to be written by instruction in EXE
        if (EXE_writes_to_register_file and cw_WB_stage_EXE_s.writeback_selection /= npc) and
        to_integer(unsigned(datapath_in.rd_EXE)) /= 0 and
        (ID_branch_uses_RF and rs1_address_ID = datapath_in.rd_EXE) then
            hazard_control_s.FE.stall_PC <= '1';
            hazard_control_s.FE.stall    <= '1';
            hazard_control_s.ID.stall    <= '1';
            hazard_control_s.ID.flush    <= '1';

        -- RAW HAZARD 2: branch instruction in ID needs register that is going to be written by load instruction in MEM
        elsif MEM_is_a_load and
        to_integer(unsigned(datapath_in.rd_MEM)) /= 0 and
        (ID_branch_uses_RF and rs1_address_ID = datapath_in.rd_MEM) then
            hazard_control_s.FE.stall_PC <= '1';
            hazard_control_s.FE.stall    <= '1';
            hazard_control_s.ID.stall    <= '1';
            hazard_control_s.ID.flush    <= '1';

            
            if datapath_in.memory_busy = '1' then
                hazard_control_s.EXE.stall   <= '1';
                hazard_control_s.MEM.stall   <= '1';
                hazard_control_s.MEM.flush   <= '1';
            end if;

        -- RAW HAZARD 3: instruction in EXE needs register that is going to be written by load instruction in MEM
        elsif MEM_is_a_load and
        cw_EXE_stage_EXE_s.is_branch = '0' and
        to_integer(unsigned(datapath_in.rd_MEM)) /=0 and
        (datapath_in.rs1_EXE = datapath_in.rd_MEM or
        ((cw_EXE_stage_EXE_s.second_operand_type = reg or EXE_is_a_store) and datapath_in.rs2_EXE = datapath_in.rd_MEM)) then
            hazard_control_s.FE.stall_PC <= '1';
            hazard_control_s.FE.stall    <= '1';
            hazard_control_s.ID.stall    <= '1';
            hazard_control_s.EXE.stall   <= '1';

            if datapath_in.memory_busy = '0' then
                hazard_control_s.EXE.flush   <= '1';
            else
                hazard_control_s.MEM.stall   <= '1';
                hazard_control_s.MEM.flush   <= '1';
            end if;
        
        -- fetch busy (because of instruction cache miss, etc...)
        elsif datapath_in.fetch_busy = '1' then
            hazard_control_s.FE.stall_PC <= '1';

            if datapath_in.memory_busy = '1' then
                hazard_control_s.ID.stall    <= '1';
                hazard_control_s.EXE.stall   <= '1';
                hazard_control_s.MEM.stall   <= '1';
                hazard_control_s.MEM.flush   <= '1';
            elsif datapath_in.mispredict_ID = '1' then
                hazard_control_s.ID.stall    <= '1';
            end if;

        -- memory stage busy (because of data cache miss, etc...)
        elsif datapath_in.memory_busy = '1' then
            hazard_control_s.FE.stall_PC <= '1';
            hazard_control_s.FE.stall    <= '1';
            hazard_control_s.ID.stall    <= '1';
            hazard_control_s.EXE.stall   <= '1';
            hazard_control_s.MEM.stall   <= '1';
            hazard_control_s.MEM.flush   <= '1';

        -- SPECULATIVE EXECUTION HAZARD: mispredicted branch
        elsif datapath_in.mispredict_ID = '1' then
            hazard_control_s.FE.stall    <= '1';
            hazard_control_s.FE.flush    <= '1';
            hazard_control_s.ID.flush    <= '1';

        end if;
    end process hazard_detection;

    -- forward stage outputs to avoid specific hazards
    forwarding: process(all)
        variable MEM_writes_not_NPC_to_register_file : boolean;
        variable MEM_is_a_load_or_store              : boolean;
        variable WB_writes_to_register_file          : boolean;
        variable rs1_address_ID, rs2_address_ID      : std_logic_vector(CFG_RF_ADDR_WIDTH-1 downto 0);
    begin
        -- default hazard control assignments
        hazard_control_s.ID.rs1_forwarding_sel  <= no_forward;
        hazard_control_s.ID.rs2_forwarding_sel  <= no_forward;
        hazard_control_s.EXE.rs1_forwarding_sel <= no_forward;
        hazard_control_s.EXE.rs2_forwarding_sel <= no_forward;

        -- get rs1, rs2 addresses from instruction in ID stage
        rs1_address_ID := datapath_in.instruction_ID(rs1_range);
        rs2_address_ID := datapath_in.instruction_ID(rs2_range);

        -- instruction in MEMORY stage writes back to register file but not NPC
        MEM_writes_not_NPC_to_register_file := cw_WB_stage_MEM_s.rf_write_enable = '0' or
                                               (cw_WB_stage_MEM_s.rf_write_enable = '1' and
                                                cw_WB_stage_MEM_s.writeback_selection /= npc);

        MEM_is_a_load_or_store := (cw_WB_stage_MEM_s.rf_write_enable = '1' and cw_WB_stage_MEM_s.writeback_selection = memory_out) or
                                  cw_MEM_stage_MEM_s.memory_write_enable = '1';

        -- instruction in WRITEBACK stage writes back to register file
        WB_writes_to_register_file := (cw_WB_stage_WB_s.rf_write_enable = '1');

        -- RS1 forwarding to ID stage
        if to_integer(unsigned(rs1_address_ID)) /= 0 then
            -- RS1: forward ALU output from MEM to ID stage
            if (MEM_writes_not_NPC_to_register_file and not MEM_is_a_load_or_store) and
            rs1_address_ID = datapath_in.rd_MEM then
                hazard_control_s.ID.rs1_forwarding_sel <= alu_out_at_mem_forward;

            -- RS1: forward writeback data from WB to ID stage
            elsif WB_writes_to_register_file and
            rs1_address_ID = datapath_in.rd_WB then
                hazard_control_s.ID.rs1_forwarding_sel <= wb_forward;

            -- RS1: forward NPC from EXE to ID stage
            elsif cw_WB_stage_EXE_s.writeback_selection = npc and
            to_integer(unsigned(rs1_address_ID)) = 31 then
                hazard_control_s.ID.rs1_forwarding_sel <= npc_at_exe_forward;

            -- RS1: forward NPC from MEM to ID stage
            elsif cw_WB_stage_MEM_s.writeback_selection = npc and
            to_integer(unsigned(rs1_address_ID)) = 31 then
                hazard_control_s.ID.rs1_forwarding_sel <= npc_at_mem_forward;
                
            end if;
        end if;

        -- RS1 forwarding to EXE stage
        if to_integer(unsigned(datapath_in.rs1_EXE)) /= 0 then
            -- RS1: forward ALU output from MEM to EXE stage
            if (MEM_writes_not_NPC_to_register_file and not MEM_is_a_load_or_store) and
            datapath_in.rs1_EXE = datapath_in.rd_MEM then
                hazard_control_s.EXE.rs1_forwarding_sel <= alu_out_at_mem_forward;

            -- RS1: forward writeback data from WB to EXE stage
            elsif WB_writes_to_register_file and
            datapath_in.rs1_EXE = datapath_in.rd_WB then
                hazard_control_s.EXE.rs1_forwarding_sel <= wb_forward;

            end if;
        end if;

        -- RS2 forwarding to ID stage
        if to_integer(unsigned(rs2_address_ID)) /= 0 then
            -- RS2: forward writeback data from WB to ID stage
            if WB_writes_to_register_file and
            rs2_address_ID = datapath_in.rd_WB then
                hazard_control_s.ID.rs2_forwarding_sel <= wb_forward;

            end if;
        end if;

        -- RS2 forwarding to EXE stage
        if to_integer(unsigned(datapath_in.rs2_EXE)) /= 0 then
            -- RS2: forward ALU output from MEM to EXE stage
            if (MEM_writes_not_NPC_to_register_file and not MEM_is_a_load_or_store) and
            datapath_in.rs2_EXE = datapath_in.rd_MEM then
                hazard_control_s.EXE.rs2_forwarding_sel <= alu_out_at_mem_forward;

            -- RS2: forward writeback data from WB to EXE stage
            elsif WB_writes_to_register_file and
            datapath_in.rs2_EXE = datapath_in.rd_WB then
                hazard_control_s.EXE.rs2_forwarding_sel <= wb_forward;

            -- RS2: forward NPC from MEM to EXE stage
            elsif cw_WB_stage_MEM_s.writeback_selection = npc and
            to_integer(unsigned(datapath_in.rs2_EXE)) = 31 then
                hazard_control_s.EXE.rs2_forwarding_sel <= npc_at_mem_forward;

            end if;
        end if;
    end process forwarding;

    -- assign datapath control signals
    controls_out <= (
        control_word => (
            ID  => control_word_s.ID,
            EXE => cw_EXE_stage_EXE_s,
            MEM => cw_MEM_stage_MEM_s,
            WB  => cw_WB_stage_WB_s    
        ),
        hazard_control => hazard_control_s
    );
end architecture rtl;
