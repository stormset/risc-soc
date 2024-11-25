library ieee;

use ieee.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.utils_package.all;
use work.tlm_interface_package.all;
use work.control_word_package.all;

-- set associative branch target buffer
-- generics: 
--     - NBIT: address width
--     - NUM_SETS: number of sets in the cache
--     - NUM_WAYS: number of cache lines in a set
entity branch_target_buffer is
    generic(
        NBIT     : integer := 32;
        NUM_SETS : integer := 8;
        NUM_WAYS : integer := 4
    );
    port(        
        i_clk                    : in std_logic;                
        i_nrst                   : in std_logic;                

        -- inputs from fetch stage
        i_stall_IF               : in std_logic;
        i_npc_IF                 : in std_logic_vector(NBIT-1 downto 0);

        -- inputs from decode stage
        i_stall_ID               : in std_logic;
        i_npc_ID                 : in std_logic_vector(NBIT-1 downto 0);
        i_branch_condition_ID    : in branch_condition_t;
        i_calculated_address_ID  : in std_logic_vector(NBIT-1 downto 0);
        i_branch_taken_ID        : in std_logic;
        i_previous_prediction_ID : in std_logic_vector(NBIT-1 downto 0);

        -- predicted PC and misprediction outputs
        o_predicted_pc           : out std_logic_vector(NBIT-1 downto 0);
        o_misprediction          : out std_logic
    );
end entity branch_target_buffer;

architecture rtl of branch_target_buffer is
    -- ignore LSBs of addresses that are always 0 because of alignment requirements
    constant IGNORE_ADDR_BITS : integer := clog2(NBIT/8);
    -- tag field size is the remaining bits after the bits for the SET
    constant TAG_FIELD_SIZE: integer := NBIT - clog2(NUM_SETS) - IGNORE_ADDR_BITS;
    -- width of a cache line: valid bit + tag + target address
    constant ROW_WIDTH: integer := 1 + TAG_FIELD_SIZE + (NBIT - IGNORE_ADDR_BITS);
    
    -- ranges of SET and TAG fields in the program counter
    subtype SET_range is integer range clog2(NUM_SETS) + IGNORE_ADDR_BITS - 1 downto IGNORE_ADDR_BITS;
    subtype TAG_range is integer range SET_range'high + TAG_FIELD_SIZE downto SET_range'high + 1;

    subtype way_t is integer range 0 to NUM_WAYS-1;
    subtype set_t is integer range 0 to NUM_SETS-1;

    -- read output of BTB cache RAMs
    type cache_ram_out_t is array(way_t) of std_logic_vector(ROW_WIDTH-1 downto 0);

    -- type for storing pointers for each SET to the next way to replace
    type replace_way_t is array(set_t) of way_t;

    -- pipeline register type for internal state
    type pipeline_reg_t is record
        hit : std_logic;
        hit_way : way_t;
    end record;

    -- signals for outputs
    signal is_hit  : std_logic;
    signal hit_way : way_t;
    signal mispredict : std_logic;
    signal prediction : std_logic_vector(NBIT - 1 downto 0);
    signal cache_wr_data : std_logic_vector(ROW_WIDTH - 1 downto 0);
    signal cache_out : cache_ram_out_t;

    -- stores pointer for each SET to the next way to replace
    signal replace_way_counters : replace_way_t;

    -- pipeline registers for internal state
    signal pipeline_IF, pipeline_ID : pipeline_reg_t;
