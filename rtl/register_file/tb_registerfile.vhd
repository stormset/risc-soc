library ieee;

use ieee.std_logic_1164.all;

entity tbregisterfile is
end tbregisterfile;

architecture testa of tbregisterfile is
    signal clk: std_logic := '0';
    signal rst: std_logic;
    signal wr_en: std_logic;
    signal add_wr: std_logic_vector(4 downto 0);
    signal add_rd1: std_logic_vector(4 downto 0);
    signal add_rd2: std_logic_vector(4 downto 0);
    signal datain: std_logic_vector(63 downto 0);
    signal out1: std_logic_vector(63 downto 0);
    signal out2: std_logic_vector(63 downto 0);

    component register_file
        generic(
            DATA_WIDTH: integer := 64;
            ADDR_WIDTH: integer := 5
        );
        port (
            clk: in  std_logic;

            -- synchronous rst (active high)
            rst: in  std_logic;

            -- write enable (active high)
            wr_en: in  std_logic;

            -- write|read_1|read_2 port address
            add_wr, add_rd1, add_rd2: in std_logic_vector(ADDR_WIDTH-1 downto 0);

            -- write port data in
            datain: in  std_logic_vector(DATA_WIDTH-1 downto 0);

            -- read_1|read_2 port data out
            out1, out2: out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component;

begin 

    register_file_inst: register_file
        generic map (
            DATA_WIDTH => 64,
            ADDR_WIDTH => 5
        )
        port map (
            clk,
            rst,
            wr_en,
            add_wr,
            add_rd1,
            add_rd2,
            datain,
            out1,
            out2
        );

    rst <= '1','0' after 5 ns;
    wr_en <= '0','1' after 6 ns, '0' after 7 ns, '1' after 10 ns, '0' after 20 ns;
    add_wr <= "10110", "01000" after 9 ns;
    add_rd1 <="10110", "01000" after 9 ns;
    add_rd2<= "11100", "01000" after 9 ns;
    datain<=(others => '0'),(others => '1') after 8 ns;

    pclock : process(clk)
    begin
        clk <= not(clk) after 0.5 ns;    
    end process;
end testa;
