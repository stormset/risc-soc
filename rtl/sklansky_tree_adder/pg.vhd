library ieee;
use ieee.std_logic_1164.all;

entity pg is
    port (
        a, b  : in  std_logic;
        p, g  : out std_logic
    );
end pg;

architecture behavioral of pg is
begin
    p <= a xor b;
    g <= a and b;
end behavioral;
