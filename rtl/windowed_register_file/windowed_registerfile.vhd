library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

-- windowed register file
-- generics:
--     DATA_WIDTH: width of individual registers in the rf
--     M: number of global registers
--     N: number of in|out / local registers
--     F: number of windows
-- remarks of the implementation:
--     - the swp register is used as a pointer to the register that we are currently spilling/filling
--     - the cwp register is updated in case call/ret is asserted to it's new value
--       in case spilling/filling it is also updated to it's new value immediately, but during these
--       operations busy is asserted, thus this will be used while integrating it into the data path of the dlx
--       to not to use the rf until busy is high
entity windowed_register_file is
    generic(
        DATA_WIDTH: integer := 64;  -- width of individual registers in the rf
        M:          integer := 16;  -- number of global registers
        N:          integer := 8;   -- number of in|out / local registers
        F:          integer := 8    -- number of windows
    );
    port (
        clk: in  std_logic;
        reset: in  std_logic;

        -- global enable (active high)
        enable: in  std_logic;
        -- write|read_1|read_2 port enable (active high)
        wr, rd1, rd2: in  std_logic;

        -- write|read_1|read_2 port address (width: calculated so global, in, out, local are addressable)
        add_wr, add_rd1, add_rd2: in  std_logic_vector(integer(ceil(log2(real(M + 3*n))))-1 downto 0);

        -- write port data in
        datain:    in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- subroutine call signal (active high)
        call:      in  std_logic;
        -- subroutine return signal (active high)
        ret:       in  std_logic;
        -- mmu finished writing/reading (fill/spill)
        mmu_done:  in  std_logic;
        -- fill request to mmu (active high)
        fill:      out  std_logic;
        -- spill request to mmu (active high)
        spill:     out  std_logic;
        -- busy (active high)
        busy:      out  std_logic;

        -- data in from mmu (used when filling)
        mmu_in:    in std_logic_vector(DATA_WIDTH-1 downto 0);

        -- data out from mmu (used when spilling)  
        -- the data changes on rising edge, so mmu should sample it on the falling
        mmu_out:   out std_logic_vector(DATA_WIDTH-1 downto 0);

        -- read_1|read_2 port data out
        out1, out2: out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end windowed_register_file;

architecture rtl of windowed_register_file is
    --- physical registers
    -- number of registers in physical register file = globals + nr_windows*(nr_in|out + nr_local) = m + f*(2*n)
    subtype reg_addr is natural range 0 to  M + F*(2*N)-1;
    type reg_array is array(reg_addr) of std_logic_vector(DATA_WIDTH-1 downto 0); 
    signal registers : reg_array;    
    
    --- addresses to convert from vitual to physical register addresses
    signal phy_add_wr, phy_add_rd1, phy_add_rd2: std_logic_vector(integer(ceil(log2(real(M + F*(2*N)))))-1 downto 0);

    --- signals for controlling the windowing
    type state_type is (state_idle, state_spill, state_fill);
    signal curr_state, next_state: state_type;

    -- current window pointer (points to the first register of the current window)
    -- save window pointer (points to the start of the next window, that needs to be saved (end of the saved window))
    signal cwp_reg, next_cwp_reg, swp_reg, next_swp_reg: std_logic_vector(integer(ceil(log2(real(F*(2*N)))))-1 downto 0);

    -- keeps track of the number of the windows that can be saved/restored without spilling/filling
    -- used as described in the oracle sparc documentation (https://www.oracle.com/technetwork/server-storage/sun-sparc-enterprise/documentation/sparc-architecture-2015-2868130.pdf p. 106)
    signal cansave, next_cansave, canrestore, next_canrestore: std_logic_vector(integer(ceil(log2(real(F))))-1 downto 0);

    -- used to keep track of the last register to spill (swp_reg will go until this value while spilling)
    signal spill_limit, next_spill_limit: std_logic_vector(integer(ceil(log2(real(F*(2*N)))))-1 downto 0);

    -- extended cwp, swp signals (to match the width of the physical address length)
    signal cwp_extended, swp_extended: std_logic_vector(phy_add_wr'range);
begin
    -- extend control unit signals to match the width of the physical address length
    cwp_extended <= std_logic_vector(resize(unsigned(cwp_reg), cwp_extended'length));
    swp_extended <= std_logic_vector(resize(unsigned(swp_reg), swp_extended'length));

    -- map virtual addresses to physical addresses in register file
    addr_translation: process(add_wr, add_rd1, add_rd2, cwp_reg, cwp_extended)
    begin
        if to_integer(unsigned(add_wr)) >= (3*N) then
            -- global registers
            phy_add_wr <= std_logic_vector(unsigned(add_wr) + to_unsigned(F*(2*N) - 3*N, phy_add_wr'length));
        elsif to_integer(unsigned(cwp_reg)) = ((F-1)*2*N) and to_integer(unsigned(add_wr)) > (2*N - 1) then
            -- wrap around in case last window and accessing out registers
            phy_add_wr <= std_logic_vector(unsigned(add_wr) - to_unsigned(2*n, phy_add_wr'length));
        else
            -- local/in/out registers
            phy_add_wr <= std_logic_vector(unsigned(add_wr) + unsigned(cwp_extended));
        end if;

        if to_integer(unsigned(add_rd1)) >= (3*N) then
            -- global registers
            phy_add_rd1 <= std_logic_vector(unsigned(add_rd1) + to_unsigned(F*(2*N) - 3*N, phy_add_rd1'length));
        elsif to_integer(unsigned(cwp_reg)) = ((F-1)*2*N) and to_integer(unsigned(add_rd1)) > (2*N - 1) then
            -- wrap around in case last window and accessing out registers
            phy_add_rd1 <= std_logic_vector(unsigned(add_rd1) - to_unsigned(2*N, phy_add_rd1'length));
        else
            -- local/in/out registers
            phy_add_rd1 <= std_logic_vector(unsigned(add_rd1) + unsigned(cwp_extended));
        end if;

        if to_integer(unsigned(add_rd2)) >= (3*N) then
            -- global registers
            phy_add_rd2 <= std_logic_vector(unsigned(add_rd2) + to_unsigned(F*(2*N) - 3*N, phy_add_rd2'length));
        elsif to_integer(unsigned(cwp_reg)) = ((F-1)*2*N) and to_integer(unsigned(add_rd2)) > (2*N - 1) then
            -- wrap around in case last window and accessing out registers
            phy_add_rd2 <= std_logic_vector(unsigned(add_rd2) - to_unsigned(2*N, phy_add_rd2'length));
        else
            -- local/in/out registers
            phy_add_rd2 <= std_logic_vector(unsigned(add_rd2) + unsigned(cwp_extended));
        end if;
    end process;

    -- physical register file
    reg_proc: process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                registers <= (others => (others => '0'));
            else
                if enable = '1' then
                    -- read port 1
                    if rd1 = '1' then
                        out1 <= registers(to_integer(unsigned(phy_add_rd1)));
                    else
                        out1 <= (others => '0');
                    end if;

                    -- read port 2
                    if rd2 = '1' then
                        out2 <= registers(to_integer(unsigned(phy_add_rd2)));
                    else
                        out2 <= (others => '0');
                    end if;

                    -- write port
                    if wr = '1' then
                        registers(to_integer(unsigned(phy_add_wr))) <= datain;
                    end if;

                    -- write port for fill operation
                    if curr_state = state_fill and mmu_done = '1' then
                        registers(to_integer(unsigned(swp_reg))) <= mmu_in;
                    end if;
                else
                    out1 <= (others => '0');
                    out2 <= (others => '0');
                end if;
            end if;
        end if;
    end process reg_proc;


    -- windowing control unit register process
    ctrl_reg_proc: process (clk)
    begin
      if rising_edge(clk) then
        if reset = '1' then
            curr_state <= state_idle;
            cwp_reg <= (others => '0');
            swp_reg <= (others => '0');

            -- there is nothing to restore initially
            canrestore <= (others => '0');
            -- initially we can save F-1 without spilling (the fth out overlaps with the 0th in)
            -- note: it is set to F-2, because the decrement in case of a call only happens in the next clock cycle,
            --       and the condition (cansave == 0) check happens in the same cycle
            cansave <= std_logic_vector(to_unsigned(F-2, cansave'length));

            spill_limit <= (others => '0');
        else
            curr_state <= next_state;
            cwp_reg <= next_cwp_reg;
            swp_reg <= next_swp_reg;
            cansave <= next_cansave;
            canrestore <= next_canrestore;
            spill_limit <= next_spill_limit;
        end if;
      end if;
    end process;

    -- windowing control unit combinational process
    ctrl_comb_proc: process(curr_state, enable, call, ret, mmu_done, cwp_reg, swp_reg, cansave, canrestore, spill_limit)
    begin
        -- default assignments
        fill <= '0';
        spill <= '0';
        busy <= '0';
        mmu_out <= (others => '0');
        next_state <= state_idle;
        next_cwp_reg <= cwp_reg;
        next_swp_reg <= swp_reg;
        next_canrestore <= canrestore;
        next_cansave <= cansave;
        next_spill_limit <= spill_limit;

        case curr_state is
            when state_idle =>
                if call = '1' then
                    if unsigned(cansave) = 0 then
                        -- no place for new save, need to spill
                        -- cansave, canrestore stays unchanged (as described in the sparc doc.)
                        next_spill_limit <= std_logic_vector(unsigned(swp_reg) + (2*N - 1)); -- spill until spill_limit is reached
                        next_state <= state_spill;
                    else
                        -- decrease count of windows that can be saved, increase count of windows that can be restored
                        next_cansave <= std_logic_vector(unsigned(cansave) - 1);
                        next_canrestore <= std_logic_vector(unsigned(canrestore) + 1);

                        -- no need to spill/fill
                        next_state <= state_idle;
                    end if;
                    
                    -- move to next window
                    next_cwp_reg <= std_logic_vector(unsigned(cwp_reg) + 2*N);
                    
                    -- check if need to wrap around circle
                    -- note: this is only needed in case F*2*N is not a power of 2 (in case we choose F and N that way this can be removed)
                    if to_integer(unsigned(cwp_reg)) > (F*2*N - 1) then
                        next_cwp_reg <= (others => '0');
                    end if;
                elsif ret = '1' then
                    if unsigned(canrestore) = 0 then
                        -- need to restore (fill) from memory
                        -- cansave, canrestore stays unchanged (as described in the sparc doc.)
                        next_swp_reg <= std_logic_vector(unsigned(swp_reg) - 1); -- subtract 1 from swp as it points to the first unsaved register
                        next_state <= state_fill;
                    else
                        -- increase count of windows that can be saved, decrease count of windows that can be restored
                        next_cansave <= std_logic_vector(unsigned(cansave) + 1);
                        next_canrestore <= std_logic_vector(unsigned(canrestore) - 1);

                        -- no need to spill/fill
                        next_state <= state_idle;
                    end if;

                    -- move to previous window
                    next_cwp_reg <= std_logic_vector(unsigned(cwp_reg) - 2*N);

                    -- check if need to wrap around circle
                    -- this is only needed in case F*2*N is not a power of 2 (in case we choose F and N that way this can be removed)
                    if to_integer(unsigned(cwp_reg)) > (F*2*N - 1) then
                        next_cwp_reg <= std_logic_vector(to_unsigned(F*2*N - 1, cwp_reg'length));
                    end if;
                end if;
            when state_spill =>
                next_state <= state_spill;
                next_swp_reg <= swp_reg;
                mmu_out <= registers(to_integer(unsigned(swp_reg)));
                busy <= '1';
                spill <= '1';

                if mmu_done = '1' then
                    -- if mmu is done writing

                    -- go to next register to save
                    next_swp_reg <= std_logic_vector(unsigned(swp_reg) + 1);

                    if swp_reg = spill_limit then
                        -- if finished spilling, go to state_idle
                        next_state <= state_idle;
    
                        -- this is only needed in case F*2*N is not a power of 2 (in case we choose F and N that way this can be removed)
                        if to_integer(unsigned(swp_reg)) > (F*2*N - 1) then
                            next_swp_reg <= (others => '0');
                        end if;
                    end if;
                end if;

            when state_fill =>
                next_state <= state_fill;
                busy <= '1';
                fill <= '1';

                if mmu_done = '1' then
                    -- if mmu is done reading

                    if swp_reg = cwp_reg then
                        -- when filling, we go until the cwp => go to state_idle
                        next_state <= state_idle;
                    else
                        -- proceed to the next register to spill if cwp is not reached
                        next_swp_reg <= std_logic_vector(unsigned(swp_reg) - 1);
                    end if;
                end if;
            when others =>
                next_state <= state_idle;
        end case;
    end process;

end rtl;
