`define AUIPC 5'b01100
`define ADD   5'b00001
`define SUB   5'b00010
`define AND   5'b00011
`define OR    5'b00100
`define XOR   5'b00101
`define SLL   5'b00110
`define SRL   5'b00111
`define SRA   5'b01000
`define SLT   5'b01001
`define SLTU  5'b01010
`define LUI   5'b01011

`define LB    5'b10000
`define LBU   5'b10001
`define LH    5'b10010
`define LHU   5'b10011
`define LW    5'b10100
`define SB    5'b10101
`define SH    5'b10110
`define SW    5'b10111
`define BEQ   5'b11000
`define BGE   5'b11001
`define BGEU  5'b11010
`define BLT   5'b11011
`define BLTU  5'b11100
`define BNE   5'b11101
`define JAL   5'b11110
`define JALR  5'b11111
`define NONE  5'b00000

`define BIN_OP   7'b011'0011
`define IMM_OP   7'b001'0011
`define LD_OP    7'b000'0011
`define ST_OP    7'b010'0011
`define BR_OP    7'b110'0011
`define JAL_OP   7'b110'1111
`define JALR_OP  7'b110'0111
`define AUIPC_OP 7'b001'0111
`define LUI_OP   7'b011'0111

`define None 4'b0000
`define Add1 4'b0001
`define Add2 4'b0010
`define Add3 4'b0011
`define LS1  4'b0100
`define LS2  4'b0101
`define LS3  4'b0110
`define LS4  4'b0111
`define LS5  4'b1000
`define LS6  4'b1001
`define LS7  4'b1010
`define LS8  4'b1011
`define LS9  4'b1100
`define LS10 4'b1101

`define BP_SIZE_W 8
`define BP_SIZE (1 << `BP_SIZE_W)

`define FOQ_SIZE_W 4
`define FOQ_SIZE (1 << `FOQ_SIZE_W)

`define ICACHE_ADDR_W 5
`define ICACHE_SIZE (1 << `ICACHE_ADDR_W)

`define ROB_SIZE_W 4
`define ROB_SIZE (1 << `ROB_SIZE_W)

`define DCACHE_ADDR_W 7
`define DCACHE_SIZE (1 << `DCACHE_ADDR_W)