library ieee;
use ieee.std_logic_1164.all;

entity pg_block is
    port (
        pg_curr  : in  std_logic_vector(1 downto 0);  -- (p_i:k, g_i:k)
        pg_prev  : in  std_logic_vector(1 downto 0);  -- (p_(k-1 : j), g_(k-1 : j))
        pg       : out std_logic_vector(1 downto 0)   -- (p_i:j, g_i:j)
    );
end pg_block;

architecture behavioral of pg_block is
begin
    pg(1) <= pg_curr(1) and pg_prev(1);                  -- p_i:j = p_i:k * p_(k-1 : j)
    pg(0) <= pg_curr(0) or (pg_curr(1) and pg_prev(0));  -- g_i:j = g_i:k + p_i:k * g_(k-1 : j)
end behavioral;
