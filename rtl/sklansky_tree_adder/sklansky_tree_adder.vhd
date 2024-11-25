library ieee;
use ieee.std_logic_1164.all;

entity sklansky_tree_adder is
    generic (
        NBIT           : integer := 32;
        NBIT_PER_BLOCK : integer := 4
    );
    port (
        a, b : in  std_logic_vector(NBIT-1 downto 0);
        cin  : in  std_logic;
        s    : out std_logic_vector(NBIT-1 downto 0);
        cout : out std_logic
    );
end sklansky_tree_adder;

architecture rtl of sklansky_tree_adder is
    signal co_signals: std_logic_vector((NBIT / NBIT_PER_BLOCK)-1 downto 0);
    signal sum_generator_cin: std_logic_vector((NBIT / NBIT_PER_BLOCK) - 1 downto 0);
begin
    -- carry generator
    -- inputs: a; b; cin bit
    -- output: carry out signals (c4, c8, ..., c32)
    carry_generator: entity work.carry_generator
        generic map (
            NBIT           => NBIT,
            NBIT_PER_BLOCK => NBIT_PER_BLOCK
        )
        port map (
            a => a,
            b => b,
            cin => cin,
            co => co_signals
        );

    -- sum generator
    -- inputs: a; b; carries generated by carry generator, except the last carry (c32) with cin bit concatenated
    -- output: sum (s)
    sum_generator_cin <= co_signals(co_signals'length - 2 downto 0) & cin;
    sum_generator: entity work.sum_generator
        generic map (
            NBLOCKS        => NBIT/NBIT_PER_BLOCK,
            NBIT_PER_BLOCK => NBIT_PER_BLOCK
        )
        port map (
            a  => a,
            b  => b,
            ci => sum_generator_cin,
            s  => s
        );

    -- carry out is the last bit (c32) generated by the carry generator
    cout <= co_signals(co_signals'length - 1);
end rtl;
