library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dlx_config.all;
use work.tlm_interface_package.all;
use work.control_word_package.all;

entity decode is
    generic(
        NBIT : integer
    );
    port(
        i_clk               : in  std_logic;
        i_nrst              : in  std_logic;
        i_fetch_to_decode   : in  fetch_to_decode_t;
        i_rf_to_decode      : in  rf_to_decode_t;
        i_control           : in  ID_control_word_t;
        i_hazard_control    : in  ID_hazard_control_t;
        i_forwardings       : in  forwardings_to_decode_t;
        o_decode_to_rf      : out decode_to_rf_t;
        o_decode_to_fetch   : out decode_to_fetch_t;
        o_decode_to_execute : out decode_to_execute_t
    );
end decode;

architecture rtl of decode is
    -- pipeline registers of decode stage
    type registers_t is record
        npc                       : std_logic_vector(NBIT-1 downto 0);
        immediate                 : std_logic_vector(NBIT-1 downto 0);
        rs1_address               : std_logic_vector(CFG_RF_ADDR_WIDTH-1 downto 0);
        rs1_data                  : std_logic_vector(NBIT-1 downto 0);
        rs2_address               : std_logic_vector(CFG_RF_ADDR_WIDTH-1 downto 0);
        rs2_data                  : std_logic_vector(NBIT-1 downto 0);
        rd_address                : std_logic_vector(CFG_RF_ADDR_WIDTH-1 downto 0);
        branch_condition          : branch_condition_t;
        branch_taken              : std_logic;
        calculated_branch_address : std_logic_vector(NBIT-1 downto 0);
        previous_prediction       : std_logic_vector(NBIT-1 downto 0);
    end record;

    constant RESET_VALUE : registers_t := (
        npc                       => (others => '0'),
        immediate                 => (others => '0'),
        rs1_address               => (others => '0'),
        rs1_data                  => (others => '0'),
        rs2_address               => (others => '0'),
        rs2_data                  => (others => '0'),
        rd_address                => (others => '0'),
        branch_condition          => never,
        branch_taken              => '0',
        calculated_branch_address => (others => '0'),
        previous_prediction       => (others => '0')
    );

    signal r, r_next : registers_t;
