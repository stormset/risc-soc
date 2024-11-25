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
--! @brief     "River" CPU Top level with AXI4 interface.
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.dlx_config.all;
use work.types_amba4.all;
use work.tlm_interface_package.all;

entity l1_cache_axi_master_wrapper is 
    generic (
        async_reset : boolean
    );
    port (
        i_clk                  : in  std_logic;
        i_nrst                 : in  std_logic;

        i_req_mem_path         : in  std_logic;
        i_req_mem_valid        : in  std_logic;
        i_req_mem_type         : in  std_logic_vector(REQ_MEM_TYPE_BITS-1 downto 0);
        i_req_mem_addr         : in  std_logic_vector(CFG_ADDR_BITS-1 downto 0);
        i_req_mem_strob        : in  std_logic_vector(L1CACHE_BYTES_PER_LINE-1 downto 0);
        i_req_mem_data         : in  std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
        o_req_mem_ready        : out std_logic;
        o_resp_mem_valid       : out std_logic;
        o_resp_mem_path        : out std_logic;
        o_resp_mem_data        : out std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
        o_resp_mem_load_fault  : out std_logic;
        o_resp_mem_store_fault : out std_logic;        

        i_master_in            : in  axi4_l1_cache_in_type;
        o_master_out           : out axi4_l1_cache_out_type
    );
end;
 
architecture rtl of l1_cache_axi_master_wrapper is

  type state_type is (
      state_idle,
      state_ar,
      state_r,
      state_aw,
      state_w,
      state_b
  );

  type snoopstate_type is (
      snoop_idle,
      snoop_ac_wait_accept,
      snoop_cr,
      snoop_cr_wait_accept,
      snoop_cd,
      snoop_cd_wait_accept
  );

  type RegistersType is record
      state : state_type;
      req_addr : std_logic_vector(CFG_ADDR_BITS-1 downto 0);
      req_path : std_logic;
      req_cached : std_logic_vector(3 downto 0);
      req_wdata : std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
      req_wstrb : std_logic_vector(L1CACHE_BYTES_PER_LINE-1 downto 0);
      req_size : std_logic_vector(2 downto 0);
      req_prot : std_logic_vector(2 downto 0);
      req_ar_snoop : std_logic_vector(3 downto 0);
      req_aw_snoop : std_logic_vector(2 downto 0);
  end record;

  constant R_RESET : RegistersType := (
      state_idle,
      (others => '0'),    -- req_addr
      '0',                -- req_path
      (others => '0'),    -- req_cached
      (others => '0'),    -- req_wdata
      (others => '0'),    -- req_wstrb
      (others => '0'),    -- req_size
      (others => '0'),    -- req_prot
      (others => '0'),    -- req_ar_snoop
      (others => '0')     -- req_aw_snoop
  );

  signal r, rin : RegistersType;

  -- D$ Snoop interface
  signal req_snoop_valid_i : std_logic;
  signal req_snoop_type_i : std_logic_vector(SNOOP_REQ_TYPE_BITS-1 downto 0);
  signal req_snoop_ready_o : std_logic;
  signal req_snoop_addr_i : std_logic_vector(CFG_ADDR_BITS-1 downto 0);
  signal resp_snoop_ready_i : std_logic;
  signal resp_snoop_valid_o : std_logic;
  signal resp_snoop_data_o : std_logic_vector(L1CACHE_LINE_BITS-1 downto 0);
  signal resp_snoop_flags_o : std_logic_vector(DTAG_FL_TOTAL-1 downto 0);

