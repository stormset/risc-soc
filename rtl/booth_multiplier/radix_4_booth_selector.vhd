library ieee;
use ieee.std_logic_1164.all;

-- input: 3 bits of the multiplicand
-- outputs:
--      double_single : controls the mux select signals
--          > 00 = not single and not double ==> 0
--          > 01 = single and not double     ==> 2*a (shift a left by 1)
--          > 10 = not single and double     ==> 4*a (shift a left by 2)
--      neg: conrols the sign of the mux value (used to control the adder/subtractor functionality)
--          > 1 = negative
--          > 0 = positive
-- implements this table: https://slideplayer.com/slide/17912467/108/images/32/inputs+partial+products+booth+selects.jpg
entity radix_4_booth_selector is
    port (
        selector_input  : in  std_logic_vector(2 downto 0); -- (x_2i+1, x_2i, x_2i-1)
        double_single   : out std_logic_vector(1 downto 0); -- (double, single)
        neg             : out std_logic                     -- negative
    );
end radix_4_booth_selector;

architecture behavioral of radix_4_booth_selector is
begin
    process (selector_input) is
    begin
        case selector_input is
            when "001" | "101" | "010" | "110" => double_single <= "01";
            when "011" | "100" => double_single <= "10";
            when others => double_single <= "00";
        end case;
    end process;

    neg <= selector_input(2); -- negative == x_2i+1
end behavioral;
