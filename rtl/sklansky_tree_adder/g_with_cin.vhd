library ieee;
use ieee.std_logic_1164.all;

entity g_with_cin is
    port (
        a, b  : in  std_logic;
        cin   : in  std_logic;
        g     : out std_logic
    );
end g_with_cin;

architecture behavioral of g_with_cin is
begin
    g <= (a and b) or ((a xor b) and cin); -- g1 + p1*cin, where g1 = a and b; p1 = a xor b;
end behavioral;
