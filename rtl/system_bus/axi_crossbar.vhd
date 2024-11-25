--!
--! Copyright 2019 Sergey Khabarov, sergeykhbr@gmail.com
--!
--! Licensed under the Apache License, Version 2.0 (the "License");
--! you may not use this file except in compliance with the License.
--! You may obtain a copy of the License at
--!
--!     http://www.apache.org/licenses/LICENSE-2.0
--!
--! Unless required by applicable law or agreed to in writing, software
--! distributed under the License is distributed on an "AS IS" BASIS,
--! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--! See the License for the specific language governing permissions and
--! limitations under the License.
--!

library ieee;
use ieee.std_logic_1164.all;

use work.dlx_config.all;
use work.utils_package.all;
use work.types_amba4.all;

entity axi_crossbar is
  generic (
    async_reset : boolean
  );
  port (
    i_clk           : in std_logic;
    i_nrst          : in std_logic;
    
    i_slave_configs : in  bus0_xslv_cfg_vector;

    i_slave_outs    : in  bus0_xslv_out_vector;
    o_slave_ins     : out bus0_xslv_in_vector;

    i_master_outs   : in  bus0_xmst_out_vector;
    o_master_ins    : out bus0_xmst_in_vector
  );
end; 
 
architecture rtl of axi_crossbar is

  type nasti_master_out_vector_miss is array (0 to CFG_BUS0_XMST_TOTAL) 
       of axi4_master_out_type;

  type nasti_master_in_vector_miss is array (0 to CFG_BUS0_XMST_TOTAL) 
       of axi4_master_in_type;

  type nasti_slave_out_vector_miss is array (0 to CFG_BUS0_XSLV_TOTAL) 
       of axi4_slave_out_type;

  type nasti_slave_in_vector_miss is array (0 to CFG_BUS0_XSLV_TOTAL) 
       of axi4_slave_in_type;
       
  type reg_type is record
     r_midx : integer range 0 to CFG_BUS0_XMST_TOTAL;
     r_sidx : integer range 0 to CFG_BUS0_XSLV_TOTAL;
     w_midx : integer range 0 to CFG_BUS0_XMST_TOTAL;
     w_sidx : integer range 0 to CFG_BUS0_XSLV_TOTAL;
     b_midx : integer range 0 to CFG_BUS0_XMST_TOTAL;
     b_sidx : integer range 0 to CFG_BUS0_XSLV_TOTAL;
  end record;

  constant R_RESET : reg_type := (
      CFG_BUS0_XMST_TOTAL, CFG_BUS0_XSLV_TOTAL,
      CFG_BUS0_XMST_TOTAL, CFG_BUS0_XSLV_TOTAL,
      CFG_BUS0_XMST_TOTAL, CFG_BUS0_XSLV_TOTAL);

  signal rin, r : reg_type;

