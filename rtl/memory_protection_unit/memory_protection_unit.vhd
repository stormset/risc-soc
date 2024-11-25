--!
--! Copyright 2019 Sergey Khabarov, sergeykhbr@gmail.com
--!
--! Licensed under the Apache License, Version 2.0 (the "License");
--! you may not use this file except in compliance with the License.
--! You may obtain a copy of the License at
--!
--!         http://www.apache.org/licenses/LICENSE-2.0
--!
--! Unless required by applicable law or agreed to in writing, software
--! distributed under the License is distributed on an "AS IS" BASIS,
--! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--! See the License for the specific language governing permissions and
--! limitations under the License.
--!

library ieee;
use ieee.std_logic_1164.all;

use work.utils_package.all;
use work.dlx_config.all;

-- memory protection unit with 2 lookup ports
entity memory_protection_unit is
port (
    i_clk    : in  std_logic;
    i_nrst   : in  std_logic;
    i_addr1  : in  std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    i_addr2  : in  std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    o_flags1 : out std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
    o_flags2 : out std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0)
);
end;

architecture rtl of memory_protection_unit is
    type mpu_table_item_t is record
        addr  : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        mask  : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
        flags : std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
    end record;

    type mpu_tbl_type is array (0 to CFG_MPU_TBL_SIZE - 1) of mpu_table_item_t;

    signal tbl      : mpu_tbl_type;
    signal tbl_next : mpu_tbl_type;
begin
    comb : process (all)
        variable v_flags1 : std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
        variable v_flags2 : std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
    begin
        v_flags1 := (others => '1');
        v_flags2 := (others => '1');

        -- lookup matching entry based on input address'
        for i in 0 to CFG_MPU_TBL_SIZE - 1 loop
            -- lookup for port 1
            if tbl(i).addr = (i_addr1 and tbl(i).mask) then
                if tbl(i).flags(CFG_MPU_FL_ENA) = '1' then
                    v_flags1 := tbl(i).flags;
                end if;
            end if;

            -- lookup for port 2
            if tbl(i).addr = (i_addr2 and tbl(i).mask) then
                if tbl(i).flags(CFG_MPU_FL_ENA) = '1' then
                    v_flags2 := tbl(i).flags;
                end if;
            end if;
        end loop;

        o_flags1 <= v_flags1;
        o_flags2 <= v_flags2;
    end process;
    
    regs : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_nrst = '0' then
                -- static configuration (MPU should be configurable through CSR registers in the future)

                for i in 0 to CFG_MPU_TBL_SIZE - 1 loop
                    tbl(i).flags <= (others => '0');
                    tbl(i).addr  <= (others => '0');
                    tbl(i).mask  <= (others => '1');
                end loop;

                -- All address below 0x80000000 are executable and cached
                tbl(0).addr(31 downto 0)          <= X"00000000";
                tbl(0).mask(31 downto 0)          <= X"80000000";
                tbl(0).flags(CFG_MPU_FL_ENA)      <= '1';
                tbl(0).flags(CFG_MPU_FL_CACHABLE) <= '1';
                tbl(0).flags(CFG_MPU_FL_EXEC)     <= '1';
                tbl(0).flags(CFG_MPU_FL_RD)       <= '1';
                tbl(0).flags(CFG_MPU_FL_WR)       <= '1';

                -- All address above 0x80000000 are uncached (IO devices in the future)
                tbl(1).addr(31 downto 0)          <= X"80000000";
                tbl(1).mask(31 downto 0)          <= X"80000000";
                tbl(1).flags(CFG_MPU_FL_ENA)      <= '1';
                tbl(1).flags(CFG_MPU_FL_CACHABLE) <= '0';
                tbl(1).flags(CFG_MPU_FL_EXEC)     <= '1';
                tbl(1).flags(CFG_MPU_FL_RD)       <= '1';
                tbl(1).flags(CFG_MPU_FL_WR)       <= '1';
            else
                tbl <= tbl_next;
            end if;
        end if;
    end process;
end;
