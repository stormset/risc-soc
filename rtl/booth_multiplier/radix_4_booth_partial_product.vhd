library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity radix_4_booth_partial_product is
    generic (
        n     : integer; -- width of the operands of the multiplier
        LEVEL : integer  -- level of the partial product calculator [0 == input level (first mux); ceil(N/2) - 1 == output level (last mux)]
    );
    port (
        encoder_double_single         : in  std_logic_vector(1 downto 0);                    -- from booth selector: 2*prev or 4*prev should be selected
        encoder_negative              : in  std_logic;                                       -- from booth selector: negative should be selected
        prev_partial_product          : in  std_logic_vector(N + LEVEL*2 downto 0);          -- previous stage partial product
        prev_shifted_multiplicand     : in  std_logic_vector(N + LEVEL*2 - 1 downto 0);      -- previous stage largest shifted multiplicand (this way next stages only have to shift by 1 and 2, thus reducing the fanout of the multiplicand)
        prev_neg_shifted_multiplicand : in  std_logic_vector(N + LEVEL*2 downto 0);          -- previous stage largest 2's complemented shifted multiplicand
        curr_shifted_multiplicand     : out std_logic_vector(N + (LEVEL+1)*2 - 1 downto 0);  -- current stage largest shifted multiplicand
        curr_neg_shifted_multiplicand : out std_logic_vector(N + (LEVEL+1)*2 downto 0);      -- current stage largest 2's complemented shifted multiplicand
        curr_partial_product          : out std_logic_vector(N + (LEVEL+1)*2 - integer(floor(real(LEVEL+1) / ceil(real(N) / real(2)))) downto 0)
    );
end radix_4_booth_partial_product;

