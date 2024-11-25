library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

use work.dlx_config.all;
use work.utils_package.all;
use work.tlm_interface_package.all;
use work.control_word_package.all;

entity memory is
    generic(
        NBIT : integer
    );
    port(
        i_clk                 : in  std_logic;
        i_nrst                : in  std_logic;
        i_execute_to_memory   : in  execute_to_memory_t;
        i_l1_cache_to_memory  : in  l1_cache_to_memory_t;
        i_control             : in  MEM_control_word_t;
        i_hazard_control      : in  MEM_hazard_control_t;
        o_memory_to_l1_cache  : out memory_to_l1_cache_t;
        o_memory_to_writeback : out memory_to_writeback_t;
        o_busy                : out std_logic
    );
end memory;

architecture rtl of memory is
    -- pipeline registers of memory stage
    type registers_t is record
        npc                : std_logic_vector(NBIT-1 downto 0);
        execution_unit_out : std_logic_vector(NBIT-1 downto 0);
        memory_out         : std_logic_vector(NBIT-1 downto 0);
        rd_address         : std_logic_vector(CFG_RF_ADDR_WIDTH-1 downto 0);
    end record;

    constant RESET_VALUE : registers_t := (
        npc                => (others => '0'),
        execution_unit_out => (others => '0'),
        memory_out         => (others => '0'),
        rd_address         => (others => '0')
    );

    -- internal state registers
    type state_t is (idle, wait_grant, wait_response);

    type internal_registers_t is record
        state       : state_t;
        write_request     : std_logic;
        address  : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        write_data : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        strobe : std_logic_vector(3 downto 0);
    end record;

    constant INTERNAL_RESET_VALUE : internal_registers_t := (
        state         => idle,
        write_request => '0',
        address       => (others => '0'),
        write_data    => (others => '0'),
        strobe        => (others => '0')
    );

    signal r, r_next : registers_t;
    signal internal_r, internal_r_next : internal_registers_t;
