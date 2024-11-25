library ieee;
use ieee.std_logic_1164.all;

entity g_block is
    port (
        pg_curr : in  std_logic_vector(1 downto 0); -- (p_i:k, g_i:k)
        g_prev  : in  std_logic;                    -- g_(k-1 : j)
        g       : out std_logic                     -- g_i:j
    );
end g_block;

architecture behavioral of g_block is
begin
    g <= pg_curr(0) or (pg_curr(1) and g_prev);  -- g_i:j = g_i:k + p_i:k * g_(k-1 : j)
end behavioral;