begin
    -- here the cache is implemented with a RAM block (1 asynchronous read + 1 synchronous write port) for each way
    -- for an ASIC this would be done with content-addressable memories and RAM compilers (e.g. https://github.com/VLSIDA/OpenCache)
    cache_rams: for i in 0 to NUM_WAYS-1 generate
        signal do_read  : std_logic;
        signal do_write : std_logic;
        signal rd_addr  : std_logic_vector(clog2(NUM_SETS)-1 downto 0);
        signal wr_addr  : std_logic_vector(clog2(NUM_SETS)-1 downto 0);
    begin
        -- cache RAMs (one per way)
        way: entity work.dual_port_ram
            generic map (
                ROW_BITS => clog2(NUM_SETS),
                WIDTH => ROW_WIDTH
            )
            port map (
                i_clk     => i_clk,
                i_nrst    => i_nrst,

                i_rd_en   => do_read,
                i_rd_addr => rd_addr,
                o_rd_data => cache_out(i),

                i_wr_en   => do_write,
                i_wr_addr => wr_addr,
                i_wr_data => cache_wr_data
            );

        -- read/write enable and address for way i
        process(all)
        begin
            -- select read SET based on address in IF stage
            rd_addr <= i_npc_IF(SET_range);
            -- select write SET based on address in EXE stage
            wr_addr <= i_npc_ID(SET_range);

            -- read enable when IF stage is enabled
            do_read <= not i_stall_IF;

            -- write of a way is enabled in 3 cases:
            --     the way was hit but we mispredicted (we have to invalidate the line if the branch is NOT taken otherwise update target address)
            --     there was no hit but the branch was taken, thus need to be stored
            do_write <= '0';
            if i_stall_ID = '0' then
                if mispredict = '1' and pipeline_ID.hit = '1' and i = pipeline_ID.hit_way then
                    do_write <= '1';
                elsif i_branch_taken_ID = '1' and pipeline_ID.hit = '0' and
                i = replace_way_counters(to_integer(unsigned(i_npc_ID(SET_range)))) then
                    do_write <= '1';
                end if;
            end if;
        end process;
    end generate;

    -- determine data to store in the BTB RAM
    cache_write_data : process(all)
    begin
        if i_branch_taken_ID = '0' then
            -- invalidate line, branch was not taken
            cache_wr_data <= (others => '0');
        else
            -- taken branch, new line content: valid bit + TAG + target_address
            cache_wr_data <= '1' & i_npc_ID(TAG_range) & i_calculated_address_ID(i_calculated_address_ID'high downto IGNORE_ADDR_BITS);
        end if;
    end process;

    -- counters for each set to implement the round-robin replacement policy
    replace_way_counter: for i in 0 to NUM_SETS-1 generate
    begin
        process(i_clk)
            variable counter : std_logic_vector(clog2(NUM_WAYS) - 1 downto 0);
        begin
            if rising_edge(i_clk) then
                if i_nrst = '0' then
                    replace_way_counters(i) <= 0;
                elsif i_stall_ID = '0' and i_branch_taken_ID = '1' and pipeline_ID.hit = '0' and i = to_integer(unsigned(i_npc_ID(SET_range))) then
                    -- branch was taken but there was no hit =>
                    -- new record will be added to the BTB, increase counter
                    counter := std_logic_vector(to_unsigned(replace_way_counters(i), counter'length));
                    replace_way_counters(i) <= to_integer(unsigned(counter + 1));
                end if;
            end if;
        end process;
    end generate;

    -- detect hit way if any
    cache_hit_detection : process(all)
    begin
        is_hit  <= '0';
        hit_way <= 0;
        for i in way_t loop
            -- line is valid and the TAG matches the lookup TAG
            if cache_out(i)(ROW_WIDTH-1) = '1' and cache_out(i)(ROW_WIDTH-1-1 downto ROW_WIDTH-TAG_FIELD_SIZE-1) = i_npc_IF(TAG_range) then
                is_hit  <= '1';
                hit_way <= i;
            end if;
        end loop;
    end process;

    -- fetch stage pipeline register for internal state information
    pipeline_fetch_stage : process(i_clk)
    begin
        if rising_edge(i_clk) then
            pipeline_IF <= pipeline_IF;
            
            if i_nrst = '0' then
                pipeline_IF <= (
                    hit => '0',
                    hit_way => 0
                );
            elsif i_stall_IF = '0' then
                pipeline_IF <= (
                    hit => is_hit,
                    hit_way => hit_way
                );
            end if;
        end if;
    end process;

    -- decode stage pipeline register for internal state information
    pipeline_decode_stage : process(i_clk)
    begin
        if rising_edge(i_clk) then
            pipeline_ID <= pipeline_ID;

            if i_nrst = '0' then
                pipeline_ID <= (
                    hit => '0',
                    hit_way => 0
                );
            elsif i_stall_ID = '0' then
                pipeline_ID <= pipeline_IF;
            end if;
        end if;
    end process;

    -- assert mispredict signal in case the instruction is a branch and the prediction is wrong
    mispredict <= '1' when (i_branch_condition_ID /= never) and (i_previous_prediction_ID /= i_calculated_address_ID) else
                  '0';

    -- predicted address
    prediction <= i_calculated_address_ID when mispredict = '1' else
                  cache_out(hit_way)(NBIT - IGNORE_ADDR_BITS - 1 downto 0) & "00" when is_hit = '1' else
                  i_npc_IF;

    -- output assignments
    o_predicted_pc <= prediction;
    o_misprediction <= mispredict;

end architecture rtl;
