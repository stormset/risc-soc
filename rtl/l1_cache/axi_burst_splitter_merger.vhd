--!
--! Copyright 2020 Sergey Khabarov, sergeykhbr@gmail.com
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
use work.tlm_interface_package.all;


-- splits/merges cache line size read/write requests into an AXI burst
entity axi_burst_splitter_merger is
    generic (
        async_reset : boolean
    );
    port (
        i_clk        : in std_logic;
        i_nrst       : in std_logic;
        i_l1_out     : in axi4_l1_cache_out_type;
        o_l1_in      : out axi4_l1_cache_in_type;
        i_master_in  : in axi4_master_in_type;
        o_master_out : out axi4_master_out_type
    );
end;

architecture rtl of axi_burst_splitter_merger is

    -- TODO as generic parameters
    constant linew : integer := 256;--L1CACHE_LINE_BITS;
    constant busw : integer := CFG_BUS0_DATA_BITS;

    constant lineb : integer := linew / 8;
    constant busb : integer := busw / 8;

    constant SERDES_BURST_LEN : integer := lineb / busb;

    type state_type is (Idle, Read, Write);

    type RegistersType is record
        state : state_type;
        req_len : std_logic_vector(7 downto 0);
        b_wait : std_logic;
        cacheline : std_logic_vector(linew - 1 downto 0);
        wstrb : std_logic_vector(lineb - 1 downto 0);
        rmux : std_logic_vector(SERDES_BURST_LEN - 1 downto 0);
    end record;

    constant R_RESET : RegistersType := (
        idle, X"00", '0', (others => '0'), (others => '0'), (others => '0')
    );

    signal r, rin : RegistersType;

    function size2len(size : std_logic_vector)
        return std_logic_vector is
        variable len : std_logic_vector(7 downto 0);
    begin
        case size(2 downto 0) is
            when "100" => len := X"01";
            when "101" => len := X"07";
            when "110" => len := X"0F";
            when "111" => len := X"17";
            when others => len := X"00";
        end case;
        return len;
    end function size2len;

