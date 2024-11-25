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
use ieee.numeric_std.all;

use work.dlx_config.all;
use work.utils_package.all;

package types_amba4 is
  --! @name   AXI Response values
  --! @brief  AMBA 4.0 specified response types from a slave device.
  --! @{

  --! @brief Normal access success. 
  --! @details Indicates that a normal access has been
  --! successful. Can also indicate an exclusive access has failed. 
  constant AXI_RESP_OKAY : std_logic_vector(1 downto 0) := "00";
  --! @brief Exclusive access okay. 
  --! @details Indicates that either the read or write
  --! portion of an exclusive access has been successful.
  constant AXI_RESP_EXOKAY : std_logic_vector(1 downto 0) := "01";
  --! @brief Slave error. 
  --! @details Used when the access has reached the slave successfully,
  --! but the slave wishes to return an error condition to the originating
  --! master.
  constant AXI_RESP_SLVERR : std_logic_vector(1 downto 0) := "10";
  --! @brief Decode error. 
  --! @details Generated, typically by an interconnect component,
  --! to indicate that there is no slave at the transaction address.
  constant AXI_RESP_DECERR : std_logic_vector(1 downto 0) := "11";
  --! @}

  --! @name   AXI burst request type.
  --! @brief  AMBA 4.0 specified burst operation request types.
  --! @{

  --! @brief Fixed address burst operation.
  --! @details The address is the same for every transfer in the burst 
  --!          (FIFO type)
  constant AXI_BURST_FIXED : std_logic_vector(1 downto 0) := "00";
  --! @brief Burst operation with address increment.
  --! @details The address for each transfer in the burst is an increment of
  --!        the address for the previous transfer. The increment value depends 
  --!        on the size of the transfer.
  constant AXI_BURST_INCR : std_logic_vector(1 downto 0) := "01";
  --! @brief Burst operation with address increment and wrapping.
  --! @details A wrapping burst is similar to an incrementing burst, except that
  --!          the address wraps around to a lower address if an upper address 
  --!          limit is reached
  constant AXI_BURST_WRAP : std_logic_vector(1 downto 0) := "10";
  --! @}
  
  --! @name Decoder of the transaction size.
  --! @{

  --! Burst length size decoder
  constant XSIZE_TOTAL : integer := 8;
  --! Definition of the AXI bytes converter.
  type xsize_type is array (0 to XSIZE_TOTAL - 1) of integer;
  --! Decoder of the transaction bytes from AXI format to Bytes.
  constant XSizeToBytes : xsize_type := (
    0 => 1,
    1 => 2,
    2 => 4,
    3 => 8,
    4 => 16,
    5 => 32,
    6 => 64,
    7 => 128
  );
  --! @}

  --! @name Plug'n'Play descriptor constants.
  --! @{
  --! Undefined type of the descriptor (empty device).
  constant PNP_CFG_TYPE_INVALID : std_logic_vector := "00";
  --! AXI slave device standard descriptor.
  constant PNP_CFG_TYPE_MASTER : std_logic_vector := "01";
  --! AXI master device standard descriptor.
  constant PNP_CFG_TYPE_SLAVE : std_logic_vector := "10";
  --! @brief Size in bytes of the standard slave descriptor..
  --! @details Firmware uses this value instead of sizeof(nasti_slave_config_type).
  constant PNP_CFG_SLAVE_DESCR_BYTES : std_logic_vector(7 downto 0) := X"10";
  --! @brief Size in bytes of the standard master descriptor.
  --! @details Firmware uses this value instead of sizeof(nasti_master_config_type).
  constant PNP_CFG_MASTER_DESCR_BYTES : std_logic_vector(7 downto 0) := X"08";
  --! @}
  --! @brief   Plug-n-play descriptor structure for slave device.
  --! @details Each slave device must generates this datatype output that
  --!          is connected directly to the 'pnp' slave module on system bus.
  type axi4_slave_config_type is record
    --! Descriptor size in bytes.
    descrsize : std_logic_vector(7 downto 0);
    --! Descriptor type.
    descrtype : std_logic_vector(1 downto 0);
    --! Descriptor size in bytes.
    irq_idx : std_logic_vector(7 downto 0);
    --! Base address value.
    xaddr : std_logic_vector(CFG_BUS0_CFG_ADDR_BITS - 1 downto 0);
    --! Maskable bits of the base address.
    xmask : std_logic_vector(CFG_BUS0_CFG_ADDR_BITS - 1 downto 0);
    --! Vendor ID.
    vid : std_logic_vector(15 downto 0);
    --! Device ID.
    did : std_logic_vector(15 downto 0);
  end record;

  --! @brief Default slave config value.
  --! @default This value corresponds to an empty device and often used
  --!          as assignment of outputs for the disabled device.
  constant axi4_slave_config_none : axi4_slave_config_type := (
    PNP_CFG_SLAVE_DESCR_BYTES, PNP_CFG_TYPE_SLAVE, (others => '0'),
    (others => '0'), (others => '0'), (others => '0'), (others => '0'));
  --! @brief   Plug-n-play descriptor structure for master device.
  --! @details Each master device must generates this datatype output that
  --!          is connected directly to the 'pnp' slave module on system bus.
  type axi4_master_config_type is record
    --! Descriptor size in bytes.
    descrsize : std_logic_vector(7 downto 0);
    --! Descriptor type.
    descrtype : std_logic_vector(1 downto 0);
    --! Vendor ID.
    vid : std_logic_vector(15 downto 0);
    --! Device ID.
    did : std_logic_vector(15 downto 0);
  end record;

  --! @brief Default master config value.
  constant axi4_master_config_none : axi4_master_config_type := (
    PNP_CFG_MASTER_DESCR_BYTES, PNP_CFG_TYPE_MASTER,
    (others => '0'), (others => '0'));

  constant ARCACHE_DEVICE_NON_BUFFERABLE : std_logic_vector(3 downto 0) := "0000";
  constant ARCACHE_WRBACK_READ_ALLOCATE : std_logic_vector(3 downto 0) := "1111";

  constant AWCACHE_DEVICE_NON_BUFFERABLE : std_logic_vector(3 downto 0) := "0000";
  constant AWCACHE_WRBACK_WRITE_ALLOCATE : std_logic_vector(3 downto 0) := "1111";

  -- see table C3-7 Permitted read address control signal combinations
  --
  --    read  |  cached  |  unique  |
  --     0    |    0     |    *     |    ReadNoSnoop
  --     0    |    1     |    0     |    ReadShared
  --     0    |    1     |    1     |    ReadMakeUnique
  constant ARSNOOP_READ_NO_SNOOP : std_logic_vector(3 downto 0) := "0000";
  constant ARSNOOP_READ_SHARED : std_logic_vector(3 downto 0) := "0001";
  constant ARSNOOP_READ_MAKE_UNIQUE : std_logic_vector(3 downto 0) := "1100";

  -- see table C3-8 Permitted read address control signal combinations
  --
  --   write  |  cached  |  unique  |
  --     1    |    0     |    *     |    WriteNoSnoop
  --     1    |    1     |    1     |    WriteLineUnique
  --     1    |    1     |    0     |    WriteBack
  constant AWSNOOP_WRITE_NO_SNOOP : std_logic_vector(2 downto 0) := "000";
  constant AWSNOOP_WRITE_LINE_UNIQUE : std_logic_vector(2 downto 0) := "001";
  constant AWSNOOP_WRITE_BACK : std_logic_vector(2 downto 0) := "011";

  -- see table C3-19
  constant AC_SNOOP_READ_UNIQUE : std_logic_vector(3 downto 0) := "0111";
  constant AC_SNOOP_MAKE_INVALID : std_logic_vector(3 downto 0) := "1101";
  --! @brief AMBA AXI4 compliant data structure.
  type axi4_metadata_type is record
    --! @brief Read address.
    --! @details The read address gives the address of the first transfer
    --!          in a read burst transaction.
    addr : std_logic_vector(CFG_BUS0_ADDR_BITS - 1 downto 0);
    --! @brief   Burst length.
    --! @details This signal indicates the exact number of transfers in 
    --!          a burst. This changes between AXI3 and AXI4. nastiXLenBits=8 so
    --!          this is an AXI4 implementation.
    --!              Burst_Length = len[7:0] + 1
    len : std_logic_vector(7 downto 0);
    --! @brief   Burst size.
    --! @details This signal indicates the size of each transfer 
    --!          in the burst: 0=1 byte; ..., 6=64 bytes; 7=128 bytes;
    size : std_logic_vector(2 downto 0);
    --! @brief   Read response.
    --! @details This signal indicates the status of the read transfer. 
    --! The responses are:
    --!      0b00 FIXED - In a fixed burst, the address is the same for every transfer 
    --!                  in the burst. Typically is used for FIFO.
    --!      0b01 INCR - Incrementing. In an incrementing burst, the address for each
    --!                  transfer in the burst is an increment of the address for the 
    --!                  previous transfer. The increment value depends on the size of 
    --!                  the transfer.
    --!      0b10 WRAP - A wrapping burst is similar to an incrementing burst, except 
    --!                  that the address wraps around to a lower address if an upper address 
    --!                  limit is reached.
    --!      0b11 resrved.
    burst : std_logic_vector(1 downto 0);
    --! @brief   Lock type.
    --! @details Not supported in AXI4.
    lock : std_logic;
    --! @brief   Memory type.
    --! @details See table for write and read transactions.
    cache : std_logic_vector(3 downto 0);
    --! @brief   Protection type.
    --! @details This signal indicates the privilege and security level 
    --!          of the transaction, and whether the transaction is a data access
    --!          or an instruction access:
    --!  [0] :   0 = Unpriviledge access
    --!          1 = Priviledge access
    --!  [1] :   0 = Secure access
    --!          1 = Non-secure access
    --!  [2] :   0 = Data access
    --!          1 = Instruction access
    prot : std_logic_vector(2 downto 0);
    --! @brief   Quality of Service, QoS. 
    --! @details QoS identifier sent for each read transaction. 
    --!          Implemented only in AXI4:
    --!              0b0000 - default value. Indicates that the interface is 
    --!                       not participating in any QoS scheme.
    qos : std_logic_vector(3 downto 0);
    --! @brief Region identifier.
    --! @details Permits a single physical interface on a slave to be used for 
    --!          multiple logical interfaces. Implemented only in AXI4. This is 
    --!          similar to the banks implementation in Leon3 without address 
    --!          decoding.
    region : std_logic_vector(3 downto 0);
  end record;

  --! @brief Empty metadata value.
  constant META_NONE : axi4_metadata_type := (
  (others => '0'), X"00", "000", AXI_BURST_INCR, '0', X"0", "000", "0000", "0000"
  );

  --! @brief Master device output signals
  type axi4_master_out_type is record
    --! Write Address channel:
    aw_valid : std_logic;
    --! metadata of the read channel.
    aw_bits : axi4_metadata_type;
    --! Write address ID. Identification tag used for a trasaction ordering.
    aw_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    --! Optional user defined signal in a write address channel.
    aw_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Write Data channel valid flag
    w_valid : std_logic;
    --! Write channel data value
    w_data : std_logic_vector(CFG_BUS0_DATA_BITS - 1 downto 0);
    --! Write Data channel last address in a burst marker.
    w_last : std_logic;
    --! Write Data channel strob signals selecting certain bytes.
    w_strb : std_logic_vector(CFG_BUS0_DATA_BYTES - 1 downto 0);
    --! Optional user defined signal in write channel.
    w_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Write Response channel accepted by master.
    b_ready : std_logic;
    --! Read Address Channel data valid.
    ar_valid : std_logic;
    --! Read Address channel metadata.
    ar_bits : axi4_metadata_type;
    --! Read address ID. Identification tag used for a trasaction ordering.
    ar_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    --! Optional user defined signal in read address channel.
    ar_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Read Data channel:
    r_ready : std_logic;
  end record;

  --! @brief   Master device empty value.
  --! @warning If the master is not connected to the vector then vector value
  --!          MUST BE initialized by this value.
  constant axi4_master_out_none : axi4_master_out_type := (
    '0', META_NONE, (others => '0'), (others => '0'),
    '0', (others => '0'), '0', (others => '0'), (others => '0'),
    '0', '0', META_NONE, (others => '0'), (others => '0'), '0');
  --! @brief Master device input signals.
  type axi4_master_in_type is record
    --! Write Address channel.
    aw_ready : std_logic;
    --! Write Data channel.
    w_ready : std_logic;
    --! Write Response channel:
    b_valid : std_logic;
    b_resp : std_logic_vector(1 downto 0);
    b_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    b_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Read Address Channel
    ar_ready : std_logic;
    --! Read valid.
    r_valid : std_logic;
    --! @brief Read response. 
    --! @details This signal indicates the status of the read transfer. 
    --!  The responses are:
    --!      0b00 OKAY - Normal access success. Indicates that a normal access has
    --!                  been successful. Can also indicate an exclusive access
    --!                  has failed.
    --!      0b01 EXOKAY - Exclusive access okay. Indicates that either the read or
    --!                  write portion of an exclusive access has been successful.
    --!      0b10 SLVERR - Slave error. Used when the access has reached the slave 
    --!                  successfully, but the slave wishes to return an error
    --!                  condition to the originating master.
    --!      0b11 DECERR - Decode error. Generated, typically by an interconnect 
    --!                  component, to indicate that there is no slave at the
    --!                  transaction address.
    r_resp : std_logic_vector(1 downto 0);
    --! Read data
    r_data : std_logic_vector(CFG_BUS0_DATA_BITS - 1 downto 0);
    --! @brief  Read last. 
    --! @details This signal indicates the last transfer in a read burst.
    r_last : std_logic;
    --! @brief Read ID tag.
    --! @details This signal is the identification tag for the read data
    --!          group of signals generated by the slave.
    r_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    --! @brief User signal. 
    --! @details Optional User-defined signal in the read channel. Supported 
    --!          only in AXI4.
    r_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
  end record;

  constant axi4_master_in_none : axi4_master_in_type := (
    '0', '0', '0', AXI_RESP_OKAY, (others => '0'), (others => '0'),
    '0', '0', AXI_RESP_OKAY, (others => '0'), '0', (others => '0'), (others => '0'));
  --! @brief Slave device AMBA AXI input signals.
  type axi4_slave_in_type is record
    --! Write Address channel:
    aw_valid : std_logic;
    aw_bits : axi4_metadata_type;
    aw_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    aw_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Write Data channel:
    w_valid : std_logic;
    w_data : std_logic_vector(CFG_BUS0_DATA_BITS - 1 downto 0);
    w_last : std_logic;
    w_strb : std_logic_vector(CFG_BUS0_DATA_BYTES - 1 downto 0);
    w_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Write Response channel:
    b_ready : std_logic;
    --! Read Address Channel:
    ar_valid : std_logic;
    ar_bits : axi4_metadata_type;
    ar_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    ar_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Read Data channel:
    r_ready : std_logic;
  end record;

  constant axi4_slave_in_none : axi4_slave_in_type := (
    '0', META_NONE, (others => '0'), (others => '0'), '0',
    (others => '0'), '0', (others => '0'), (others => '0'), '0', '0', META_NONE,
    (others => '0'), (others => '0'), '0');
  --! @brief Slave device AMBA AXI output signals.
  type axi4_slave_out_type is record
    --! Write Address channel:
    aw_ready : std_logic;
    --! Write Data channel:
    w_ready : std_logic;
    --! Write Response channel:
    b_valid : std_logic;
    b_resp : std_logic_vector(1 downto 0);
    b_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    b_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
    --! Read Address Channel
    ar_ready : std_logic;
    --! Read Data channel:
    r_valid : std_logic;
    --! @brief Read response.
    --! @details This signal indicates the status of the read transfer. 
    --!  The responses are:
    --!      0b00 OKAY - Normal access success. Indicates that a normal access has
    --!                  been successful. Can also indicate an exclusive access
    --!                  has failed.
    --!      0b01 EXOKAY - Exclusive access okay. Indicates that either the read or
    --!                  write portion of an exclusive access has been successful.
    --!      0b10 SLVERR - Slave error. Used when the access has reached the slave 
    --!                  successfully, but the slave wishes to return an error
    --!                  condition to the originating master.
    --!      0b11 DECERR - Decode error. Generated, typically by an interconnect 
    --!                  component, to indicate that there is no slave at the
    --!                  transaction address.
    r_resp : std_logic_vector(1 downto 0);
    --! Read data
    r_data : std_logic_vector(CFG_BUS0_DATA_BITS - 1 downto 0);
    --! Read last. This signal indicates the last transfer in a read burst.
    r_last : std_logic;
    --! @brief Read ID tag. 
    --! @details This signal is the identification tag for the read data
    --!           group of signals generated by the slave.
    r_id : std_logic_vector(CFG_BUS0_ID_BITS - 1 downto 0);
    --! @brief User signal. 
    --! @details Optinal User-defined signal in the read channel. Supported 
    --!          only in AXI4.
    r_user : std_logic_vector(CFG_BUS0_USER_BITS - 1 downto 0);
  end record;

  --! @brief Slave output signals connected to system bus.
  --! @details If the slave is not connected to the vector then vector value
  --! MUST BE initialized by this value.
  constant axi4_slave_out_none : axi4_slave_out_type := (
    '0', '0', '0', AXI_RESP_EXOKAY, (others => '0'), (others => '0'),
    '0', '0', AXI_RESP_EXOKAY, (others => '1'),
    '0', (others => '0'), (others => '0'));
  --! Array of addresses providing word aligned access.
  type global_addr_array_type is array (0 to CFG_BUS0_WORDS_ON_BUS - 1)
  of std_logic_vector(CFG_BUS0_ADDR_BITS - 1 downto 0);

  --! @brief Array type definitions for masters and slaves and their configurations for system bus #0.
  type bus0_xmst_in_vector is array (0 to CFG_BUS0_XMST_TOTAL-1) of types_amba4.axi4_master_in_type;
  type bus0_xmst_out_vector is array (0 to CFG_BUS0_XMST_TOTAL-1) of types_amba4.axi4_master_out_type;
  type bus0_xslv_cfg_vector is array (0 to CFG_BUS0_XSLV_TOTAL-1) of types_amba4.axi4_slave_config_type;
  type bus0_xslv_in_vector is array (0 to CFG_BUS0_XSLV_TOTAL-1) of types_amba4.axi4_slave_in_type;
  type bus0_xslv_out_vector is array (0 to CFG_BUS0_XSLV_TOTAL-1) of types_amba4.axi4_slave_out_type;

end; -- package declaration
