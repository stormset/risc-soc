library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.utils_package.all;

package dlx_config is

    -- bit width of the datapath
    constant CFG_ADDR_BITS             : integer := 32;

    -- number of general-purpose registers
    constant CFG_N_GP_REGS             : integer := 32;
    constant CFG_RF_ADDR_WIDTH         : integer := log2(CFG_N_GP_REGS);

    -- reset address (initial PC value)
    constant CFG_RESET_ADDRESS         : std_logic_vector(CFG_ADDR_BITS-1 downto 0) := X"00000000";

    -- address of link register inside register file
    constant CFG_LINK_REGISTER_ADDRESS : std_logic_vector := std_logic_vector(to_unsigned(CFG_N_GP_REGS-1, CFG_RF_ADDR_WIDTH));

    -- number of sets in the cache
    constant CFG_BTB_NSETS             : integer := 8;

    -- number of cache lines in a set
    constant CFG_BTB_NWAYS             : integer := 4;

    -- sparsity of the sklansky tree    
    constant CFG_SKLANSKY_ADDER_BIT_PER_BLOCK : integer := 4;

    -- CPU (core) id field size for AXI transactions
    constant CFG_CPU_ID_BITS   : integer := 1;

    -- instruction cache config:
    constant CFG_ILOG2_BYTES_PER_LINE : integer := 5;
    constant CFG_ILOG2_LINES_PER_WAY  : integer := 7;
    constant CFG_ILOG2_NWAYS          : integer := 2;
    constant ICACHE_BYTES_PER_LINE    : integer := 2**CFG_ILOG2_BYTES_PER_LINE;
    constant ICACHE_LINES_PER_WAY     : integer := 2**CFG_ILOG2_LINES_PER_WAY;
    constant ICACHE_WAYS              : integer := 2**CFG_ILOG2_NWAYS;
    constant ICACHE_LINE_BITS         : integer := 8*ICACHE_BYTES_PER_LINE;
    constant ITAG_FL_TOTAL            : integer := 1;

    -- data cache config:
    constant CFG_DLOG2_BYTES_PER_LINE : integer := 5;
    constant CFG_DLOG2_LINES_PER_WAY  : integer := 7;
    constant CFG_DLOG2_NWAYS          : integer := 2;
    constant DCACHE_BYTES_PER_LINE    : integer := 2**CFG_DLOG2_BYTES_PER_LINE;
    constant DCACHE_LINES_PER_WAY     : integer := 2**CFG_DLOG2_LINES_PER_WAY;
    constant DCACHE_WAYS              : integer := 2**CFG_DLOG2_NWAYS;
    constant DCACHE_LINE_BITS         : integer := 8*DCACHE_BYTES_PER_LINE;  
    constant DCACHE_SIZE_BYTES        : integer := DCACHE_WAYS * DCACHE_LINES_PER_WAY * DCACHE_BYTES_PER_LINE;
    constant TAG_FL_VALID             : integer := 0;
    constant DTAG_FL_DIRTY            : integer := 1;
    constant DTAG_FL_SHARED           : integer := 2;
    constant DTAG_FL_TOTAL            : integer := 3;

    -- derived constants to calculate AXI transaction burst parameters
    constant L1CACHE_BYTES_PER_LINE : integer := DCACHE_BYTES_PER_LINE;
    constant L1CACHE_LINE_BITS      : integer := 8*DCACHE_BYTES_PER_LINE;

    -- common L1 cache parameters
    constant SNOOP_REQ_TYPE_READDATA   : integer := 0;   -- 0 = check flags ; 1 = data transfer
    constant SNOOP_REQ_TYPE_READCLEAN  : integer := 1;   -- 0 = do nothing  ; 1 = read and invalidate line
    constant SNOOP_REQ_TYPE_BITS       : integer := 2;
    constant REQ_MEM_TYPE_BITS         : integer := 3;
    constant REQ_MEM_TYPE_WRITE        : integer := 0;
    constant REQ_MEM_TYPE_CACHED       : integer := 1;
    constant REQ_MEM_TYPE_UNIQUE       : integer := 2;
    constant READNOSNOOP               : std_logic_vector := "000";
    constant READSHARED                : std_logic_vector := "010";
    constant READMAKEUNIQUE            : std_logic_vector := "110";
    constant WRITENOSNOOP              : std_logic_vector := "001";
    constant WRITELINEUNIQUE           : std_logic_vector := "111";
    constant WRITEBACK                 : std_logic_vector := "011";

    -- memory protection unit parameters
    constant CFG_MPU_TBL_WIDTH   : integer := 2;
    constant CFG_MPU_TBL_SIZE    : integer := 2**CFG_MPU_TBL_WIDTH;
    constant CFG_MPU_FL_WR       : integer := 0;
    constant CFG_MPU_FL_RD       : integer := 1;
    constant CFG_MPU_FL_EXEC     : integer := 2;
    constant CFG_MPU_FL_CACHABLE : integer := 3;
    constant CFG_MPU_FL_ENA      : integer := 4;
    constant CFG_MPU_FL_TOTAL    : integer := 5;

    -- system bus configuration
    constant CFG_BUS0_ADDR_BITS     : integer := 32;
    constant CFG_BUS0_DATA_BITS     : integer := 32;
    constant CFG_BUS0_DATA_BYTES    : integer := CFG_BUS0_DATA_BITS/8;
    constant CFG_BUS0_ADDR_OFFSET   : integer := log2(CFG_BUS0_DATA_BYTES); -- number of bits on address bus for one data transaction
    constant CFG_BUS0_CFG_ADDR_BITS : integer := CFG_BUS0_ADDR_BITS - 12;   -- number of address bits used for device addressing (12 -> minimum 4 KB address space per device)
    constant CFG_BUS0_ALIGN_BYTES   : integer := 4;                         -- global alignment
    constant CFG_BUS0_WORDS_ON_BUS  : integer := CFG_BUS0_DATA_BYTES/CFG_BUS0_ALIGN_BYTES;
    constant CFG_BUS0_ID_BITS       : integer := 5;  -- number of bits in transaction identifiers (ARID, AWID, ...)
    constant CFG_BUS0_USER_BITS     : integer := 1;  -- number of user bits
    constant CFG_BUS0_XMST_TOTAL    : integer := 1;  -- number of masters on bus #0
    constant CFG_BUS0_XSLV_TOTAL    : integer := 1;  -- number of slaves on bus #0

end package dlx_config;
