library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tbregisterfile is
end tbregisterfile;

architecture tb of tbregisterfile is
    constant clk_period   : time := 1 ns;

    constant DATA_WIDTH   : integer := 32;
    constant num_io_local : integer := 4;
    constant num_global   : integer := 4;
    constant num_window   : integer := 8;

    component windowed_register_file
        generic(
            DATA_WIDTH: integer := 64;
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
            add_wr, add_rd1, add_rd2: in  std_logic_vector(integer(ceil(log2(real(m + 3*n))))-1 downto 0);

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
            mmu_out:   out std_logic_vector(DATA_WIDTH-1 downto 0);

            -- read_1|read_2 port data out
            out1, out2: out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

    signal clk: std_logic := '0';
    signal reset, enable: std_logic := '0';

    signal wr, rd1, rd2, call, ret, mmu_done, fill, spill, busy: std_logic;

    signal add_wr, add_rd1, add_rd2: std_logic_vector(integer(ceil(log2(real(num_global + 3*num_io_local))))-1 downto 0);

    signal datain, mmu_in, mmu_out, out1, out2: std_logic_vector(DATA_WIDTH-1 downto 0);

    -- stack, used to imitate external memory
    subtype stack_addr is natural range 0 to  3*(num_window*(2*num_io_local)-1);
    type stack_array is array(stack_addr) of std_logic_vector(DATA_WIDTH-1 downto 0); 
    signal stack : stack_array := (others => (others => '0'));
begin 

    wrg: windowed_register_file
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            M          => num_global,
            N          => num_io_local,
            F          => num_window
        )
        port map (clk,reset,enable,wr,rd1,rd2,add_wr,add_rd1,add_rd2,datain,call,ret,mmu_done,fill,spill,busy,mmu_in,mmu_out,out1,out2);

    pstimuli: process
        -- reads(rw == 0)/writes(rw == 1) the current window and does a call(callret == 0) or ret(callret == 1), and repeats this times time
        -- in case reading: it reads in, then local, then out registers (on read port 1, rd1)
        -- in case writing: it writes local and out registers with an incrementing value and a starting value of start_val
        procedure do_call_ret_read_write(
            times: integer;
            callret: integer;        -- call == 0 or ret == 1
            rw: integer;             -- read == 0 or write == 1
            start_val: integer := 1
        ) is 
            variable ctr: integer := start_val;
        begin
            for i in 0 to times-1 loop
                -- if busy, wait until not busy
                if busy /= '0' then
                    wait until busy='0';
                end if;
                
                
                if rw = 1 then
                    -- write local and out registers of current window
                    -- skip in registers (first num_io_local registers)
                    for j in num_io_local to num_io_local + 2*num_io_local-1 loop
                        wr <= '1';
                        add_wr <= std_logic_vector(to_unsigned(j, add_wr'length));
                        datain <= std_logic_vector(to_unsigned(ctr, datain'length));
                        ctr := ctr + 1;
                        wait for clk_period;
                        wr <= '0';
                        add_wr <= (others => '0');
                        datain <= (others => '0');
                    end loop;
                elsif rw = 0 then
                    -- read in, local and out registers of current window
                    for j in 0 to 3*num_io_local-1 loop
                        rd1 <= '1';
                        add_rd1 <= std_logic_vector(to_unsigned(j, add_rd1'length));
                        wait for clk_period;
                        rd1 <= '0';
                        add_rd1 <= (others => '0');
                    end loop;
                end if;
    
                -- go to next/previous window by doing call/ret
                if callret = 0 then
                    call <= '1';
                else
                    ret <= '1';
                end if;
                wait for clk_period;
                call <= '0';
                ret <= '0';
                wait for clk_period;
                
                -- uncomment to simulate that mmu takes 1 cc. to write/read
                -- if busy = '1' then
                --     for k in 0 to 2*num_io_local-1 loop
                --         mmu_done <= '0';
                --         wait for clk_period;
                --         mmu_done <= '1';
                --         wait for clk_period;
                --     end loop;
                -- end if;
            end loop;

            -- if busy, wait until not busy
            if busy /= '0' then
                wait until busy='0';
            end if;
        end procedure;
    begin
        -- init all input
        reset   <= '1';
        enable  <= '0';
        wr      <= '0';
        rd1     <= '0';
        rd2     <= '0';
        call    <= '0';
        ret     <= '0';
        mmu_done<= '0';
        --mmu_in  <= (others => '0');
        datain  <= (others => '0');
        add_wr  <= (others => '0'); 
        add_rd1 <= (others => '0'); 
        add_rd2 <= (others => '0');

        wait for 2*clk_period;
        
        reset   <= '0';
        enable   <= '1';
        mmu_done <= '1';

        wait for clk_period;

        -- write into global registers
        for i in 3*num_io_local to (3*num_io_local + num_global - 1) loop
            wr <= '1';
            add_wr <= std_logic_vector(to_unsigned(i, add_wr'length));
            datain <= std_logic_vector(to_unsigned(i, datain'length));
            wait for clk_period;
            wr <= '0';
            add_wr <= (others => '0');
            datain <= (others => '0');
        end loop;

        -- read global registers (on read port 1)
        for i in 3*num_io_local to (3*num_io_local + num_global - 1) loop
            rd1 <= '1';
            add_rd1 <= std_logic_vector(to_unsigned(i, add_rd1'length));
            wait for clk_period;
            rd1 <= '0';
            add_rd1 <= (others => '0');
        end loop;

        -- go in "circle" 2 times: (2*num_window) call, write with incrementing values starting from 1
        do_call_ret_read_write(2*num_window, 0, 1, 1);

        -- go back in "circle" 2 times: (2*num_window) call, cwp should return to 0, read current window before each ret
        do_call_ret_read_write(2*num_window, 1, 0);

        -- go in "circle" 1 time (cwp should be at first window == 0), write with incrementing values starting from 100
        do_call_ret_read_write(num_window, 0, 1, 100);
        -- go back 1 time: ret, read current window
        do_call_ret_read_write(1, 1, 0);
        -- do 2 calls (cwp should be at the second window == 2*num_io_local, the first call shouldn't spill, the second call should spill the 2nd window), write with incrementing values starting from 200
        do_call_ret_read_write(2, 0, 1, 200);

        -- go back (ret) num_window + 1 times, cwp should return to 0, read current window before each ret
        do_call_ret_read_write(num_window + 1, 1, 0);
        -- disable rf
        enable   <= '0';
        wait;
    end process;

    -- imitates external memory (used as stack)
    -- the spilled out values will be filled back from here during test
    stack_proc: process(clk)
        variable stack_ptr: integer := 0;
    begin
        -- data is changing on falling edge, as the rf samples/outputs on rising edge
        if falling_edge(clk) then
            if spill = '1' then
                stack(stack_ptr) <= mmu_out;
                stack_ptr := stack_ptr + 1;
            end if;
            if fill = '1' then
                stack_ptr := stack_ptr - 1;
                if stack_ptr >= 0 then
                    mmu_in <= stack(stack_ptr);
                end if;
            else
                mmu_in <= (others => '0');
            end if;
        end if;
    end process;

    pclock : process(clk)
    begin
        clk <= not(clk) after clk_period/2;    
    end process;

end tb;