begin
    comb : process (all)
        variable v : RegistersType;
        variable v_resp_mem_valid : std_logic;
        variable v_mem_er_load_fault : std_logic;
        variable v_mem_er_store_fault : std_logic;
        variable v_next_ready : std_logic;
        variable vmaster_out : axi4_l1_cache_out_type;
    begin
        v := r;

        v_resp_mem_valid := '0';
        v_mem_er_load_fault := '0';
        v_mem_er_store_fault := '0';
        v_next_ready := '0';

        vmaster_out := (
            '0', META_NONE,
            '0', (others=>'0'), '0', (others=>'0'),
            '0', '0', META_NONE, '0',
             "00", X"0", "00", "00", X"0", "00", '0', '0',
             "00000", '0', (others => '0'), '0', '0', '0');
        vmaster_out.ar_bits.burst := "01";  -- INCR (possible any value)
        vmaster_out.aw_bits.burst := "01";  -- INCR (possible any value)

        case r.state is
        when state_idle =>
            v_next_ready := '1';
            if i_req_mem_valid = '1' then
                v.req_path := i_req_mem_path;
                v.req_addr := i_req_mem_addr;
                if i_req_mem_type(REQ_MEM_TYPE_CACHED) = '1' then
                    v.req_size := "101";   -- 32 Bytes
                elsif i_req_mem_path = '1' then
                    v.req_size := "100";   -- 16 Bytes: Uncached Instruction
                else
                    v.req_size := "011";   -- 8 Bytes: Uncached Data
                end if;
                -- [0] 0=Unpriv/1=Priv;
                -- [1] 0=Secure/1=Non-secure;
                -- [2]  0=Data/1=Instruction
                v.req_prot := i_req_mem_path & "00";
                if i_req_mem_type(REQ_MEM_TYPE_WRITE) = '0' then
                    v.state := state_ar;
                    v.req_wdata := (others => '0');
                    v.req_wstrb := (others => '0');
                    if i_req_mem_type(REQ_MEM_TYPE_CACHED) = '1' then
                        v.req_cached := ARCACHE_WRBACK_READ_ALLOCATE;
                    else
                        v.req_cached := ARCACHE_DEVICE_NON_BUFFERABLE;
                    end if;
                else
                    v.state := state_aw;
                    v.req_wdata := i_req_mem_data;
                    v.req_wstrb := i_req_mem_strob;
                    if i_req_mem_type(REQ_MEM_TYPE_CACHED) = '1' then
                        v.req_cached := AWCACHE_WRBACK_WRITE_ALLOCATE;
                    else
                        v.req_cached := AWCACHE_DEVICE_NON_BUFFERABLE;
                    end if;
                end if;
            end if;

        when state_ar =>
            vmaster_out.ar_valid := '1';
            vmaster_out.ar_bits.addr := r.req_addr;
            vmaster_out.ar_bits.cache := r.req_cached;
            vmaster_out.ar_bits.size := r.req_size;
            vmaster_out.ar_bits.prot := r.req_prot;
            vmaster_out.ar_snoop := r.req_ar_snoop;
            if i_master_in.ar_ready = '1' then
                v.state := state_r;
            end if;
        when state_r =>
            vmaster_out.r_ready := '1';
            v_mem_er_load_fault := i_master_in.r_resp(1);
            v_resp_mem_valid := i_master_in.r_valid;
            -- r_valid and r_last always should be in the same time
            if i_master_in.r_valid = '1' and i_master_in.r_last = '1' then
                v.state := state_idle;
            end if;

        when state_aw =>
            vmaster_out.aw_valid := '1';
            vmaster_out.aw_bits.addr := r.req_addr;
            vmaster_out.aw_bits.cache := r.req_cached;
            vmaster_out.aw_bits.size := r.req_size;
            vmaster_out.aw_bits.prot := r.req_prot;

            -- axi lite to simplify L2-cache
            vmaster_out.w_valid := '1';
            vmaster_out.w_last := '1';
            vmaster_out.w_data := r.req_wdata;
            vmaster_out.w_strb := r.req_wstrb;
            if i_master_in.aw_ready = '1' then
                if i_master_in.w_ready = '1' then
                    v.state := state_b;
                else
                    v.state := state_w;
                end if;
            end if;
        when state_w =>
            -- Shoudln't get here because of Lite interface:
            vmaster_out.w_valid := '1';
            vmaster_out.w_last := '1';
            vmaster_out.w_data := r.req_wdata;
            vmaster_out.w_strb := r.req_wstrb;
            if i_master_in.w_ready = '1' then
                v.state := state_b;
            end if;
        when state_b =>
            vmaster_out.b_ready := '1';
            v_resp_mem_valid := i_master_in.b_valid;
            v_mem_er_store_fault := i_master_in.b_resp(1);
            if i_master_in.b_valid = '1' then
                v.state := state_idle;
            end if;
        when others =>  
        end case;

        if not async_reset and i_nrst = '0' then
            v := R_RESET;
        end if;


        o_master_out <= vmaster_out;

        o_req_mem_ready  <= v_next_ready;  
        o_resp_mem_valid <= v_resp_mem_valid;
        o_resp_mem_path  <= r.req_path;
        o_resp_mem_data  <= i_master_in.r_data;
        o_resp_mem_load_fault <= v_mem_er_load_fault;
        o_resp_mem_store_fault <= v_mem_er_store_fault;

        rin <= v;
    end process;

    -- registers:
    regs : process(i_clk, i_nrst)
    begin 
        if async_reset and i_nrst = '0' then
        r <= R_RESET;
        elsif rising_edge(i_clk) then 
        r <= rin;
        end if; 
    end process;
end;
