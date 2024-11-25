library ieee;
use ieee.std_logic_1164.all;

use work.dlx_config.all;
use work.utils_package.all;
use work.types_amba4.all;
use work.tlm_interface_package.all;

entity axi_l1_cache is
port (
    i_clk  : in std_logic;
    i_nrst : in std_logic;

    -- MPU interface
    i_mpu_flags1   : in std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
    i_mpu_flags2   : in std_logic_vector(CFG_MPU_FL_TOTAL - 1 downto 0);
    o_mpu_addr1    : out std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    o_mpu_addr2    : out std_logic_vector(CFG_ADDR_BITS - 1 downto 0);

    -- interface with fetch stage
    i_fetch_to_l1_cache : in  fetch_to_l1_cache_t;
    o_l1_cache_to_fetch : out l1_cache_to_fetch_t;

    -- interface with memory stage
    i_memory_to_l1_cache : in memory_to_l1_cache_t;
    o_l1_cache_to_memory : out l1_cache_to_memory_t;

    -- AXI interface
    i_master_in  : in axi4_master_in_type;
    o_master_out : out axi4_master_out_type
);
end;

architecture rtl of axi_l1_cache is
    signal req_mem_ready : std_logic;
    signal req_mem_path : std_logic;
    signal req_mem_valid : std_logic;
    signal req_mem_type : std_logic_vector(REQ_MEM_TYPE_BITS - 1 downto 0);
    signal req_mem_addr : std_logic_vector(CFG_ADDR_BITS - 1 downto 0);
    signal req_mem_strob : std_logic_vector(L1CACHE_BYTES_PER_LINE - 1 downto 0);
    signal req_mem_data : std_logic_vector(L1CACHE_LINE_BITS - 1 downto 0);
    signal resp_mem_valid : std_logic;
    signal resp_mem_path : std_logic;
    signal resp_mem_data : std_logic_vector(L1CACHE_LINE_BITS - 1 downto 0);
    signal resp_mem_load_fault : std_logic;
    signal resp_mem_store_fault : std_logic;

    signal l1_master_i : axi4_l1_cache_in_type;
    signal l1_master_o : axi4_l1_cache_out_type;
begin

    -- AXI master wrapper
    l1_cache_axi_master_wrapper : entity work.l1_cache_axi_master_wrapper
        generic map(
            async_reset => false
        )
        port map(
            i_clk  => i_clk,
            i_nrst => i_nrst,

            i_req_mem_path         => req_mem_path,
            i_req_mem_valid        => req_mem_valid,
            i_req_mem_type         => req_mem_type,
            i_req_mem_addr         => req_mem_addr,
            i_req_mem_strob        => req_mem_strob,
            i_req_mem_data         => req_mem_data,
            o_req_mem_ready        => req_mem_ready,
            o_resp_mem_valid       => resp_mem_valid,
            o_resp_mem_path        => resp_mem_path,
            o_resp_mem_data        => resp_mem_data,
            o_resp_mem_load_fault  => resp_mem_load_fault,
            o_resp_mem_store_fault => resp_mem_store_fault,

            i_master_in  => l1_master_i,
            o_master_out => l1_master_o
        );

    -- split L1 line size read/write requests into appropriately sized AXI bursts for the system bus
    axi_burst_splitter_merger : entity work.axi_burst_splitter_merger
        generic map(
            async_reset => false
        )
        port map(
            i_clk        => i_clk,
            i_nrst       => i_nrst,

            i_l1_out     => l1_master_o,
            o_l1_in      => l1_master_i,

            i_master_in  => i_master_in,
            o_master_out => o_master_out
        );

    -- L1 cache
    l1_cache : entity work.l1_cache
        generic map(
            async_reset   => false,
            coherence_ena => false
        )
        port map(
            i_clk  => i_clk,
            i_nrst => i_nrst,
            -- Control (instruction) path:
            i_req_ctrl_valid       => i_fetch_to_l1_cache.read_request,
            i_req_ctrl_addr        => i_fetch_to_l1_cache.read_addr,
            o_req_ctrl_ready       => o_l1_cache_to_fetch.mmu_ready,
            o_resp_ctrl_valid      => o_l1_cache_to_fetch.read_data_valid,
            o_resp_ctrl_addr       => o_l1_cache_to_fetch.read_data_address,
            o_resp_ctrl_data       => o_l1_cache_to_fetch.read_data,
            o_resp_ctrl_load_fault => open,
            o_resp_ctrl_executable => open,
            i_resp_ctrl_ready      => i_fetch_to_l1_cache.fetch_ready,
            -- Data path:
            i_req_data_valid             => i_memory_to_l1_cache.request_valid,
            i_req_data_write             => i_memory_to_l1_cache.request_write,
            i_req_data_addr              => i_memory_to_l1_cache.address,
            i_req_data_wdata             => i_memory_to_l1_cache.write_data,
            i_req_data_wstrb             => i_memory_to_l1_cache.strobe,
            o_req_data_ready             => o_l1_cache_to_memory.mmu_ready,
            o_resp_data_valid            => o_l1_cache_to_memory.read_data_valid,
            o_resp_data_addr             => o_l1_cache_to_memory.read_data_address,
            o_resp_data_data             => o_l1_cache_to_memory.read_data,
            o_resp_data_store_fault_addr => open,
            o_resp_data_load_fault       => open,
            o_resp_data_store_fault      => open,
            o_resp_data_er_mpu_load      => open,
            o_resp_data_er_mpu_store     => open,
            i_resp_data_ready            => i_memory_to_l1_cache.memory_stage_ready,
            -- MPU interface
            i_mpu_flags1 => i_mpu_flags1,
            i_mpu_flags2 => i_mpu_flags2,
            o_mpu_addr1  => o_mpu_addr1,
            o_mpu_addr2  => o_mpu_addr2,
            -- Memory interface:
            i_req_mem_ready        => req_mem_ready,
            i_resp_mem_valid       => resp_mem_valid,
            i_resp_mem_path        => resp_mem_path,
            i_resp_mem_data        => resp_mem_data,
            i_resp_mem_load_fault  => resp_mem_load_fault,
            i_resp_mem_store_fault => resp_mem_store_fault,
            o_req_mem_path         => req_mem_path,
            o_req_mem_valid        => req_mem_valid,
            o_req_mem_type         => req_mem_type,
            o_req_mem_addr         => req_mem_addr,
            o_req_mem_strob        => req_mem_strob,
            o_req_mem_data         => req_mem_data,
            -- D$ Snoop interface
            i_req_snoop_valid  => '0',
            i_req_snoop_type   => (others => '0'),
            o_req_snoop_ready  => open,
            i_req_snoop_addr   => (others => '0'),
            i_resp_snoop_ready => '0',
            o_resp_snoop_valid => open,
            o_resp_snoop_data  => open,
            o_resp_snoop_flags => open,
            -- Debug signals:
            i_flush_address      => (others => '0'),
            i_flush_valid        => '0',
            i_data_flush_address => (others => '0'),
            i_data_flush_valid   => '0',
            o_data_flush_end     => open
        );
end;
