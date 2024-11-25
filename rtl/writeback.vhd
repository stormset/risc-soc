library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.tlm_interface_package.all;
use work.control_word_package.all;

entity writeback is
    generic(
        NBIT : integer := 32
    );
    port(
        i_clk                 : in  std_logic;
        i_nrst                : in  std_logic;
        i_memory_to_writeback : in  memory_to_writeback_t;
        i_control             : in  WB_control_word_t;
        i_hazard_control      : in  WB_hazard_control_t;
        o_writeback_to_rf     : out writeback_to_rf_t
    );
end writeback;

architecture rtl of writeback is
begin
    -- register file write enable
    o_writeback_to_rf.write_enable <= i_control.rf_write_enable;

    -- register file write address
    o_writeback_to_rf.write_address <= i_memory_to_writeback.rd_address;

    -- mux for selecting writeback value
    writeback_value_selector: process (all)
    begin
        case i_control.writeback_selection is
            when alu_out =>
                o_writeback_to_rf.write_data <= i_memory_to_writeback.execution_unit_out;
            when memory_out =>
                o_writeback_to_rf.write_data <= i_memory_to_writeback.memory_out;
            when npc =>
                o_writeback_to_rf.write_data <= i_memory_to_writeback.npc;
        end case;
    end process writeback_value_selector;
end;
