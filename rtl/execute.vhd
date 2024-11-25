library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.dlx_config.all;
use work.tlm_interface_package.all;
use work.control_word_package.all;

entity execute is
    generic (
        NBIT                : integer;
        ADDER_BIT_PER_BLOCK : integer
    );
    port (
        i_clk               : in  std_logic;
        i_nrst              : in  std_logic;
        i_decode_to_execute : in  decode_to_execute_t;
        i_control           : in  EXE_control_word_t;
        i_hazard_control    : in  EXE_hazard_control_t;
        i_forwardings       : in  forwardings_to_execute_t;
        o_execute_to_memory : out execute_to_memory_t
    );
end execute;

architecture rtl of execute is
    -- operands of execution units
    signal rs1, rs2 : std_logic_vector(NBIT - 1 downto 0);

    -- forwarded rs2
    signal rs2_forwarded : std_logic_vector(NBIT - 1 downto 0);

    -- pipeline registers of execute stage
    type registers_t is record
        npc                : std_logic_vector(NBIT - 1 downto 0);
        memory_data        : std_logic_vector(NBIT - 1 downto 0);
        execution_unit_out : std_logic_vector(NBIT - 1 downto 0);
        rd_address         : std_logic_vector(CFG_RF_ADDR_WIDTH - 1 downto 0);
    end record;

    constant RESET_VALUE : registers_t := (
        npc                => (others => '0'),
        memory_data        => (others => '0'),
        execution_unit_out => (others => '0'),
        rd_address         => (others => '0')
    );

    signal r, r_next : registers_t;
begin
    -- register NPC (for writeback for branch and link)
    r_next.npc <= i_decode_to_execute.npc;

    -- register destination register address
    r_next.rd_address <= i_decode_to_execute.rd_address;

    -- register data input (rs2) for memory stage
    r_next.memory_data <= rs2_forwarded;

    -- forwarding for rs1
    rs1_forwarding_mux : process (all)
    begin
        case i_hazard_control.rs1_forwarding_sel is
            when alu_out_at_mem_forward =>
                rs1 <= i_forwardings.alu_out_MEM;
            when wb_forward =>
                rs1 <= i_forwardings.writeback_out_WB;
            when others =>
                rs1 <= i_decode_to_execute.rs1_data;
        end case;
    end process rs1_forwarding_mux;

    -- forwarding for rs2
    rs2_forwarding_mux : process (all)
    begin
        case i_hazard_control.rs2_forwarding_sel is
            when alu_out_at_mem_forward =>
                rs2_forwarded <= i_forwardings.alu_out_MEM;
            when wb_forward =>
                rs2_forwarded <= i_forwardings.writeback_out_WB;
            when npc_at_mem_forward =>
                rs2_forwarded <= r.npc;
            when others =>
                rs2_forwarded <= i_decode_to_execute.rs2_data;
        end case;
    end process rs2_forwarding_mux;

    -- mux for selecting second operand (immediate or register)
    rs2_selector_mux : process (all)
    begin
        case i_control.second_operand_type is
            when imm =>
                rs2 <= i_decode_to_execute.immediate;
            when reg =>
                rs2 <= rs2_forwarded;
        end case;
    end process rs2_selector_mux;

    -- various execution units (ALU, multiplier, ...)
    execution_unit : block
        signal alu_out     : std_logic_vector(NBIT - 1 downto 0);
        signal mult_out    : std_logic_vector(2 * NBIT - 1 downto 0);
        signal mult_enable : std_logic;
    begin
        alu : entity work.alu
            generic map(
                NBIT                => NBIT,
                ADDER_BIT_PER_BLOCK => ADDER_BIT_PER_BLOCK
            )
            port map(
                i_operand_1 => rs1,
                i_operand_2 => rs2,
                i_operation => i_control.alu_operation,
                o_result    => alu_out
            );

        mult_enable <= '1' when (i_control.execution_unit = unit_multiplier) else '0';
        multiplier : entity work.radix_4_booth_multiplier
            generic map(
                NBIT => NBIT
            )
            port map(
                a => rs1,
                b => rs2,
                p => mult_out
            );

        -- mux for selecting second operand (immediate or register)
        result_selector_mux : process (all)
        begin
            case i_control.execution_unit is
                when unit_alu =>
                    r_next.execution_unit_out <= alu_out;
                when unit_multiplier =>
                    r_next.execution_unit_out <= mult_out(NBIT - 1 downto 0);
            end case;
        end process result_selector_mux;
    end block execution_unit;

    -- pipeline registers
    regs : process (i_clk)
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
    o_execute_to_memory <= (
        npc                => r.npc,
        memory_data        => r.memory_data,
        execution_unit_out => r.execution_unit_out,
        rd_address         => r.rd_address
    );
end;
