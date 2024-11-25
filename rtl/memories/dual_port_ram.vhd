library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- dual port RAM
entity dual_port_ram is
    generic(
        ROW_BITS : integer := 16;
        WIDTH    : integer := 64
    );
    port(
        i_clk     : in  std_logic;
        i_nrst    : in  std_logic;

		-- asynchronous read port
        i_rd_en   : in  std_logic;
        i_rd_addr : in  std_logic_vector(ROW_BITS - 1 downto 0);
        o_rd_data : out std_logic_vector(WIDTH - 1 downto 0);

		-- synchronous write port
        i_wr_en   : in  std_logic;
        i_wr_addr : in  std_logic_vector(ROW_BITS - 1 downto 0);
        i_wr_data : in  std_logic_vector(WIDTH - 1 downto 0)
    );

end dual_port_ram;

architecture rtl of dual_port_ram is
    type ram_type is array (0 to 2**ROW_BITS - 1) of std_logic_vector(WIDTH - 1 downto 0);
    signal ram : ram_type;
begin
    -- synchronous write port
    synchronous_write: process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_nrst = '0' then
                ram <= (others => (others => '0'));
            elsif i_wr_en = '1' then
                ram(to_integer(unsigned(i_wr_addr))) <= i_wr_data;
            end if;
        end if;
    end process;

    -- asynchronous read port
    asynchronous_read: process(all)
    begin
        if i_rd_en = '1' then
            o_rd_data <= ram(to_integer(unsigned(i_rd_addr)));
        end if;
    end process;
end;