begin

    -- register NPC (for writeback for branch and link)
    r_next.npc <= i_execute_to_memory.npc;

    -- register destination register address
    r_next.rd_address <= i_execute_to_memory.rd_address;

    -- register output of execution unit
    r_next.execution_unit_out <= i_execute_to_memory.execution_unit_out;

    -- handle fetch <-> MMU transactions
    mmu_transactions_comb : process (all)
        variable write_address : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        variable write_data    : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);

        variable write_data_shifted : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        variable write_strobe       : std_logic_vector(CFG_ADDR_BITS/8 - 1 downto 0);
        variable read_data_shifted  : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    begin
        internal_r_next <= internal_r;

        -- write address and data from execution stage
        write_address := i_execute_to_memory.execution_unit_out;
        write_data    := i_execute_to_memory.memory_data;

        -- align write data and determine strobe
        case i_control.memory_data_size is
            when byte =>
                write_data_shifted := write_data(7 downto 0) & write_data(7 downto 0) & write_data(7 downto 0) & write_data(7 downto 0);

                if write_address(1 downto 0)    = "00" then
                    write_strobe := X"1";
                elsif write_address(1 downto 0) = "01" then
                    write_strobe := X"2";
                elsif write_address(1 downto 0) = "10" then
                    write_strobe := X"4";
                else
                    write_strobe := X"8";
                end if;
            when half_word =>
                write_data_shifted := write_data(15 downto 0) & write_data(15 downto 0);

                if write_address(1) = '0' then
                    write_strobe := X"3";
                else
                    write_strobe := X"C";
                end if;
            when word =>
                write_data_shifted := write_data;

                write_strobe := X"F";
        end case;

        -- align read data to the LSBs of the output
        case internal_r.address(1 downto 0) is
            when "01"   => read_data_shifted := (0 to 7 => '0') & i_l1_cache_to_memory.read_data(31 downto 8);
            when "10"   => read_data_shifted := (0 to 15 => '0') & i_l1_cache_to_memory.read_data(31 downto 16);
            when "11"   => read_data_shifted := (0 to 23 => '0') & i_l1_cache_to_memory.read_data(31 downto 24);
            when others => read_data_shifted := i_l1_cache_to_memory.read_data;
        end case;

        -- sign extend read data based on data type
        case i_control.memory_data_size is
            when byte =>
                if i_control.memory_data_type = type_unsigned then
                    r_next.memory_out <= std_logic_vector(resize(unsigned(read_data_shifted(7 downto 0)), NBIT));
                else
                    r_next.memory_out <= std_logic_vector(resize(signed(read_data_shifted(7 downto 0)), NBIT));
                end if;
            when half_word =>
                if i_control.memory_data_type = type_unsigned then
                    r_next.memory_out <= std_logic_vector(resize(unsigned(read_data_shifted(15 downto 0)), NBIT));
                else
                    r_next.memory_out <= std_logic_vector(resize(signed(read_data_shifted(15 downto 0)), NBIT));
                end if;
            when word =>
                r_next.memory_out <= read_data_shifted;
        end case;

        -- default assignments
        o_busy                                  <= '0';
        o_memory_to_l1_cache.memory_stage_ready <= '1';
        o_memory_to_l1_cache.request_valid      <= '0';
        o_memory_to_l1_cache.request_write      <= i_control.memory_write_enable;
        o_memory_to_l1_cache.address            <= write_address(CFG_ADDR_BITS - 1 downto 2) & "00";
        o_memory_to_l1_cache.write_data         <= write_data_shifted;
        o_memory_to_l1_cache.strobe             <= write_strobe;

        case internal_r.state is
            when idle =>
                o_busy <= '0';
                if i_control.memory_read_enable = '1' or i_control.memory_write_enable = '1' then
                    o_memory_to_l1_cache.request_valid <= '1';
                    o_busy <= '1';

                    internal_r_next.write_request <= i_control.memory_write_enable;
                    internal_r_next.address       <= i_execute_to_memory.execution_unit_out;
                    internal_r_next.write_data    <= write_data_shifted;
                    internal_r_next.strobe        <= write_strobe;

                    if i_l1_cache_to_memory.mmu_ready = '1' then
                        internal_r_next.state <= wait_response;
                    else
                        internal_r_next.state <= wait_grant;
                    end if;
                end if;
            when wait_grant =>
                o_memory_to_l1_cache.request_valid <= '1';
                o_busy <= '1';

                o_memory_to_l1_cache.request_write <= internal_r.write_request;
                o_memory_to_l1_cache.address       <= internal_r.address(CFG_ADDR_BITS - 1 downto 2) & "00";
                o_memory_to_l1_cache.write_data    <= internal_r.write_data;
                o_memory_to_l1_cache.strobe        <= internal_r.strobe;

                if i_l1_cache_to_memory.mmu_ready = '1' then
                    internal_r_next.state <= wait_response;
                end if;
            when wait_response =>
                o_busy <= '1';
                if i_l1_cache_to_memory.read_data_valid = '1' then
                    o_busy <= '0';

                    internal_r_next.state <= idle;
                end if;
            when others =>
        end case;
    end process;

    -- pipeline registers
    regs : process(i_clk)
    begin 
        if rising_edge(i_clk) then
            if i_nrst = '0' then
                r <= RESET_VALUE;
            elsif i_hazard_control.stall = '0' then
                r <= r_next;
            end if;
        end if; 
    end process;

    internal_regs : process(i_clk)
    begin 
        if rising_edge(i_clk) then
            if i_nrst = '0' then
                internal_r <= INTERNAL_RESET_VALUE;
            else
                internal_r <= internal_r_next;
            end if;
        end if; 
    end process;

    -- output to writeback stage
    o_memory_to_writeback <= (
        npc                => r.npc,
        execution_unit_out => r.execution_unit_out,
        memory_out         => r.memory_out,
        rd_address         => r.rd_address
    );
end;