architecture structural of radix_4_booth_partial_product is
    -- signals for holding shifted values, before connecting to the mux sign extension is needed to the widest multiplexed signal
    signal shift_1: std_logic_vector(N + LEVEL*2 downto 0);
    signal neg_shift_1: std_logic_vector(N + LEVEL*2 + 1 downto 0);
    signal shift_1_extended, neg_shift_1_extended: std_logic_vector(curr_neg_shifted_multiplicand'range);
    signal shift_2: std_logic_vector(curr_shifted_multiplicand'range);
    signal shift_2_extended, neg_shift_2: std_logic_vector(curr_neg_shifted_multiplicand'range);
    signal booth_selector_out: std_logic_vector(curr_neg_shifted_multiplicand'range);
    signal op_1_extended, op_2_extended: std_logic_vector(curr_partial_product'range);
    signal mux_ctrl_signal: std_logic_vector(2 downto 0);
begin
    -- concatenate encoder outputs (encoder_negative to the msb of encoder_double_single),
    -- to use it as selection signal of the 5to1 mux
    mux_ctrl_signal <= (encoder_negative & encoder_double_single);

    -- in case level = 0, there is no previous partial product to add to (so no adder is needed)
    level_zero : if LEVEL = 0 generate
        -- in case level = 0, there is only 2 shifter needed (for 2a and -2a),
        -- the other mux inputs are a and -a (==prev_shifted_multiplicand and prev_neg_shifted_multiplicand) unchanged
        lshifter0: entity work.left_shifter_extender
            generic map (N => prev_shifted_multiplicand'length, S => 1)
            port map (
                sig => prev_shifted_multiplicand,
                shifted_sig => shift_1
            );

        neg_lshifter0: entity work.left_shifter_extender
            generic map (N => prev_neg_shifted_multiplicand'length, S => 1)
            port map (
                sig => prev_neg_shifted_multiplicand,
                shifted_sig => neg_shift_1
            );
        
        -- sign extend mux inputs (in case LEVEL = 0, shift_1 corresponds to prev_shifted_multiplicand (==a), shift_2 corresponds to shift_1 (==2a))
        shift_1_extended     <= std_logic_vector(resize(signed(prev_shifted_multiplicand), curr_neg_shifted_multiplicand'length));
        neg_shift_1_extended <= std_logic_vector(resize(signed(prev_neg_shifted_multiplicand), curr_neg_shifted_multiplicand'length));
        shift_2              <= std_logic_vector(resize(signed(shift_1), curr_shifted_multiplicand'length));
        shift_2_extended     <= std_logic_vector(resize(signed(shift_1), curr_neg_shifted_multiplicand'length));
        neg_shift_2          <= std_logic_vector(resize(signed(Neg_shift_1), curr_neg_shifted_multiplicand'length));

        -- MUX for 0, a, 2a, -a, -2a
        booth_selector_mux: process (all)
        begin
            case mux_ctrl_signal is
                when "001"  => booth_selector_out <= shift_1_extended;
                when "010"  => booth_selector_out <= shift_2_extended;
                when "101"  => booth_selector_out <= neg_shift_1_extended;
                when "110"  => booth_selector_out <= neg_shift_2;
                when others => booth_selector_out <= (others => '0');
            end case;
        end process booth_selector_mux;

        -- assign booth_selector_out to the output partial product
        curr_partial_product <= booth_selector_out(curr_partial_product'range);

        -- put the shifted (2a) value to the output port (the next stage will only have to shift it by 1 and 2 to get 4a and 8a)
        curr_shifted_multiplicand <= shift_2;
        -- put the shifted (-2a) value to the output port (the next stage will only have to shift it by 1 and 2 to get -4a and -8a)
        curr_neg_shifted_multiplicand <= neg_shift_2;
    end generate level_zero;

    -- in case LEVEL > 0, 4 shifter is needed (for 2*prev_shifted_multiplicand and 4*prev_shifted_multiplicand, and the corresponding negative values)
    level_pos : if LEVEL > 0 generate
        lshifter0: entity work.left_shifter_extender
            generic map (N => prev_shifted_multiplicand'length, S => 1)
            port map (
                sig => prev_shifted_multiplicand,
                shifted_sig => shift_1
            );

        lshifter1: entity work.left_shifter_extender
            generic map (N => prev_shifted_multiplicand'length, S => 2)
            port map (
                sig => prev_shifted_multiplicand,
                shifted_sig => shift_2
            );

        neg_lshifter0: entity work.left_shifter_extender
            generic map (N => prev_neg_shifted_multiplicand'length, S => 1)
            port map (
                sig => prev_neg_shifted_multiplicand,
                shifted_sig => neg_shift_1
            );

        neg_lshifter1: entity work.left_shifter_extender
            generic map (N => prev_neg_shifted_multiplicand'length, S => 2)
            port map (
                sig => prev_neg_shifted_multiplicand,
                shifted_sig => neg_shift_2
            );
        
        -- sign extend mux inputs
        shift_1_extended <= std_logic_vector(resize(signed(shift_1), curr_neg_shifted_multiplicand'length));
        neg_shift_1_extended <= std_logic_vector(resize(signed(Neg_shift_1), curr_neg_shifted_multiplicand'length));
        shift_2_extended <= std_logic_vector(resize(signed(shift_2), curr_neg_shifted_multiplicand'length));

        -- MUX for 0, 2*prev, 4*prev, -2*prev, -4*prev
        booth_selector_mux: process (all)
        begin
            case mux_ctrl_signal is
                when "001"  => booth_selector_out <= shift_1_extended;
                when "010"  => booth_selector_out <= shift_2_extended;
                when "101"  => booth_selector_out <= neg_shift_1_extended;
                when "110"  => booth_selector_out <= neg_shift_2;
                when others => booth_selector_out <= (others => '0');
            end case;
        end process booth_selector_mux;

        -- sign extend prev_partial_product, to match the required width of the current partial product
        op_1_extended <= std_logic_vector(resize(signed(prev_partial_product), curr_partial_product'length));

        -- assign booth_selector_out to the second operand of the adder
        op_2_extended <= booth_selector_out(curr_partial_product'range);

        -- add the prev_partial_product and the mux output together
        -- since the width of the partial product is determined so that no overflow can occour, co can be ignored
        rca: entity work.rca
            generic map (N => curr_partial_product'length)
            port map (
                a  => op_1_extended,
                b  => op_2_extended,
                ci => '0',
                s  => curr_partial_product
            );

        -- put the shifted (4*prev_shifted_multiplicand) value to the output port (the next stage will only have to shift it by 1 and 2)
        curr_shifted_multiplicand <= shift_2;
        -- put the shifted (-4*prev_shifted_multiplicand) value to the output port (the next stage will only have to shift it by 1 and 2)
        curr_neg_shifted_multiplicand <= neg_shift_2;
    end generate level_pos;
end structural;