begin
    comb : process (i_nrst, i_l1_out, i_master_in, r)
        variable v : RegistersType;
        variable v_req_mem_ready : std_logic;
        variable vb_line_o : std_logic_vector(linew - 1 downto 0);
        variable v_r_valid : std_logic;
        variable v_w_valid : std_logic;
        variable v_w_last : std_logic;
        variable v_w_ready : std_logic;
        variable vb_len : std_logic_vector(7 downto 0);
        variable vb_aw_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
        variable vb_ar_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    begin

        v := r;

        v_req_mem_ready := '0';
        v_r_valid := '0';
        v_w_valid := '0';
        v_w_last := '0';
        v_w_ready := '0';
        vb_len := (others => '0');
        vb_aw_id := (others => '0');
        vb_ar_id := (others => '0');

        vb_aw_id(CFG_CPU_ID_BITS - 1 downto 0) := (others => '0');
        vb_ar_id(CFG_CPU_ID_BITS - 1 downto 0) := (others => '0');

        vb_line_o := r.cacheline;

        for i in 0 to SERDES_BURST_LEN - 1 loop
            if r.rmux(i) = '1' then
                vb_line_o((i + 1) * busw - 1 downto i * busw) := i_master_in.r_data;
            end if;
        end loop;

        if i_l1_out.b_ready = '1' then
            v.b_wait := '0';
        end if;
        case r.state is
            when Idle =>
                v_req_mem_ready := '1';

            when Read =>
                if i_master_in.r_valid = '1' then
                    v.cacheline := vb_line_o;
                    v.rmux := r.rmux(SERDES_BURST_LEN - 2 downto 0) & '0';
                    if r.req_len = X"00" then
                        v_r_valid := '1';
                        v_req_mem_ready := '1';
                    else
                        v.req_len := r.req_len - 1;
                    end if;
                end if;

            when Write =>
                v_w_valid := '1';
                if r.req_len = X"00" then
                    v_w_last := '1';
                end if;
                if i_master_in.w_ready = '1' then
                    v.cacheline(linew - 1 downto linew - busw) := (others => '0');
                    v.cacheline(linew - busw - 1 downto 0) := r.cacheline(linew - 1 downto busw);
                    v.wstrb(lineb - 1 downto lineb - busb) := (others => '0');
                    v.wstrb(lineb - busb - 1 downto 0) := r.wstrb(lineb - 1 downto busb);
                    if r.req_len = X"00" then
                        v_w_ready := '1';
                        v.b_wait := '1';
                        v_req_mem_ready := '1';
                    else
                        v.req_len := r.req_len - 1;
                    end if;
                end if;

            when others =>
        end case;

        if v_req_mem_ready = '1' then
            if (i_l1_out.ar_valid and i_master_in.ar_ready) = '1' then
                v.state := Read;
                v.rmux := conv_std_logic_vector(1, SERDES_BURST_LEN);
                vb_len := size2len(i_l1_out.ar_bits.size);
            elsif (i_l1_out.aw_valid and i_master_in.aw_ready) = '1' then
                v.cacheline := i_l1_out.w_data;
                v.wstrb := i_l1_out.w_strb;
                v.state := Write;
                vb_len := size2len(i_l1_out.aw_bits.size);
            else
                v.state := Idle;
            end if;
            v.req_len := vb_len;
        end if;
        if not async_reset and i_nrst = '0' then
            v := R_RESET;
        end if;

        o_master_out.aw_valid <= i_l1_out.aw_valid;
        o_master_out.aw_bits.addr <= i_l1_out.aw_bits.addr;
        o_master_out.aw_bits.len <= vb_len; -- burst len = len[7:0] + 1
        o_master_out.aw_bits.size <= "010"; -- 0=1B; 1=2B; 2=4B; 3=8B; ...
        o_master_out.aw_bits.burst <= "01"; -- 00=FIXED; 01=INCR; 10=WRAP; 11=reserved
        o_master_out.aw_bits.lock <= i_l1_out.aw_bits.lock;
        o_master_out.aw_bits.cache <= i_l1_out.aw_bits.cache;
        o_master_out.aw_bits.prot <= i_l1_out.aw_bits.prot;
        o_master_out.aw_bits.qos <= i_l1_out.aw_bits.qos;
        o_master_out.aw_bits.region <= i_l1_out.aw_bits.region;
        o_master_out.aw_id <= vb_aw_id;
        o_master_out.aw_user <= (others => '0');
        o_master_out.w_valid <= v_w_valid;
        o_master_out.w_last <= v_w_last;
        o_master_out.w_data <= r.cacheline(busw - 1 downto 0);
        o_master_out.w_strb <= r.wstrb(busb - 1 downto 0);
        o_master_out.w_user <= (others => '0');
        o_master_out.b_ready <= i_l1_out.b_ready;
        o_master_out.ar_valid <= i_l1_out.ar_valid;
        o_master_out.ar_bits.addr <= i_l1_out.ar_bits.addr;
        o_master_out.ar_bits.len <= vb_len; -- burst len = len[7:0] + 1
        o_master_out.ar_bits.size <= "010"; -- 0=1B; 1=2B; 2=4B; 3=8B; ...
        o_master_out.ar_bits.burst <= "01"; -- 00=FIXED; 01=INCR; 10=WRAP; 11=reserved
        o_master_out.ar_bits.lock <= i_l1_out.ar_bits.lock;
        o_master_out.ar_bits.cache <= i_l1_out.ar_bits.cache;
        o_master_out.ar_bits.prot <= i_l1_out.ar_bits.prot;
        o_master_out.ar_bits.qos <= i_l1_out.ar_bits.qos;
        o_master_out.ar_bits.region <= i_l1_out.ar_bits.region;
        o_master_out.ar_id <= vb_ar_id;
        o_master_out.ar_user <= (others => '0');
        o_master_out.r_ready <= i_l1_out.r_ready;

        o_l1_in.aw_ready <= i_master_in.aw_ready;
        o_l1_in.w_ready <= v_w_ready;
        o_l1_in.b_valid <= i_master_in.b_valid and r.b_wait;
        o_l1_in.b_resp <= i_master_in.b_resp;
        o_l1_in.ar_ready <= i_master_in.ar_ready;
        o_l1_in.r_valid <= v_r_valid;
        o_l1_in.r_resp <= "00" & i_master_in.r_resp;
        o_l1_in.r_data <= vb_line_o;
        o_l1_in.r_last <= v_r_valid;

        rin <= v;
    end process;

    -- registers:
    regs : process (i_clk, i_nrst)
    begin
        if async_reset and i_nrst = '0' then
            r <= R_RESET;
        elsif rising_edge(i_clk) then
            r <= rin;
        end if;
    end process;

end;