begin

  comblogic : process(i_nrst, i_slave_configs, i_master_outs, i_slave_outs, r)
    variable v : reg_type;
    variable ar_midx : integer range 0 to CFG_BUS0_XMST_TOTAL;
    variable aw_midx : integer range 0 to CFG_BUS0_XMST_TOTAL;
    variable ar_sidx : integer range 0 to CFG_BUS0_XSLV_TOTAL; -- +1 miss access
    variable aw_sidx : integer range 0 to CFG_BUS0_XSLV_TOTAL; -- +1 miss access
    variable vmsto : nasti_master_out_vector_miss;
    variable vmsti : nasti_master_in_vector_miss;
    variable vslvi : nasti_slave_in_vector_miss;
    variable vslvo : nasti_slave_out_vector_miss;
    variable aw_fire : std_logic;
    variable ar_fire : std_logic;
    variable w_fire : std_logic;
    variable w_busy : std_logic;
    variable r_fire : std_logic;
    variable r_busy : std_logic;
    variable b_fire : std_logic;
    variable b_busy : std_logic;

  begin

    v := r;

    for m in 0 to CFG_BUS0_XMST_TOTAL-1 loop
       vmsto(m) := i_master_outs(m);
       vmsti(m) := axi4_master_in_none;
    end loop;
    vmsto(CFG_BUS0_XMST_TOTAL) := axi4_master_out_none;
    vmsti(CFG_BUS0_XMST_TOTAL) := axi4_master_in_none;

    for s in 0 to CFG_BUS0_XSLV_TOTAL-1 loop
       vslvo(s) := i_slave_outs(s);
       vslvi(s) := axi4_slave_in_none;
    end loop;

    vslvi(CFG_BUS0_XSLV_TOTAL) := axi4_slave_in_none;

    ar_midx := CFG_BUS0_XMST_TOTAL;
    aw_midx := CFG_BUS0_XMST_TOTAL;
    ar_sidx := CFG_BUS0_XSLV_TOTAL;
    aw_sidx := CFG_BUS0_XSLV_TOTAL;

    -- select master bus:
    for m in 0 to CFG_BUS0_XMST_TOTAL-1 loop
        if i_master_outs(m).ar_valid = '1' then
            ar_midx := m;
        end if;
        if i_master_outs(m).aw_valid = '1' then
            aw_midx := m;
        end if;
    end loop;

    -- select slave interface
    for s in 0 to CFG_BUS0_XSLV_TOTAL-1 loop
        if i_slave_configs(s).xmask /= X"00000" and
           (vmsto(ar_midx).ar_bits.addr(CFG_BUS0_ADDR_BITS-1 downto 12) 
            and i_slave_configs(s).xmask) = i_slave_configs(s).xaddr then
            ar_sidx := s;
        end if;
        if i_slave_configs(s).xmask /= X"00000" and
           (vmsto(aw_midx).aw_bits.addr(CFG_BUS0_ADDR_BITS-1 downto 12)
            and i_slave_configs(s).xmask) = i_slave_configs(s).xaddr then
            aw_sidx := s;
        end if;
    end loop;

    -- Read Channel:
    ar_fire := vmsto(ar_midx).ar_valid and vslvo(ar_sidx).ar_ready;
    r_fire := vmsto(r.r_midx).r_ready and vslvo(r.r_sidx).r_valid and vslvo(r.r_sidx).r_last;
    -- Write channel:
    aw_fire := vmsto(aw_midx).aw_valid and vslvo(aw_sidx).aw_ready;
    w_fire := vmsto(r.w_midx).w_valid and vmsto(r.w_midx).w_last and vslvo(r.w_sidx).w_ready;
    -- Write confirm channel
    b_fire := vmsto(r.b_midx).b_ready and vslvo(r.b_sidx).b_valid;

    r_busy := '0';
    if r.r_sidx /= CFG_BUS0_XSLV_TOTAL and r_fire = '0' then
        r_busy := '1';
    end if;

    w_busy := '0';
    if (r.w_sidx /= CFG_BUS0_XSLV_TOTAL and w_fire = '0') 
       or (r.b_sidx /= CFG_BUS0_XSLV_TOTAL and b_fire = '0') then
        w_busy := '1';
    end if;

    b_busy := '0';
    if (r.b_sidx /= CFG_BUS0_XSLV_TOTAL and b_fire = '0')  then
        b_busy := '1';
    end if;

    if ar_fire = '1' and r_busy = '0' then
        v.r_sidx := ar_sidx;
        v.r_midx := ar_midx;
    elsif r_fire = '1' then
        v.r_sidx := CFG_BUS0_XSLV_TOTAL;
        v.r_midx := CFG_BUS0_XMST_TOTAL;
    end if;

    if aw_fire = '1' and w_busy = '0' then
        v.w_sidx := aw_sidx;
        v.w_midx := aw_midx;
    elsif w_fire = '1' and b_busy = '0' then
        v.w_sidx := CFG_BUS0_XSLV_TOTAL;
        v.w_midx := CFG_BUS0_XMST_TOTAL;
    end if;

    if w_fire = '1' and b_busy = '0' then
        v.b_sidx := r.w_sidx;
        v.b_midx := r.w_midx;
    elsif b_fire = '1' then
        v.b_sidx := CFG_BUS0_XSLV_TOTAL;
        v.b_midx := CFG_BUS0_XMST_TOTAL;
    end if;


    vmsti(ar_midx).ar_ready := vslvo(ar_sidx).ar_ready and not r_busy;
    vslvi(ar_sidx).ar_valid := vmsto(ar_midx).ar_valid and not r_busy;
    vslvi(ar_sidx).ar_bits  := vmsto(ar_midx).ar_bits;
    vslvi(ar_sidx).ar_id    := vmsto(ar_midx).ar_id;
    vslvi(ar_sidx).ar_user  := vmsto(ar_midx).ar_user;

    vmsti(r.r_midx).r_valid := vslvo(r.r_sidx).r_valid;
    vmsti(r.r_midx).r_resp  := vslvo(r.r_sidx).r_resp;
    vmsti(r.r_midx).r_data  := vslvo(r.r_sidx).r_data;
    vmsti(r.r_midx).r_last  := vslvo(r.r_sidx).r_last;
    vmsti(r.r_midx).r_id    := vslvo(r.r_sidx).r_id;
    vmsti(r.r_midx).r_user  := vslvo(r.r_sidx).r_user;
    vslvi(r.r_sidx).r_ready := vmsto(r.r_midx).r_ready;

    vmsti(aw_midx).aw_ready := vslvo(aw_sidx).aw_ready and not w_busy;
    vslvi(aw_sidx).aw_valid := vmsto(aw_midx).aw_valid and not w_busy;
    vslvi(aw_sidx).aw_bits  := vmsto(aw_midx).aw_bits;
    vslvi(aw_sidx).aw_id    := vmsto(aw_midx).aw_id;
    vslvi(aw_sidx).aw_user  := vmsto(aw_midx).aw_user;

    vmsti(r.w_midx).w_ready := vslvo(r.w_sidx).w_ready and not b_busy;
    vslvi(r.w_sidx).w_valid := vmsto(r.w_midx).w_valid and not b_busy;
    vslvi(r.w_sidx).w_data := vmsto(r.w_midx).w_data;
    vslvi(r.w_sidx).w_last := vmsto(r.w_midx).w_last;
    vslvi(r.w_sidx).w_strb := vmsto(r.w_midx).w_strb;
    vslvi(r.w_sidx).w_user := vmsto(r.w_midx).w_user;

    vmsti(r.b_midx).b_valid := vslvo(r.b_sidx).b_valid;
    vmsti(r.b_midx).b_resp := vslvo(r.b_sidx).b_resp;
    vmsti(r.b_midx).b_id := vslvo(r.b_sidx).b_id;
    vmsti(r.b_midx).b_user := vslvo(r.b_sidx).b_user;
    vslvi(r.b_sidx).b_ready := vmsto(r.b_midx).b_ready;

    if not async_reset and i_nrst = '0' then
        v := R_RESET;
    end if;
 
    rin <= v;

    for m in 0 to CFG_BUS0_XMST_TOTAL-1 loop
       o_master_ins(m) <= vmsti(m);
    end loop;
    for s in 0 to CFG_BUS0_XSLV_TOTAL-1 loop
       o_slave_ins(s) <= vslvi(s);
    end loop;

  end process;

  regs : process(i_clk, i_nrst)
  begin 
     if async_reset and i_nrst = '0' then
         r <= R_RESET;
     elsif rising_edge(i_clk) then 
         r <= rin;
     end if; 
  end process;
end;
