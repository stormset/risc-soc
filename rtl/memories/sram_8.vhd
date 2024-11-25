library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

use work.dlx_config.all;
use work.utils_package.all;
use work.types_amba4.all;

-- 8 byte wide 2^ADDRESS_WIDTH deep SRAM array
-- GENERICS:
--     ADDRESS_WIDTH    : determines the depth of the SRAM array
--     INIT_FILE        : file contents to be loaded into the SRAM for simulation
--     INIT_FILE_OFFSET : byte offset in the line of the file to be loaded into the SRAM
entity sram_8 is
    generic (
        ADDRESS_WIDTH    : integer;
        INIT_FILE        : string;
        INIT_FILE_OFFSET : integer
    );
    port (
        i_clk     : in std_logic;
        i_wr_en   : in std_logic;
        i_addr    : in std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
        i_wr_data : in std_logic_vector(7 downto 0);
        o_rd_data : out std_logic_vector(7 downto 0)
    );
end;

architecture rtl of sram_8 is
    type ram_type is array (0 to 2 ** ADDRESS_WIDTH - 1) of std_logic_vector(7 downto 0);

    impure function init_ram(file_name : in string) return ram_type is
        file ram_file     : text open read_mode is file_name;
        variable ram_line : line;
        variable temp_slv : std_logic_vector(CFG_BUS0_DATA_BITS - 1 downto 0);
        variable temp_mem : ram_type;
    begin
        for i in 0 to (2 ** ADDRESS_WIDTH - 1) loop
            readline(ram_file, ram_line);
            hread(ram_line, temp_slv);

            temp_mem(i) := temp_slv((INIT_FILE_OFFSET + 1) * 8 - 1 downto 8 * INIT_FILE_OFFSET);
        end loop;

        return temp_mem;
    end function;


    signal ram  : ram_type := init_ram(INIT_FILE);
    signal radr : std_logic_vector(ADDRESS_WIDTH - 1 downto 0);
begin

    reg : process (i_clk, i_addr, i_wr_data) begin
        if rising_edge(i_clk) then
            if i_wr_en = '1' then
                ram(conv_integer(i_addr)) <= i_wr_data;
            end if;
            radr <= i_addr;
        end if;
    end process;

    o_rd_data <= ram(conv_integer(radr));
end;
