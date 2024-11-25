library ieee;
use ieee.std_logic_1164.all;

entity carry_generator is
    generic (
        NBIT           : integer := 32;
        NBIT_PER_BLOCK : integer := 4
    );
    port (
        a, b : in  std_logic_vector(NBIT-1 downto 0);
        cin  : in  std_logic;
        co   : out std_logic_vector((NBIT/NBIT_PER_BLOCK)-1 downto 0)
    );
end carry_generator;

architecture structural of carry_generator is
    signal pg_signals : std_logic_vector(2*NBIT - 1 downto 0);
begin
    pg_net: entity work.pg_network
        generic map (N => NBIT)
        port map (a => a, b => b, cin => cin, pgs => pg_signals);

    sklansky_tree: entity work.sklansky_tree
        generic map (N => NBIT, SPARSITY => NBIT_PER_BLOCK)
        port map (pg => pg_signals, cout => co);
end structural;
