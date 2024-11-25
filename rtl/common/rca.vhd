library ieee; 
use ieee.std_logic_1164.all; 
use ieee.std_logic_unsigned.all;

entity rca is 
    generic (
        N  : integer
    );
    port (
        a, b: in  std_logic_vector(N-1 downto 0);
        ci:   in  std_logic;
        s:    out std_logic_vector(N-1 downto 0);
        co:   out std_logic
    );
end rca; 

architecture structural of rca is
    signal s_outs : std_logic_vector(N-1 downto 0);
    signal c_outs : std_logic_vector(N downto 0);
begin
    -- output assignments
    s         <= s_outs;
    co        <= c_outs(N);
    
    c_outs(0) <= ci;
    -- chain full-adders: each fa gets the carry out of the previous stage and the relevant bit of the 2 operands
    chained_fas: for i in 1 to N generate
        full_adder : entity work.full_adder 
            port map (
                a(i-1),
                b(i-1),
                c_outs(i-1),
                s_outs(i-1),
                c_outs(i)
            ); 
    end generate;
end structural;
