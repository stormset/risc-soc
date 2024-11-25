library ieee;
use ieee.std_logic_1164.all;

use work.utils_package.all;

entity sklansky_tree is
    generic (
        N         :   integer;
		SPARSITY  :   integer := 4
    );
    port (
        pg    : in  std_logic_vector(2*N - 1 downto 0);
        cout  : out std_logic_vector(integer(floor_div(N, SPARSITY)) - 1 downto 0)
    );
end sklansky_tree;

architecture structural of sklansky_tree is
    -- number of elements is the number of rows in the tree + 1 (for the input pg signals) (clog of n).
    -- each element has 2*n bits for the pg signals.
    type mx_type is array (clog2(N) downto 0) of std_logic_vector(2*N - 1 downto 0);
    signal sklansky_mx: mx_type;
begin
    -- connect first row of the sklansky matrix to the input pg signals
    sklansky_mx(0) <= pg;

    -- generate the sklansky tree
    --     to understand how the sparsity affects the tree structure, refer to the book:
    --     CMOS VLSI Design: A circuits and systems perspective (chapter 11) available here:
    --     https://pages.hmc.edu/harris/cmosvlsi/4e/cmosvlsidesign_4e_ch11.pdf
    -- the structure of the tree:
    --     > the tree will have clog2(N) levels
    --     > each level contains a sequence of 2^k wires followed by a sequence of 2^k blocks (g or pg described in the following),
    --       where k is the index of the level 0,1,2,... . this 2*(2^k) length sequence is repeated throughout the breadth of the tree,
    --       which equals to n (number of nodes in a level). in case n is not power of 2 we simply don't generate the whole 2^k length of the sequence.
    --     > effect of sparsity (which equals to 4 in case of the pentium 4): we only have to generate blocks/wires in case they are connected to carry out,
    --       thus their index in the row is divisible by the sparsity. there is one exception to this rule: in case a g or pg block is at the end of the 2^k length
    --       sequence of blocks, it must be genrated, as it's result is used by later blocks in the following level of the tree.
    --     > wires: connect the current row to the following.
    --     > g and pg blocks: the first 2^k length sequence of blocks in each level are g blocks, as only the generate (g) signal is generated from the lsb of the operands,
    --       hence only a genrate block is connected to that, and each generate block gets connected to genrate blocks. the rest of the 2^k length sequences in a level are pg blocks.
    rows: for k in 0 to clog2(N) - 1 generate
        cols: for i in 0 to N - 1 generate

            -- we would normally step with i (column iterator) 2*2^k after each iteration, but vhdl only supports steps of 1, hence "i mod (2 * (2**k))" is used
            block_seq: if (i mod (2 * (2**k))) = 0 generate
            
                -- generate wires
                gen_wires: for j in 0 to (2**k) - 1 generate
                    f: if (i + j < N) and ((i + j + 1) mod SPARSITY) = 0 generate
                        sklansky_mx(k+1)((i + j)*2)     <= sklansky_mx(k)((i + j)*2);     -- connect g of kth row to g of previous row
                        sklansky_mx(k+1)((i + j)*2 + 1) <= sklansky_mx(k)((i + j)*2 + 1); -- connect p of kth row to p of previous row
                    end generate f;
                end generate;

                -- generate g and pg blocks
                gen_blocks: for j in 0 to (2**k) - 1 generate

                    bound_check: if (i + j + (2**k)) < N generate

                        -- first condition:  (j = ((2**k) - 1)) meaning:
                        --     this block is the last block in a repeated sequence (of length 2**k), hence it's result is used by
                        --     later stages, thus it needs to be generated, no matter if the carry is needed or not
                        -- second condition: ((i + j + (2**k) + 1) mod sparsity = 0) meaning:
                        --     this block needs to be generated as the carry at the current index is needed
                        gen_block: if (j = ((2**k) - 1)) or ((i + j + (2**k) + 1) mod SPARSITY = 0) generate
                            gen_g_block: if i = 0 generate
                                -- i == 0 means, that this is the first 2^k length repeated sequence in a row, thus g block is needed
                                gi: entity work.g_block
                                    port map (
                                        pg_curr => sklansky_mx(k)((i + j + (2**k))*2 + 1 downto (i + j + (2**k))*2),
                                        g_prev  => sklansky_mx(k)((i + (2**k) - 1)*2),
                                        g       => sklansky_mx(k + 1)((i + j + (2**k))*2)
                                    );
                            end generate gen_g_block;
                            gen_pg_block: if i > 0 generate
                                -- generate pg block (rest of 2^k length sequences are pg blocks)
                                pgi: entity work.pg_block
                                    port map (
                                        pg_curr  => sklansky_mx(k)((i + j + (2**k))*2 + 1 downto (i + j + (2**k))*2),
                                        pg_prev  => sklansky_mx(k)((i + (2**k) - 1)*2 + 1 downto (i + (2**k) - 1)*2),
                                        pg       => sklansky_mx(k + 1)((i + j + (2**k))*2 + 1 downto (i + j + (2**k))*2)
                                    );
                            end generate gen_pg_block;
                            
                        end generate gen_block;

                    end generate bound_check;

                end generate;

            end generate block_seq;

        end generate;
    end generate;

    -- connect last row of the sklansky matrix to the cout output
    gen_cout: for i in 1 to N generate
        cout_wire: if (i mod SPARSITY) = 0 generate
            -- connect g's in the last row of the sklansky matrix to the cout output
            cout(integer(i / SPARSITY) - 1) <= sklansky_mx(clog2(N))(2*i - 2);
        end generate cout_wire;
    end generate;
end structural;
