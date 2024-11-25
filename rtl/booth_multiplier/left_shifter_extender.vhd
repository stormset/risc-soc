library ieee;
use ieee.std_logic_1164.all;

-- shifts the signal left by n positions logically, without dropping digits, thus extending the width by shift amount (s)
-- generic parameters:
--     N: width of the input signal
--     S: shift amount
entity left_shifter_extender is
    generic (
        N  : integer;  -- width of the input signal
        S  : integer   -- shift amount
    );
    port (
        sig         : in  std_logic_vector(n-1 downto 0);
        shifted_sig : out std_logic_vector((n + s)-1 downto 0)
    );
end left_shifter_extender;
 
 
architecture behavioral of left_shifter_extender is
begin
    shifted_sig(shifted_sig'high downto s) <= sig;
    shifted_sig(s - 1 downto 0) <= (others => '0');
end behavioral;
