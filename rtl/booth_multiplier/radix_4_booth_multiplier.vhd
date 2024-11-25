library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.utils_package.all;

entity radix_4_booth_multiplier is
    generic (
        NBIT :    integer := 32
    );
    port (
        a, b : in  std_logic_vector(NBIT-1 downto 0);
        p    : out std_logic_vector(2*NBIT-1 downto 0)
    );
end radix_4_booth_multiplier;

architecture structural of radix_4_booth_multiplier is
    -- signals to extend the multiplier
    signal extended_multiplier: std_logic_vector(b'length + (b'length mod 2) - 1 downto 0);
    signal zero_extended_multiplier: std_logic_vector(b'length + (b'length mod 2) downto 0);

    --signal complemented_multiplicand: std_logic_vector(NBIT downto 0);
    signal complemented_multiplicand: std_logic_vector(NBIT downto 0);

    type encoder_mx_type is array (integer(ceil_div(NBIT, 2)) - 1 downto 0) of std_logic_vector(2 downto 0);
    signal encoder_outs: encoder_mx_type;

    -- these signals are used to interconnect the stages of the multiplier
    -- the width of these signals and the indices used to index them were calculated by the using the sum of arithmetic sequence
    -- (these calculations are not detailed in the comments, but are straightforward)
    signal shifted_multiplicands: std_logic_vector(integer(ceil_div(NBIT, 2))*(integer(ceil_div(NBIT, 2)) + NBIT + 1) - 1 downto 0);
    signal neg_shifted_multiplicands: std_logic_vector(integer(ceil_div(NBIT, 2))*(integer(ceil_div(NBIT, 2)) + NBIT + 2) - 1 downto 0);
    signal partial_products: std_logic_vector(integer(ceil_div(NBIT, 2))*(integer(ceil_div(NBIT, 2)) + NBIT + 2) - 2 downto 0);
begin
    -- multiplier needs to be zero extended at lsb in case it's length is odd
    extended_multiplier <= b & ((b'length mod 2) - 1 downto 0 => '0');

    -- we need to append a '0' bit at the lsb of the multiplier
    zero_extended_multiplier <= extended_multiplier & '0';

    -- 2s complement a to create -a (on NBIT + 1)
    complemented_multiplicand <= std_logic_vector(-signed(resize(signed(a), complemented_multiplicand'length)));

    -- generate stages
    gen_partial_product: for i in 0 to integer(ceil_div(NBIT, 2)) - 1 generate
    begin
        encoderi: entity work.radix_4_booth_selector
            port map (
                selector_input => zero_extended_multiplier((i+1)*2 downto i*2),
                double_single => encoder_outs(i)(2 downto 1),
                neg => encoder_outs(i)(0)
            );

        stage0: if i = 0 generate
            -- in case i == 0, we do not have previous partial product (set to 0)
            pp0: entity work.radix_4_booth_partial_product
                generic map (n => NBIT, level => i)
                port map (
                    encoder_double_single => encoder_outs(i)(2 downto 1),
                    encoder_negative => encoder_outs(i)(0),
                    prev_partial_product => (others => '0'),
                    prev_shifted_multiplicand => a,                               -- input a, used in first stage by mux
                    prev_neg_shifted_multiplicand => complemented_multiplicand,   -- input -a, used in first stage by mux
                    curr_shifted_multiplicand => shifted_multiplicands((i+1)*(i + NBIT + 2) - 1 downto i*(i + NBIT + 1)),
                    curr_neg_shifted_multiplicand => neg_shifted_multiplicands((i+1)*(i + NBIT + 3) - 1 downto i*(i + NBIT + 2)),
                    curr_partial_product => partial_products((i+1)*(i + NBIT + 2) + i - integer(floor(real(i+1) / ceil_div(NBIT, 2))) downto i*(i + NBIT + 1) + i)
                );
        end generate stage0;

        stagei: if i > 0 generate
            -- in case i > 0, we do have previous partial product
            ppi: entity work.radix_4_booth_partial_product
                generic map (n => NBIT, level => i)
                port map (
                    encoder_double_single => encoder_outs(i)(2 downto 1),
                    encoder_negative => encoder_outs(i)(0),
                    prev_partial_product => partial_products(i*(i + NBIT + 1) + i - 1 downto (i-1)*(i + NBIT) + i - 1),
                    prev_shifted_multiplicand => shifted_multiplicands(i*(i + NBIT + 1) - 1 downto (i-1)*(i + NBIT)),
                    prev_neg_shifted_multiplicand => neg_shifted_multiplicands(i*(i + NBIT + 2) - 1 downto (i-1)*(i + NBIT + 1)),
                    curr_shifted_multiplicand => shifted_multiplicands((i+1)*(i + NBIT + 2) - 1 downto i*(i + NBIT + 1)),
                    curr_neg_shifted_multiplicand => neg_shifted_multiplicands((i+1)*(i + NBIT + 3) - 1 downto i*(i + NBIT + 2)),
                    curr_partial_product => partial_products((i+1)*(i + NBIT + 2) + i - integer(floor(real(i+1) / ceil_div(NBIT, 2))) downto i*(i + NBIT + 1) + i)
                );
        end generate stagei;

        -- assign last partial product to the output (final product)
        p <= partial_products(partial_products'high downto partial_products'high - 2*NBIT + 1);
    end generate;
end structural;
