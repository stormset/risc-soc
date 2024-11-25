library ieee;
use ieee.std_logic_1164.all;

entity pg_network is
    generic (
        N  :   integer
    );
    port (
        a, b  : in  std_logic_vector(n - 1 downto 0);
        cin   : in  std_logic;
        pgs   : out std_logic_vector(2*n - 1 downto 0) -- 2*N elememts for p+g (msb is p lsb is g), first element only generates g (since p is not used, so 1 element will not be connected) 
    );
end pg_network;

architecture structural of pg_network is
begin
    -- drive pgs(1) to 0, this is not used, as the first element in the network only generates a 'g',
    -- but much easier to describe the indexing if present (synthesizer will take care of optimizing it away)
    pgs(1) <= '0';

    gen_pgs: for i in 0 to N - 1 generate
        gen_g: if i = 0 generate
            g0: entity work.g_with_cin
                port map (a => a(i), b => b(i), cin => cin, g => pgs(i));
        end generate gen_g;

        gen_pg: if i > 0 generate
            pgi: entity work.pg
                port map (a => a(i), b => b(i), p => pgs(2*i + 1), g => pgs(2*i));
        end generate gen_pg;
    end generate;
end structural;
