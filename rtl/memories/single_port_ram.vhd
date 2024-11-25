library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_package.all;

-- single port ram
entity single_port_ram is generic (
    ADDRESS_WIDTH : integer := 12;
    DATA_WIDTH    : integer := 64
);
port (
    i_clk     : in  std_logic;
    i_wr_en   : in  std_logic;
    i_addr    : in  std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
    i_wr_data : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    o_rd_data : out std_logic_vector(DATA_WIDTH - 1 downto 0)
);
end;

architecture rtl of single_port_ram is
    type ram_type is array (0 to 2 ** ADDRESS_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal ram : ram_type;
    signal radr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
begin
    reg : process (i_clk) begin
        if rising_edge(i_clk) then
            radr <= i_addr;
            if i_wr_en = '1' then
                ram(to_integer(unsigned(i_addr))) <= i_wr_data;
            end if;
        end if;
    end process;

    o_rd_data <= ram(to_integer(unsigned(radr)));
end;
