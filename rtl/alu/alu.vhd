library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_package.all;
use work.control_word_package.all;

entity alu is
    generic (
        NBIT                : integer := 32;
        ADDER_BIT_PER_BLOCK : integer := 4
    );
    port(
        i_operand_1  : in  std_logic_vector(NBIT-1 downto 0);
        i_operand_2  : in  std_logic_vector(NBIT-1 downto 0);
        i_operation  : in  alu_operation_t;
        o_result     : out std_logic_vector(NBIT-1 downto 0)
    );
end alu;

architecture rtl of alu is
    -- configuration signals for subcomponents
    signal subtract                 : std_logic;
    signal op2_xor_subtract         : std_logic_vector(NBIT-1 downto 0);

    signal shift_left_n_right       : std_logic;
    signal shift_logic_n_arithmetic : std_logic;
    signal shift_rotate             : std_logic;

    -- ALU component outputs
    signal adder_out     : std_logic_vector(NBIT-1 downto 0);
    signal carry_out     : std_logic;  -- C
    signal zero_flag     : std_logic;  -- Z
    signal negative_flag : std_logic;  -- N
    signal overflow_flag : std_logic;  -- V

    signal shifter_out   : std_logic_vector(NBIT-1 downto 0);

    -- logic operation outputs
    signal op1_and_op2         : std_logic_vector(NBIT-1 downto 0);
    signal op1_or_op2          : std_logic_vector(NBIT-1 downto 0);
    signal op1_xor_op2         : std_logic_vector(NBIT-1 downto 0);

    -- compare operation outputs
    signal op1_eq_op2          : std_logic;
    signal op1_neq_op2         : std_logic;
    signal op1_gt_op2          : std_logic;
    signal op1_gt_op2_unsigned : std_logic;
    signal op1_ge_op2          : std_logic;
    signal op1_ge_op2_unsigned : std_logic;
    signal op1_lt_op2          : std_logic;
    signal op1_lt_op2_unsigned : std_logic;
    signal op1_le_op2          : std_logic;
    signal op1_le_op2_unsigned : std_logic;
begin
    -- parallel prefix adder based on sklansky tree
    adder: entity work.sklansky_tree_adder
        generic map(
            NBIT           => NBIT,
            NBIT_PER_BLOCK => ADDER_BIT_PER_BLOCK
        )
        port map(
            a    => i_operand_1,
            b    => op2_xor_subtract,
            cin  => subtract,
            cout => carry_out,
            s    => adder_out
        );

    -- barrel shifter
    shifter : entity work.barrel_shifter     
        generic map (
            NBIT => NBIT
        )
        port map(
            value              => i_operand_1,
            amount             => i_operand_2(clog2(NBIT) - 1 downto 0),
            left_n_right       => shift_left_n_right,
            logic_n_arithmetic => shift_logic_n_arithmetic,
            rotate             => shift_rotate, 
            shifted_value      => shifter_out
        );

    -- xor operand_2 with subtract configuration bit to construct the
    -- ones' complement of the number when subtract is set
    xor_operand_2: for i in 0 to NBIT-1 generate
        op2_xor_subtract(i) <= i_operand_2(i) xor subtract;
    end generate;

    -- calculate flags: zero (Z), negative (N), overflow (V)
    flags: process (all)
    begin
        if to_integer(unsigned(adder_out)) = 0 then
            zero_flag <= '1';
        else
            zero_flag <= '0';
        end if;

        overflow_flag <= not(i_operand_1(NBIT-1) xor op2_xor_subtract(NBIT-1)) and (i_operand_1(NBIT-1) xor adder_out(NBIT-1));
        negative_flag <= adder_out(NBIT-1);
    end process flags;

    -- configure adder based on operation
    adder_conf: process (all)
    begin
        if (i_operation = op_add) then
            subtract <= '0';
        else
            subtract <= '1';
        end if;
    end process adder_conf;

    -- configure shifter based on operation
    shifter_conf: process (all)
    begin
        if (i_operation = op_sll or i_operation = op_rol) then
            shift_left_n_right <= '1';
        else
            shift_left_n_right <= '0';
        end if;

        if (i_operation = op_sll or i_operation = op_srl) then
            shift_logic_n_arithmetic <= '1';
        else
            shift_logic_n_arithmetic <= '0';
        end if;

        if (i_operation = op_rol or i_operation = op_ror) then
            shift_rotate <= '1';
        else
            shift_rotate <= '0';
        end if;
    end process shifter_conf;

    -- for now let the synthesizer implement these
    -- TODO: implementation based on OpenSparc T2 Logic Unit
    logical_operations: process (all)
    begin
        op1_and_op2 <= i_operand_1 and i_operand_2;
        op1_or_op2  <= i_operand_1 or  i_operand_2;
        op1_xor_op2 <= i_operand_1 xor i_operand_2;
    end process logical_operations;

    -- calculate flags used in compare operations
    -- based on: https://www.righto.com/2016/01/conditional-instructions-in-arm1.html
    compare_operations: process (all)
    begin
        op1_eq_op2          <= zero_flag; -- Z == 1
        op1_neq_op2         <= not zero_flag; -- Z == 0
        op1_gt_op2          <= (not zero_flag) and (not (negative_flag xor overflow_flag)); -- Z == 0 and N = V
        op1_gt_op2_unsigned <= carry_out and (not zero_flag); -- C = 1 and Z = 0
        op1_ge_op2          <= not (negative_flag xor overflow_flag); -- N = V
        op1_ge_op2_unsigned <= carry_out; -- C = 1
        op1_lt_op2          <= negative_flag xor overflow_flag; -- N != V
        op1_lt_op2_unsigned <= not carry_out; -- C = 0
        op1_le_op2          <= zero_flag or (negative_flag xor overflow_flag); -- Z = 1 or N != V
        op1_le_op2_unsigned <= zero_flag or (not carry_out); -- Z = 1 or C = 0
    end process compare_operations;

    -- result selector
    result_mux: process (all)
    begin
        o_result <= (others => '0');

        case i_operation is
            -- add / sub
            when op_add  => o_result <= adder_out;
            when op_sub  => o_result <= adder_out;

            -- shifts
            when op_sll  => o_result <= shifter_out;
            when op_srl  => o_result <= shifter_out;
            when op_sra  => o_result <= shifter_out;
            when op_rol  => o_result <= shifter_out;
            when op_ror  => o_result <= shifter_out;

            -- logical
            when op_and  => o_result <= op1_and_op2;
            when op_or   => o_result <= op1_or_op2;
            when op_xor  => o_result <= op1_xor_op2;

            -- compare
            when op_seq  => o_result(0) <= op1_eq_op2;
            when op_sne  => o_result(0) <= op1_neq_op2;
            when op_sgt  => o_result(0) <= op1_gt_op2;
            when op_sgtu => o_result(0) <= op1_gt_op2_unsigned;
            when op_sge  => o_result(0) <= op1_ge_op2;
            when op_sgeu => o_result(0) <= op1_ge_op2_unsigned;
            when op_slt  => o_result(0) <= op1_lt_op2;
            when op_sltu => o_result(0) <= op1_lt_op2_unsigned;
            when op_sle  => o_result(0) <= op1_le_op2;
            when op_sleu => o_result(0) <= op1_le_op2_unsigned;
        end case;
    end process result_mux;
end rtl;
