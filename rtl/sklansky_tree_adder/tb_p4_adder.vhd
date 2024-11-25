library IEEE;
use IEEE.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity TB_P4_ADDER is
end TB_P4_ADDER;

architecture TEST of TB_P4_ADDER is
    constant NUMBBIT1  : integer    := 32;
    constant NUMBBIT2  : integer    := 8;
    constant Period   : time      := 1 ns;  -- Clock period (1 GHz)

    component P4_ADDER is
        generic (NBIT  :	integer := 32);
        port (A, B     :    in	std_logic_vector(NBIT-1 downto 0);
              Cin      :    in	std_logic;
              S        :    out	std_logic_vector(NBIT-1 downto 0);
              Cout     :    out	std_logic);
    end component;


    component LFSR16 
        port (CLK, RESET, LD, EN : in std_logic; 
              DIN    : in std_logic_vector(15 downto 0); 
              PRN    : out std_logic_vector(15 downto 0); 
              ZERO_D : out std_logic);
    end component;
    
    -- Declare signals for P4 adder
    signal A1, B1, S1: std_logic_vector(NUMBBIT1-1 downto 0) := (others => '0');
    signal Ci1, Co1: std_logic := '0';

    signal A2, B2, S2: std_logic_vector(NUMBBIT2-1 downto 0) := (others => '0');
    signal Ci2, Co2: std_logic := '0';

    -- Declare signals for LFSR
    signal CLK                   : std_logic := '0';
    signal RESET, LD, EN, ZERO_D : std_logic;
    signal DIN, PRN              : std_logic_vector(15 downto 0);
begin
    -- P4 instantiation
    UUT1: P4_ADDER
        generic map (NBIT => NUMBBIT1)
        port map    (A => A1, B => B1, Cin => Ci1, S => S1, Cout => Co1);
   
    UUT2: P4_ADDER
        generic map (NBIT => NUMBBIT2)
        port map    (A => A2, B => B2, Cin => Ci2, S => S2, Cout => Co2);

    -- Instanciate LFSR for input generation
    LFSR: LFSR16 port map (CLK=>CLK, RESET=>RESET, LD=>LD, EN=>EN, 
                           DIN=>DIN,PRN=>PRN, ZERO_D=>ZERO_D);

    -- stimulus for testing edge cases
    STIMULUS: process
    begin
        A1 <= X"0000FFFF";
        B1 <= X"0000FFFF";
        Ci1 <= '1';
        wait for 2 * PERIOD;

        A1 <= X"0000FFFF";
        B1 <= X"FFFF0000";
        Ci1 <= '1';
        wait for 2 * PERIOD;

        A1 <= X"FFFFFFFF";
        B1 <= X"00000001";
        Ci1 <= '0';
        wait for 2 * PERIOD;

        A1 <= X"FFFFFFFF";
        B1 <= X"00000001";
        Ci1 <= '1';
        wait for 2 * PERIOD;

        A1 <= X"00000000";  -- 0
        B1 <= X"00000000";  -- 0
        Ci1 <= '0';         -- no carry in
        wait for 2 * PERIOD;

        A1 <= X"00000000";  -- 0
        B1 <= X"00000000";  -- 0
        Ci1 <= '1';         -- with carry in
        wait for 2 * PERIOD;

        A1 <= X"000003E7";  -- 999
        B1 <= X"00000001";  -- 1
        Ci1 <= '0';         -- no carry in
        wait for 2 * PERIOD;

        A1 <= X"000003E7";  -- 999
        B1 <= X"00000001";  -- 1
        Ci1 <= '1';         -- with carry in
        wait for 2 * PERIOD;

        wait;
    end process STIMULUS;

    -- feed the 8 bit adder from the LFSR
    A2(0) <= PRN(0);
    A2(1) <= PRN(6);
    A2(2) <= PRN(10);
    A2(3) <= PRN(4);
    A2(4) <= PRN(8);
    A2(5) <= PRN(2);
    A2(6) <= PRN(12);
    A2(7) <= PRN(14);

    B2(0) <= PRN(15);
    B2(1) <= PRN(9);
    B2(2) <= PRN(5);
    B2(3) <= PRN(11);
    B2(4) <= PRN(7);
    B2(5) <= PRN(13);
    B2(6) <= PRN(1);
    B2(7) <= PRN(3);
  
    -- process to change lfsr carry in on clock edge
    process(CLK,RESET) 
    begin 
        if rising_edge (CLK) then 
            Ci2 <= not Ci2;
        end if;
    end process;

    -- lfsr clock, reset
    CLK <= not CLK after Period/2;
    RESET <= '1', '0' after Period;

    -- lfsr enable, load
    LFSR_p: process
    begin
        DIN <= "0000000000000001";
        EN <='1';
        LD <='1';
        wait for 2 * PERIOD;
        LD <='0';
        wait for (65600 * PERIOD);
    end process LFSR_p;


end TEST;

configuration P4_ADDERTEST of TB_P4_ADDER is
    for TEST
      for all: P4_ADDER
        use entity WORK.P4_ADDER(STRUCTURAL);
      end for;
    end for;
end P4_ADDERTEST;
