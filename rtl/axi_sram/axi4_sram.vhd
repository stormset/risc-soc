library ieee;
use ieee.std_logic_1164.all;

use work.dlx_config.all;
use work.utils_package.all;
use work.types_amba4.all;

entity axi4_sram is
    generic (
        XADDR         : integer;
        XMASK         : integer;
        ADDRESS_WIDTH : integer;
        INIT_FILE     : string
    );
    port (
        i_clk          : in std_logic;
        i_nrst         : in std_logic;
        o_slave_config : out axi4_slave_config_type;
        i_slave_in     : in axi4_slave_in_type;
        o_slave_out    : out axi4_slave_out_type
    );
end;

architecture rtl of axi4_sram is
    constant xconfig : axi4_slave_config_type := (
        descrtype => PNP_CFG_TYPE_SLAVE,
        descrsize => PNP_CFG_SLAVE_DESCR_BYTES,
        irq_idx   => conv_std_logic_vector(0, 8),
        XADDR     => conv_std_logic_vector(XADDR, CFG_BUS0_CFG_ADDR_BITS),
        XMASK     => conv_std_logic_vector(XMASK, CFG_BUS0_CFG_ADDR_BITS),
        vid       => (others => '0'),
        did       => (others => '0')
    );

    signal read_enable  : std_logic;
    signal write_enable : std_logic;
    signal read_address : global_addr_array_type;
    signal write_address: global_addr_array_type;
    signal write_strobe : std_logic_vector(CFG_BUS0_DATA_BYTES - 1 downto 0);
    signal write_data   : std_logic_vector(CFG_BUS0_DATA_BITS - 1 downto 0);
    signal read_data    : std_logic_vector(CFG_BUS0_DATA_BITS - 1 downto 0);
begin
    o_slave_config <= xconfig;

    -- AXI slave wrapper
    axi0 : entity work.axi4_slave_wrapper
        port map(
            i_clk   => i_clk,
            i_nrst  => i_nrst,
            i_xcfg  => xconfig,
            i_xslvi => i_slave_in,
            o_xslvo => o_slave_out,
            i_ready => '1',
            i_rdata => read_data,
            o_re    => read_enable,
            o_r32   => open,
            o_radr  => read_address,
            o_wadr  => write_address,
            o_we    => write_enable,
            o_wstrb => write_strobe,
            o_wdata => write_data
        );

    -- generate an SRAM block for each byte of the system bus (to provide byte-level write access)
    srams : for n in 0 to CFG_BUS0_DATA_BYTES - 1 generate
        signal address : std_logic_vector(ADDRESS_WIDTH - CFG_BUS0_ADDR_OFFSET - 1 downto 0);
        signal wr_ena : std_logic;
    begin
        wr_ena  <= write_enable and write_strobe(n);
        address <= write_address(n / CFG_BUS0_ALIGN_BYTES)(ADDRESS_WIDTH - 1 downto CFG_BUS0_ADDR_OFFSET) when write_enable = '1' else
                   read_address(n / CFG_BUS0_ALIGN_BYTES)(ADDRESS_WIDTH - 1 downto CFG_BUS0_ADDR_OFFSET);

        sram : entity work.sram_8
            generic map(
                ADDRESS_WIDTH     => ADDRESS_WIDTH - CFG_BUS0_ADDR_OFFSET,
                INIT_FILE         => INIT_FILE,
                INIT_FILE_OFFSET  => n
            )
            port map (
                i_clk     => i_clk,
                i_wr_en   => wr_ena,
                i_addr    => address,
                i_wr_data => write_data(8 * (n + 1) - 1 downto 8 * n),
                o_rd_data => read_data(8 * (n + 1) - 1 downto 8 * n)
            );
    end generate;
end;
