library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_package.all;

entity barrel_shifter is
    generic (
        NBIT :    integer := 32
    );
    port (
        value              : in  std_logic_vector(NBIT - 1 downto 0);
        amount             : in  std_logic_vector(clog2(NBIT) - 1 downto 0);
        left_n_right       : in  std_logic;
        logic_n_arithmetic : in  std_logic;
        rotate             : in  std_logic;
        shifted_value      : out std_logic_vector(NBIT - 1 downto 0)
    );
end entity;
architecture behavioural of barrel_shifter is
    constant stages : integer := clog2(NBIT);

    type stage_out_t is array (natural range <>) of std_logic_vector(NBIT - 1 downto 0);

    signal stage_outs : stage_out_t(stages downto 0);
begin
    stage_outs(0) <= value;
    shifted_value <= stage_outs(stages);

    genstage : for i in 0 to stages - 1 generate
        process (all)
        begin
            if (amount(i) = '0') then
                stage_outs(i + 1) <= stage_outs(i);
            else
                if (rotate = '0') then
                    if (left_n_right = '0') then
                        if (logic_n_arithmetic = '0') then
                            -- arithmetic right shift
                            stage_outs(i + 1) <= ((2 ** i - 1) downto 0 => stage_outs(i)(NBIT - 1)) & stage_outs(i)(NBIT - 1 downto 2 ** i);
                        else
                            -- logical right shift
                            stage_outs(i + 1) <= ((2 ** i - 1) downto 0 => '0') & stage_outs(i)(NBIT - 1 downto 2 ** i);
                        end if;
                    else
                        -- logical/arithmetic left shift
                        stage_outs(i + 1) <= stage_outs(i)((NBIT - 2 ** i - 1) downto 0) & ((2 ** i - 1) downto 0 => '0');
                    end if;
                else
                    if (left_n_right = '0') then
                        -- rotate right shift
                        stage_outs(i + 1) <= stage_outs(i)((2 ** i - 1) downto 0) & stage_outs(i)(NBIT - 1 downto 2 ** i);
                    else
                        -- rotate left shift
                        stage_outs(i + 1) <= stage_outs(i)((NBIT - 2 ** i - 1) downto 0) & stage_outs(i)(NBIT - 1 downto (NBIT - 2 ** i));
                    end if;
                end if;
            end if;
        end process;
    end generate;
end;
