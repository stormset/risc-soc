library ieee;
use ieee.std_logic_1164.all;

entity tb_dlx_soc is
    generic(
        RAM_INIT_FILE : string := "factorial.mem"
    );
end entity tb_dlx_soc;

architecture test of tb_dlx_soc is
    constant CLK_PERIOD     : time   := 2 ns;

    signal clk, nrst : std_logic;
begin
    dlx: entity work.dlx_soc_top
        generic map(
            RAM_INIT_FILE => RAM_INIT_FILE
        )
        port map(
            i_clk  => clk,
            i_nrst => nrst
        );

    clk_gen: process
    begin
        clk <= '0';
        wait for (CLK_PERIOD / 2);
        clk <= '1';
        wait for (CLK_PERIOD / 2);
    end process;

    nrst <= '0', '1' after CLK_PERIOD;
end architecture test;
