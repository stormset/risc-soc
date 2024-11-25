library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- register file
-- generics: 
--     - DATA_WIDTH: width of a single register
--     - ADDR_WIDTH: width of the address lines (the number of registers in the register file will be 2**ADDR_WIDTH)
entity register_file is
    generic(
        DATA_WIDTH : integer := 32;
        ADDR_WIDTH : integer := 5
    );
    port(
        i_clk  : in  std_logic;
        i_nrst : in  std_logic;

        -- write enable (active high)
        i_wr_en : in  std_logic;

        -- write|read_1|read_2 port address
        i_addr_wr, i_addr_rd1, i_addr_rd2: in std_logic_vector(ADDR_WIDTH-1 downto 0);

        -- write port data in
        i_data_wr: in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- read_1|read_2 port data out
        o_data1, o_data2: out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end register_file;

architecture rtl of register_file is
    subtype reg_addr_t is natural range 0 to (2**ADDR_WIDTH)-1;
    type    reg_bank_t is array(reg_addr_t) of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal  registers : reg_bank_t;     
begin
    -- r0 == 0
    registers(0) <= (others => '0');

    -- asynchronous read port 1
    o_data1 <= registers(to_integer(unsigned(i_addr_rd1)));

    -- asynchronous read port 2
    o_data2 <= registers(to_integer(unsigned(i_addr_rd2)));

    reg_bank: for i in 1 to 2**ADDR_WIDTH-1 generate
        process(i_clk)
        begin
            if rising_edge(i_clk) then
                if i_nrst = '0' then
                    registers(i) <= (others => '0');
                else
                    -- write port
                    if i_wr_en = '1' and i = to_integer(unsigned(i_addr_wr)) then
                        registers(i) <= i_data_wr;
                    end if;
                end if;
            end if;
        end process;
    end generate;
end rtl;
