library ieee; 
use ieee.std_logic_1164.all; 
use ieee.std_logic_unsigned.all;

entity cs_block is
    generic(
        N: integer
    );
    port(
        a, b: in  std_logic_vector(N-1 downto 0);
        cin:  in  std_logic;
        s:    out std_logic_vector(N-1 downto 0)
    );
end cs_block;

architecture rtl of cs_block is    
    signal sum_cin0, sum_cin1: std_logic_vector(N-1 downto 0);
begin
    -- instantiate first rca used to compute sum on n bits with fixed carry input of 0
    rca_0: entity work.rca
        generic map(N => N)
        port map(a => a, b => b, ci => '0', s => sum_cin0);

    -- instantiate second rca used to compute sum on n bits with fixed carry input of 1
    rca_1: entity work.rca
        generic map(N => N)
        port map(a => a, b => b, ci => '1', s => sum_cin1);

    -- mux that selects the actual output, based on the actual carry input
    output_selector: process (all)
    begin
        if cin = '0' then
            s <= sum_cin0;
        else
            s <= sum_cin1;
        end if;
    end process output_selector;
end rtl;
