library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package control_word_package is
    -- fields of an instruction
    subtype opcode_range      is integer range 31 downto 26;
    subtype func_range        is integer range  5 downto 0;
    subtype rs1_range         is integer range 25 downto 21;
    subtype rs2_range         is integer range 20 downto 16;
    subtype imm_range         is integer range 15 downto 0;
    subtype rd_range          is integer range 15 downto 11;
    subtype jump_offset_range is integer range 25 downto 0;

    -- types to control datapath components
    type immediate_selection_t  is (signed_immediate, unsigned_immediate, signed_jump_offset);
    type rd_address_selection_t is (rd_i_type, rd_r_type, rd_jump_link_type);
    type operand_t              is (imm, reg);
    type branch_condition_t     is (never, always, equal_zero, not_equal_zero);
    type execution_unit_t       is (unit_alu, unit_multiplier);
    type alu_operation_t        is (op_add, op_sub, op_sll, op_srl, op_sra, op_rol, op_ror, op_and, op_or, op_xor,
                                    op_seq, op_sne, op_sgt, op_sgtu, op_sge, op_sgeu, op_slt, op_sltu, op_sle, op_sleu);
    type memory_data_type_t     is (type_unsigned, type_signed);
    type memory_data_size_t     is (byte, half_word, word);
    type writeback_selection_t  is (alu_out, memory_out, npc);
    type forward_selection_t    is (no_forward, alu_out_at_mem_forward, wb_forward, npc_at_exe_forward, npc_at_mem_forward);

    -- IF control signal
    type IF_hazard_control_t is record
        stall_PC : std_logic;
        stall    : std_logic;
        flush    : std_logic;
    end record IF_hazard_control_t;

    -- ID control signal
    type ID_control_word_t is record
        branch_target          : operand_t;
        immediate_selection    : immediate_selection_t;
        rd_address_selection   : rd_address_selection_t;
        branch_condition       : branch_condition_t;
    end record ID_control_word_t;

    type ID_hazard_control_t is record
        stall              : std_logic;
        flush              : std_logic;
        rs1_forwarding_sel : forward_selection_t;
        rs2_forwarding_sel : forward_selection_t;
    end record ID_hazard_control_t;

    -- EXE control signal
    type EXE_control_word_t is record
        is_branch           : std_logic;
        execution_unit      : execution_unit_t;
        second_operand_type : operand_t;
        alu_operation       : alu_operation_t;
    end record EXE_control_word_t;

    type EXE_hazard_control_t is record
        stall              : std_logic;
        flush              : std_logic;
        rs1_forwarding_sel : forward_selection_t;
        rs2_forwarding_sel : forward_selection_t;
    end record EXE_hazard_control_t;

    -- MEM control signal
    type MEM_control_word_t is record
        memory_read_enable  : std_logic;
        memory_write_enable : std_logic;
        memory_data_type    : memory_data_type_t;
        memory_data_size    : memory_data_size_t;
    end record MEM_control_word_t;

    type MEM_hazard_control_t is record
        stall           : std_logic;
        flush           : std_logic;
    end record MEM_hazard_control_t;

    -- WB control signal
    type WB_control_word_t is record
        rf_write_enable     : std_logic;
        writeback_selection : writeback_selection_t;
    end record WB_control_word_t;

    type WB_hazard_control_t is record
        stall           : std_logic;
        flush           : std_logic;
    end record WB_hazard_control_t;

    -- datapath control signals for the pipeline stages
    type control_word_t is record
        ID  : ID_control_word_t;
        EXE : EXE_control_word_t;
        MEM : MEM_control_word_t;
        WB  : WB_control_word_t;
    end record control_word_t;

    -- hazard control signals for the pipeline stages
    type hazard_control_t is record
        FE  : IF_hazard_control_t;
        ID  : ID_hazard_control_t;
        EXE : EXE_hazard_control_t;
        MEM : MEM_hazard_control_t;
        WB  : WB_hazard_control_t;
    end record hazard_control_t;

    -- control signals from control unit to the datapath
    type controls_t is record
        control_word   : control_word_t;
        hazard_control : hazard_control_t;
    end record controls_t;

    -- opcodes

    -- R-type instructions
    type func_t is (
        FUNC_00,       -- 0x00 (unused)
        FUNC_01,       -- 0x01 (unused)
        FUNC_02,       -- 0x02 (unused)
        FUNC_03,       -- 0x03 (unused)
        FUNC_SLL,      -- 0x04
        FUNC_05,       -- 0x05 (unused)
        FUNC_SRL,      -- 0x06
        FUNC_SRA,      -- 0x07
        FUNC_ROL,      -- 0x08
        FUNC_ROR,      -- 0x09
        FUNC_0A,       -- 0x0A (unused)
        FUNC_0B,       -- 0x0B (unused)
        FUNC_0C,       -- 0x0C (unused)
        FUNC_0D,       -- 0x0D (unused)
        FUNC_0E,       -- 0x0E (unused)
        FUNC_0F,       -- 0x0F (unused)
        FUNC_10,       -- 0x10 (unused)
        FUNC_11,       -- 0x11 (unused)
        FUNC_12,       -- 0x12 (unused)
        FUNC_13,       -- 0x13 (unused)
        FUNC_14,       -- 0x14 (unused)
        FUNC_15,       -- 0x15 (unused)
        FUNC_16,       -- 0x16 (unused)
        FUNC_17,       -- 0x17 (unused)
        FUNC_18,       -- 0x18 (unused)
        FUNC_19,       -- 0x19 (unused)
        FUNC_1A,       -- 0x1A (unused)
        FUNC_1B,       -- 0x1B (unused)
        FUNC_1C,       -- 0x1C (unused)
        FUNC_1D,       -- 0x1D (unused)
        FUNC_MULT,     -- 0x1E
        FUNC_1F,       -- 0x1F (unused)
        FUNC_ADD,      -- 0x20
        FUNC_ADDU,     -- 0x21
        FUNC_SUB,      -- 0x22
        FUNC_SUBU,     -- 0x23
        FUNC_AND,      -- 0x24
        FUNC_OR,       -- 0x25
        FUNC_XOR,      -- 0x26
        FUNC_NOT,      -- 0x27
        FUNC_SEQ,      -- 0x28
        FUNC_SNE,      -- 0x29
        FUNC_SLT,      -- 0x2A
        FUNC_SGT,      -- 0x2B
        FUNC_SLE,      -- 0x2C
        FUNC_SGE,      -- 0x2D
        FUNC_2E,       -- 0x2E (unused)
        FUNC_2F,       -- 0x2F (unused)
        FUNC_MOVI2S,   -- 0x30 (unsupported)
        FUNC_MOVS2I,   -- 0x31 (unsupported)
        FUNC_MOVF,     -- 0x32 (unsupported)
        FUNC_MOVD,     -- 0x33 (unsupported)
        FUNC_MOVFP2I,  -- 0x34 (unsupported)
        FUNC_MOVI2FP,  -- 0x35 (unsupported)
        FUNC_MOVI2T,   -- 0x36 (unsupported)
        FUNC_MOVT2I,   -- 0x37 (unsupported)
        FUNC_38,       -- 0x38 (unused)
        FUNC_39,       -- 0x39 (unused)
        FUNC_SLTU,     -- 0x3A
        FUNC_SGTU,     -- 0x3B
        FUNC_SLEU,     -- 0x3C
        FUNC_SGEU,     -- 0x3D
        FUNC_3E,       -- 0x3E (unused)
        FUNC_3F        -- 0x3F (unused)
    );

    -- other instruction
    type opcode_t is (
        OPCODE_RTYPE,  -- 0x00
        OPCODE_01,     -- 0x01 (unused)
        OPCODE_J,      -- 0x02
        OPCODE_JAL,    -- 0x03
        OPCODE_BEQZ,   -- 0x04
        OPCODE_BNEZ,   -- 0x05
        OPCODE_BFPT,   -- 0x06 (unsupported)
        OPCODE_BFPF,   -- 0x07 (unsupported)
        OPCODE_ADDI,   -- 0x08
        OPCODE_ADDUI,  -- 0x09
        OPCODE_SUBI,   -- 0x0A
        OPCODE_SUBUI,  -- 0x0B
        OPCODE_ANDI,   -- 0x0C
        OPCODE_ORI,    -- 0x0D
        OPCODE_XORI,   -- 0x0E
        OPCODE_LHI,    -- 0x0F (unsupported)
        OPCODE_RFE,    -- 0x10 (unsupported)
        OPCODE_TRAP,   -- 0x11 (unsupported)
        OPCODE_JR,     -- 0x12
        OPCODE_JALR,   -- 0x13
        OPCODE_SLLI,   -- 0x14
        OPCODE_NOP,    -- 0x15
        OPCODE_SRLI,   -- 0x16
        OPCODE_SRAI,   -- 0x17
        OPCODE_SEQI,   -- 0x18
        OPCODE_SNEI,   -- 0x19
        OPCODE_SLTI,   -- 0x1A
        OPCODE_SGTI,   -- 0x1B
        OPCODE_SLEI,   -- 0x1C
        OPCODE_SGEI,   -- 0x1D
        OPCODE_ROLI,   -- 0x1E
        OPCODE_RORI,   -- 0x1F
        OPCODE_LB,     -- 0x20
        OPCODE_LH,     -- 0x21
        OPCODE_22,     -- 0x22 (unused)
        OPCODE_LW,     -- 0x23
        OPCODE_LBU,    -- 0x24
        OPCODE_LHU,    -- 0x25
        OPCODE_LF,     -- 0x26 (unsupported)
        OPCODE_LD,     -- 0x27
        OPCODE_SB,     -- 0x28
        OPCODE_SH,     -- 0x29
        OPCODE_2A,     -- 0x2A (unused)
        OPCODE_SW,     -- 0x2B
        OPCODE_2C,     -- 0x2C (unused)
        OPCODE_2D,     -- 0x2D (unused)
        OPCODE_SF,     -- 0x2E (unsupported)
        OPCODE_SD,     -- 0x2F (unsupported)
        OPCODE_30,     -- 0x30 (unused)
        OPCODE_31,     -- 0x31 (unused)
        OPCODE_32,     -- 0x32 (unused)
        OPCODE_33,     -- 0x33 (unused)
        OPCODE_34,     -- 0x34 (unused)
        OPCODE_35,     -- 0x35 (unused)
        OPCODE_36,     -- 0x36 (unused)
        OPCODE_37,     -- 0x37 (unused)
        OPCODE_ITLB,   -- 0x38 (unsupported)
        OPCODE_39,     -- 0x39 (unused)
        OPCODE_SLTUI,  -- 0x3A
        OPCODE_SGTUI,  -- 0x3B
        OPCODE_SLEUI,  -- 0x3C
        OPCODE_SGEUI,  -- 0x3D
        OPCODE_MULTI,  -- 0x3E
        OPCODE_3F      -- 0x3F (unused)
    );

    -- control words for implemented ISA

    constant NOP_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_i_type,           -- don't care
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,             -- don't care
            rf_write_enable      => '0'
        )
    );

    constant ADD_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ADDU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SUB_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sub
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SUBU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sub
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant AND_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_and
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant OR_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_or
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant XOR_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_xor
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGE_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sge
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGEU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sgeu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGT_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sgt
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGTU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sgtu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLE_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sle
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLEU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sleu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLT_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_slt
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLTU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sltu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLL_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sll
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SRL_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_srl
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SRA_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sra
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ROR_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_ror
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ROL_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_rol
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SNE_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_sne
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SEQ_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => reg,
            alu_operation        => op_seq
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant MULT_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_r_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_multiplier,
            second_operand_type  => reg,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ADDI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ADDUI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SUBI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sub
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SUBUI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sub
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ANDI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_and
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ORI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_or
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant XORI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_xor
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGEI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sge
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGEUI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sgeu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGTI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sgt
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SGTUI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sgtu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLEI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sle
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLEUI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sleu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLTI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_slt
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLTUI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => unsigned_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sltu
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SLLI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sll
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SRLI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_srl
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SRAI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sra
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant ROLI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_ror
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant RORI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_rol
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SNEI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_sne
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SEQI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_seq
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant MULTI_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_multiplier,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,
            rf_write_enable      => '1'
        )
    );
    
    constant J_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_jump_offset,
            rd_address_selection => rd_i_type,  -- don't care
            branch_condition     => always
        ),
        EXE => (
            is_branch            => '1',
            execution_unit       => unit_alu,
            second_operand_type  => imm,   -- don't care
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,   -- don't care
            rf_write_enable      => '0'
        )
    );
    
    constant JR_cw : control_word_t := (
        ID => (
            branch_target        => reg,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_i_type,    -- don't care
            branch_condition     => always
        ),
        EXE => (
            is_branch            => '1',
            execution_unit       => unit_alu,
            second_operand_type  => imm,   -- don't care
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,   -- don't care
            rf_write_enable      => '0'
        )
    );
    
    constant JAL_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_jump_offset,
            rd_address_selection => rd_jump_link_type,
            branch_condition     => always
        ),
        EXE => (
            is_branch            => '1',
            execution_unit       => unit_alu,
            second_operand_type  => imm,   -- don't care
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => npc,
            rf_write_enable      => '1'
        )
    );
    
    constant JALR_cw : control_word_t := (
        ID => (
            branch_target        => reg,
            immediate_selection  => unsigned_immediate,  -- don't care
            rd_address_selection => rd_jump_link_type,
            branch_condition     => always
        ),
        EXE => (
            is_branch            => '1',
            execution_unit       => unit_alu,
            second_operand_type  => imm,   -- don't care
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => npc,
            rf_write_enable      => '1'
        )
    );
    
    constant BEQZ_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,  -- don't care
            branch_condition     => equal_zero
        ),
        EXE => (
            is_branch            => '1',
            execution_unit       => unit_alu,
            second_operand_type  => imm,   -- don't care
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,   -- don't care
            rf_write_enable      => '0'
        )
    );
    
    constant BNEZ_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,  -- don't care
            branch_condition     => not_equal_zero
        ),
        EXE => (
            is_branch            => '1',
            execution_unit       => unit_alu,
            second_operand_type  => imm,   -- don't care
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,    -- don't care
            memory_data_size     => word              -- don't care
        ),
        WB => (
            writeback_selection  => alu_out,   -- don't care
            rf_write_enable      => '0'
        )
    );
    
    constant LW_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '1',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,
            memory_data_size     => word
        ),
        WB => (
            writeback_selection  => memory_out,
            rf_write_enable      => '1'
        )
    );
    
    constant LH_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '1',
            memory_write_enable  => '0',
            memory_data_type     => type_signed,
            memory_data_size     => half_word
        ),
        WB => (
            writeback_selection  => memory_out,
            rf_write_enable      => '1'
        )
    );
    
    constant LHU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '1',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,
            memory_data_size     => half_word
        ),
        WB => (
            writeback_selection  => memory_out,
            rf_write_enable      => '1'
        )
    );
    
    constant LB_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '1',
            memory_write_enable  => '0',
            memory_data_type     => type_signed,
            memory_data_size     => byte
        ),
        WB => (
            writeback_selection  => memory_out,
            rf_write_enable      => '1'
        )
    );
    
    constant LBU_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '1',
            memory_write_enable  => '0',
            memory_data_type     => type_unsigned,
            memory_data_size     => byte
        ),
        WB => (
            writeback_selection  => memory_out,
            rf_write_enable      => '1'
        )
    );
    
    constant SW_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,  -- don't care
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '1',
            memory_data_type     => type_unsigned,
            memory_data_size     => word
        ),
        WB => (
            writeback_selection  => alu_out,   -- don't care
            rf_write_enable      => '0'
        )
    );
    
    constant SH_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,  -- don't care
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '1',
            memory_data_type     => type_unsigned,
            memory_data_size     => half_word
        ),
        WB => (
            writeback_selection  => alu_out,   -- don't care
            rf_write_enable      => '0'
        )
    );
    
    constant SB_cw : control_word_t := (
        ID => (
            branch_target        => imm,
            immediate_selection  => signed_immediate,
            rd_address_selection => rd_i_type,  -- don't care
            branch_condition     => never
        ),
        EXE => (
            is_branch            => '0',
            execution_unit       => unit_alu,
            second_operand_type  => imm,
            alu_operation        => op_add
        ),
        MEM => (
            memory_read_enable   => '0',
            memory_write_enable  => '1',
            memory_data_type     => type_unsigned,
            memory_data_size     => byte
        ),
        WB => (
            writeback_selection  => alu_out,   -- don't care
            rf_write_enable      => '0'
        )
    );

    -- lookup table for R-type instructions
    type r_type_lut_t is array (0 to func_t'pos(func_t'right) - 1) of control_word_t;
    constant rtype_lut : r_type_lut_t :=(
        func_t'pos(FUNC_ADD)  => ADD_cw,
        func_t'pos(FUNC_ADDU) => ADDU_cw,
        func_t'pos(FUNC_AND)  => AND_cw,
        func_t'pos(FUNC_OR)   => OR_cw,
        func_t'pos(FUNC_SGE)  => SGE_cw,
        func_t'pos(FUNC_SLE)  => SLE_cw,
        func_t'pos(FUNC_SLL)  => SLL_cw,
        func_t'pos(FUNC_SNE)  => SNE_cw,
        func_t'pos(FUNC_SRL)  => SRL_cw,
        func_t'pos(FUNC_SUB)  => SUB_cw,
        func_t'pos(FUNC_SUBU) => SUBU_cw,
        func_t'pos(FUNC_XOR)  => XOR_cw,
        func_t'pos(FUNC_SGEU) => SGEU_cw,
        func_t'pos(FUNC_SGT)  => SGT_cw,
        func_t'pos(FUNC_SGTU) => SGTU_cw,
        func_t'pos(FUNC_SLEU) => SLEU_cw,
        func_t'pos(FUNC_SLT)  => SLT_cw,
        func_t'pos(FUNC_SLTU) => SLTU_cw,
        func_t'pos(FUNC_SRA)  => SRA_cw,
        func_t'pos(FUNC_SEQ)  => SEQ_cw,
        func_t'pos(FUNC_ROR)  => ROR_cw,
        func_t'pos(FUNC_ROL)  => ROL_cw,
        func_t'pos(FUNC_MULT) => MULT_cw,
        others                   => NOP_cw
    );
    
    -- lookup table for other instructions
    type others_lut_t is array (1 to opcode_t'pos(opcode_t'right)) of control_word_t;
    constant others_lut : others_lut_t :=(
        opcode_t'pos(OPCODE_NOP)   => NOP_cw,
        opcode_t'pos(OPCODE_ADDI)  => ADDI_cw,
        opcode_t'pos(OPCODE_ADDUI) => ADDUI_cw,
        opcode_t'pos(OPCODE_SUBI)  => SUBI_cw,
        opcode_t'pos(OPCODE_SUBUI) => SUBUI_cw,
        opcode_t'pos(OPCODE_ANDI)  => ANDI_cw,
        opcode_t'pos(OPCODE_ORI)   => ORI_cw,
        opcode_t'pos(OPCODE_XORI)  => XORI_cw,
        opcode_t'pos(OPCODE_SGEI)  => SGEI_cw,
        opcode_t'pos(OPCODE_SGEUI) => SGEUI_cw,
        opcode_t'pos(OPCODE_SGTI)  => SGTI_cw,
        opcode_t'pos(OPCODE_SGTUI) => SGTUI_cw,
        opcode_t'pos(OPCODE_SLEI)  => SLEI_cw,
        opcode_t'pos(OPCODE_SLEUI) => SLEUI_cw,
        opcode_t'pos(OPCODE_SLTI)  => SLTI_cw,
        opcode_t'pos(OPCODE_SLTUI) => SLTUI_cw,
        opcode_t'pos(OPCODE_SLLI)  => SLLI_cw,
        opcode_t'pos(OPCODE_SRLI)  => SRLI_cw,
        opcode_t'pos(OPCODE_SRAI)  => SRAI_cw,
        opcode_t'pos(OPCODE_SNEI)  => SNEI_cw,
        opcode_t'pos(OPCODE_SEQI)  => SEQI_cw,
        opcode_t'pos(OPCODE_J)     => J_cw,
        opcode_t'pos(OPCODE_JR)    => JR_cw,
        opcode_t'pos(OPCODE_JAL)   => JAL_cw,
        opcode_t'pos(OPCODE_JALR)  => JALR_cw,
        opcode_t'pos(OPCODE_BEQZ)  => BEQZ_cw,
        opcode_t'pos(OPCODE_BNEZ)  => BNEZ_cw,
        opcode_t'pos(OPCODE_LW)    => LW_cw,
        opcode_t'pos(OPCODE_LH)    => LH_cw,
        opcode_t'pos(OPCODE_LHU)   => LHU_cw,
        opcode_t'pos(OPCODE_LB)    => LB_cw,
        opcode_t'pos(OPCODE_LBU)   => LBU_cw,
        opcode_t'pos(OPCODE_SW)    => SW_cw,
        opcode_t'pos(OPCODE_SH)    => SH_cw,
        opcode_t'pos(OPCODE_SB)    => SB_cw,
        opcode_t'pos(OPCODE_ROLI)  => ROLI_cw,
        opcode_t'pos(OPCODE_RORI)  => RORI_cw,
        opcode_t'pos(OPCODE_MULTI) => MULTI_cw,
        others                        => NOP_cw
    );

end package control_word_package;