begin
    -- register file connection
    o_decode_to_rf.read_address_1 <= i_fetch_to_decode.instruction(rs1_range);
    o_decode_to_rf.read_address_2 <= i_fetch_to_decode.instruction(rs2_range);

    -- register source addresses (for hazard control)
    r_next.rs1_address <= i_fetch_to_decode.instruction(rs1_range);
    r_next.rs2_address <= i_fetch_to_decode.instruction(rs2_range);

    -- register branch condition (for BPU)
    r_next.branch_condition <= i_control.branch_condition;

    -- register NPC (for writeback for branch and link)
    r_next.npc <= i_fetch_to_decode.npc;

    r_next.previous_prediction <= i_fetch_to_decode.predicted_pc;

    -- destination register address
    rd_mux: process (all)
    begin
        case i_control.rd_address_selection is
            when rd_i_type =>
                r_next.rd_address <= i_fetch_to_decode.instruction(rs2_range);
            when rd_r_type =>
                r_next.rd_address <= i_fetch_to_decode.instruction(rd_range);
            when rd_jump_link_type =>
                r_next.rd_address <= CFG_LINK_REGISTER_ADDRESS;
        end case;
    end process rd_mux;

    -- immediate sign extension
    imm_sign_extend_mux: process (all)
    begin
        case i_control.immediate_selection is
            when signed_immediate =>
                r_next.immediate <= std_logic_vector(resize(signed(i_fetch_to_decode.instruction(imm_range)), NBIT));
            when unsigned_immediate =>
                r_next.immediate <= std_logic_vector(resize(unsigned(i_fetch_to_decode.instruction(imm_range)), NBIT));
            when signed_jump_offset =>
                r_next.immediate <= std_logic_vector(resize(signed(i_fetch_to_decode.instruction(jump_offset_range)), NBIT));
        end case;
    end process imm_sign_extend_mux;

    -- forwarding for rs1 (value is used by execute stage and the branch offset adder)
    rs1_forwarding_mux: process (all)
    begin
        case i_hazard_control.rs1_forwarding_sel is
            when alu_out_at_mem_forward =>
                r_next.rs1_data <= i_forwardings.alu_out_MEM;
            when wb_forward =>
                r_next.rs1_data <= i_forwardings.writeback_out_WB;
            when npc_at_exe_forward =>
                r_next.rs1_data <= r.npc;
            when npc_at_mem_forward =>
                r_next.rs1_data <= i_forwardings.npc_MEM;
            when others =>
                r_next.rs1_data <= i_rf_to_decode.read_data_1;
        end case;
    end process rs1_forwarding_mux;

    -- forwarding for rs2
    rs2_forwarding_mux: process (all)
    begin
        case i_hazard_control.rs2_forwarding_sel is
            when wb_forward =>
                r_next.rs2_data <= i_forwardings.writeback_out_WB;
            when others =>
                r_next.rs2_data <= i_rf_to_decode.read_data_2;
        end case;
    end process rs2_forwarding_mux;

    -- branch offset adder and branch decision
    branch_unit : block
        signal relative_target     : std_logic_vector(NBIT-1 downto 0);
        signal branch_taken_target : std_logic_vector(NBIT-1 downto 0);
        signal rs1_all_zero        : std_logic;
    begin
        -- adder to calculate relative jump address
        offset_adder: entity work.sklansky_tree_adder
            generic map(
                NBIT => NBIT
            )
            port map(
                a       => i_fetch_to_decode.npc,
                b       => r_next.immediate,
                cin     => '0',
                s       => relative_target,
                cout    => open
            );

        -- mux to select target address: relative or register
        target_address_mux: process (all)
        begin
            case i_control.branch_target is
                when imm =>
                    branch_taken_target <= relative_target;
                when reg =>
                    branch_taken_target <= r_next.rs1_data;
            end case;
        end process target_address_mux;

        -- check if rs1 register is all 0 (for BEQZ, BNEQZ)
        zero_comp: process (all)
        begin
            if to_integer(signed(r_next.rs1_data)) = 0 then
                rs1_all_zero <= '1';
            else
                rs1_all_zero <= '0';
            end if;
        end process zero_comp;

        -- decide if branch is taken
        branch_decision: process(all)
        begin
            case i_control.branch_condition is
                when never =>
                    r_next.branch_taken <= '0';
                when always =>
                    r_next.branch_taken <= '1';
                when equal_zero =>
                    r_next.branch_taken <= rs1_all_zero;
                when not_equal_zero =>
                    r_next.branch_taken <= not rs1_all_zero;
            end case;
        end process branch_decision;

        -- mux to select actual target address depending on the branch decision
        actual_target_address_mux: process (all)
        begin
            if r_next.branch_taken = '1' then
                r_next.calculated_branch_address <= branch_taken_target;
            else
                r_next.calculated_branch_address <= i_fetch_to_decode.npc;
            end if;
        end process actual_target_address_mux;
    end block branch_unit;

    -- pipeline registers
    regs : process(i_clk)
    begin 
        if rising_edge(i_clk) then
            if i_nrst = '0' or i_hazard_control.flush = '1' then
                r <= RESET_VALUE;
            elsif i_hazard_control.stall = '0' then
                r <= r_next;
            end if;
        end if; 
    end process;

    -- output to decode stage
    o_decode_to_fetch <= (
        stall                     => i_hazard_control.stall,
        npc                       => r.npc,
        branch_condition          => r.branch_condition,
        branch_taken              => r.branch_taken,
        calculated_branch_address => r.calculated_branch_address,
        previous_prediction       => r.previous_prediction
    );

    -- output to execute stage
    o_decode_to_execute <= (
        npc                       => r.npc,
        immediate                 => r.immediate,
        rs1_address               => r.rs1_address,
        rs1_data                  => r.rs1_data,
        rs2_address               => r.rs2_address,
        rs2_data                  => r.rs2_data,
        rd_address                => r.rd_address
    );
end;
