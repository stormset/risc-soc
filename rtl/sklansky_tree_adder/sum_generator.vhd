library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity sum_generator is
    generic (
        NBIT_PER_BLOCK : integer := 4;
        NBLOCKS        : integer := 8
    );
    port (
        a, b  : in  std_logic_vector(NBIT_PER_BLOCK * NBLOCKS - 1 downto 0);
        ci    : in  std_logic_vector(NBLOCKS - 1 downto 0);
        s     : out std_logic_vector(NBIT_PER_BLOCK * NBLOCKS - 1 downto 0)
    );
end sum_generator;

architecture structural of sum_generator is
begin
    cs_blocks: for i in 0 to NBLOCKS - 1 generate
        cs_blocki: entity work.cs_block
            generic map (N => NBIT_PER_BLOCK)
            port map (a   => a((i+1) * NBIT_PER_BLOCK - 1 downto i * NBIT_PER_BLOCK),
                      b   => b((i+1) * NBIT_PER_BLOCK - 1 downto i * NBIT_PER_BLOCK),
                      cin => ci(i),
                      s   => s((i+1) * NBIT_PER_BLOCK - 1 downto i * NBIT_PER_BLOCK));
    end generate;
end structural;
