library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tlm_interface_package.all;
use work.control_word_package.all;

entity fetch is
    generic(
        NBIT      : integer;
        CFG_BTB_NSETS : integer;
        CFG_BTB_NWAYS : integer
    );
    port(
        i_clk               : in  std_logic;
        i_nrst              : in  std_logic;
        i_pc                : in  std_logic_vector(NBIT-1 downto 0);
        i_decode_to_fetch   : in  decode_to_fetch_t;
        i_l1_cache_to_fetch : in  l1_cache_to_fetch_t;
        i_hazard_control    : in  IF_hazard_control_t;
        o_fetch_to_l1_cache : out fetch_to_l1_cache_t;
        o_fetch_to_decode   : out fetch_to_decode_t;
        o_bpu_predicted_pc  : out std_logic_vector(NBIT-1 downto 0);
        o_bpu_misprediction : out std_logic;
        o_fetch_busy        : out std_logic
    );
end fetch;

architecture rtl of fetch is
    -- pipeline registers of fetch stage
    type registers_t is record
        wait_resp   : std_logic;
        npc         : std_logic_vector(NBIT-1 downto 0);
        instruction : std_logic_vector(NBIT-1 downto 0);
        predicted_pc : std_logic_vector(NBIT-1 downto 0);
        fetch_pc : std_logic_vector(NBIT-1 downto 0);
    end record;

    constant RESET_VALUE : registers_t := (
        wait_resp    => '0',
        npc          => (others => '0'),
        instruction  => (others => '0'),
        predicted_pc => (others => '0'),
        fetch_pc     => (others => '0')
    );

    signal r, r_next : registers_t;

    signal bpu_predicted_pc : std_logic_vector(NBIT-1 downto 0);
begin
    -- response from MMU
    r_next.instruction <= i_l1_cache_to_fetch.read_data;

    -- register predicted branch target (to check if we mispredicted)
    r_next.predicted_pc <= bpu_predicted_pc;

    -- busy output
    o_fetch_busy <= not (r.wait_resp and i_l1_cache_to_fetch.read_data_valid);

    -- RCA for calculating next PC
    next_pc_adder: entity work.RCA
        generic map(
            N => NBIT
        )
        port map(
            A  => i_pc,
            B  => std_logic_vector(to_unsigned(NBIT / 8, NBIT)),
            S  => r_next.npc,
            Ci => '0',
            Co => open
        );
    
    -- branch target buffer
    branch_target_buffer: entity work.branch_target_buffer
        generic map(
            NBIT     => NBIT,
            NUM_SETS => CFG_BTB_NSETS,
            NUM_WAYS => CFG_BTB_NWAYS
        )
        port map(
            i_clk                    => i_clk,
            i_nrst                   => i_nrst,

            i_stall_IF               => i_hazard_control.stall,
            i_npc_IF                 => r_next.npc,

            i_stall_ID               => i_decode_to_fetch.stall,
            i_npc_ID                 => i_decode_to_fetch.npc,
            i_branch_condition_ID    => i_decode_to_fetch.branch_condition,
            i_calculated_address_ID  => i_decode_to_fetch.calculated_branch_address,
            i_branch_taken_ID        => i_decode_to_fetch.branch_taken,
            i_previous_prediction_ID => i_decode_to_fetch.previous_prediction,

            o_predicted_pc           => bpu_predicted_pc,
            o_misprediction          => o_bpu_misprediction
        );

    -- handle fetch <-> MMU transactions
    mmu_transactions_comb : process (all)
        variable fetch_ready  : std_logic;
        variable read_request : std_logic;
    begin
        fetch_ready  := (r.wait_resp) and not i_hazard_control.stall_PC;
        read_request := not i_hazard_control.stall and not (r.wait_resp and not i_l1_cache_to_fetch.read_data_valid);

        r_next.wait_resp <= r.wait_resp;

        r_next.fetch_pc <= i_pc;
        if r.wait_resp = '1' and i_l1_cache_to_fetch.read_data_valid = '1' then
            r_next.fetch_pc <= bpu_predicted_pc;
        end if;

        if i_l1_cache_to_fetch.mmu_ready = '1' and read_request = '1' then
            r_next.wait_resp <= '1';
        elsif i_l1_cache_to_fetch.read_data_valid = '1' and i_hazard_control.stall = '0' then
            r_next.wait_resp <= '0';
        end if;

        o_fetch_to_l1_cache <= (
            fetch_ready  => fetch_ready,
            read_request => read_request,
            read_addr    => r_next.fetch_pc
        );
    end process;



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

    -- output predicted PC
    o_bpu_predicted_pc <= bpu_predicted_pc;

    -- output to decode stage
    o_fetch_to_decode <= (
        npc          => r.npc,
        instruction  => r.instruction,
        predicted_pc => r.predicted_pc
    );
end;
