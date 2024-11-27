`include "src/macros.v"

module InstDecoder(
  input wire [31:0] inst,
  input wire inst_length,

  output reg [4:0] op,
  output reg branch,
  output reg ls,
  output reg use_imm,
  output reg [4:0] rd,
  output reg [4:0] rs1,
  output reg [4:0] rs2,
  output reg [31:0] imm,
  output reg jalr
);

wire [6:0] opcode = inst[6:0];
wire [2:0] funct3 = inst[14:12];
wire [6:0] funct7 = inst[31:25];

always @(*) begin

  if (inst == 0) begin // invalid
    op = 0;
    branch = 0;
    ls = 0;
    use_imm = 0;
    rd = 0;
    rs1 = 0;
    rs2 = 0;
    imm = 0;
    jalr = 0;
  end
  else if (inst_length) begin // 32-bit
  
    ls = (opcode == `LD_OP) || (opcode == `ST_OP) ? 1'b1 : 1'b0;
    branch = (opcode == `BR_OP) ? 1'b1 : 1'b0; // || (opcode == `JAL_OP); // || (opcode == `JALR_OP);
    rd = inst[11:7];
    rs1 = inst[19:15];
    rs2 = inst[24:20];
    jalr = (opcode == `JALR_OP) ? 1'b1 : 1'b0;

    case (opcode)
    `BIN_OP:
    begin
      case (funct3)
      3'b000:
      if (funct7 == 7'b0000000)
        op = `ADD;
      else
        op = `SUB;
      3'b111:
      op = `AND;
      3'b110:
      op = `OR;
      3'b100:
      op = `XOR;
      3'b001:
      op = `SLL;
      3'b101:
      if (funct7 == 7'b0000000)
        op = `SRL;
      else
        op = `SRA;
      3'b010:
      op = `SLT;
      3'b011:
      op = `SLTU;
      endcase
      use_imm = 0;
    end

    `IMM_OP:
    begin
      case (funct3)
      3'b000:
      op = `ADD;
      3'b111:
      op = `AND;
      3'b110:
      op = `OR;
      3'b100:
      op = `XOR;
      3'b001:
      op = `SLL;
      3'b101:
      if (funct7 == 7'b0000000)
        op = `SRL;
      else
        op = `SRA;
      3'b010:
      op = `SLT;
      3'b011:
      op = `SLTU;
      endcase

      if (funct3 == 3'b001 || funct3 == 3'b101)
        imm = {27'b0, inst[24:20]};
      else
        imm = {{20{inst[31]}}, inst[31:20]};

      use_imm = 1;
    end

    `LD_OP:
    begin
      case (funct3)
      3'b000:
      op = `LB;
      3'b001:
      op = `LH;
      3'b010:
      op = `LW;
      3'b100:
      op = `LBU;
      3'b101:
      op = `LHU;
      endcase

      imm = {{20{inst[31]}}, inst[31:20]};
      use_imm = 1;
    end

    `ST_OP:
    begin
      case (funct3)
      3'b000:
      op = `SB;
      3'b001:
      op = `SH;
      3'b010:
      op = `SW;
      endcase

      imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
      use_imm = 1;
    end

    `BR_OP:
    begin
      case (funct3)
      3'b000:
      op = `BEQ;
      3'b001:
      op = `BNE;
      3'b100:
      op = `BLT;
      3'b101:
      op = `BGE;
      3'b110:
      op = `BLTU;
      3'b111:
      op = `BGEU;
      endcase

      imm = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
      use_imm = 1;
    end

    `JAL_OP:
    begin
      op = `JAL;
      imm = {{11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
      use_imm = 1;
    end

    `JALR_OP:
    begin
      op = `JALR;
      imm = {{20{inst[31]}}, inst[31:20]};
      use_imm = 1;
    end

    `AUIPC_OP:
    begin
      op = `AUIPC;
      imm = {inst[31:12], 12'b0};
      use_imm = 1;
    end

    `LUI_OP:
    begin
      op = `LUI;
      imm = {inst[31:12], 12'b0};
      use_imm = 1;
    end
    endcase
  end
  else begin // 16-bit
    // TODO: c.addi，c.jal，c.li，c.addi16sp，c.lui，c.srli，c.srai，c.andi，c.sub，c.xor，c.or，c.and，
    // c.j，c.beqz，c.bnez，c.addi4spn，c.lw，c.sw，c.slli，c.jr，c.mv，c.jalr，c.add，c.lwsp，c.swsp
    if (inst[15:13] == 3'b000 && inst[1:0] == 2'b01 && {inst[12], inst[6:2]} != 0 && inst[11-7] != 0) begin // c.addi
      op = `ADD;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = inst[11:7];
      rs1 = inst[11:7];
      rs2 = 0;
      imm = {{26{inst[12]}}, inst[12], inst[6:2]};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b001 && inst[1:0] == 2'b01) begin // c.jal
      op = `JAL;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = 1; // x1
      rs1 = 0;
      rs2 = 0;
      imm = {{20{inst[12]}}, inst[12], inst[8], inst[10:9], inst[6], inst[7], inst[2], inst[11], inst[5:3], 1'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b010 && inst[1:0] == 2'b01) begin // c.li
      op = `ADD;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = inst[11:7];
      rs1 = 0; // x0
      rs2 = 0;
      imm = {{26{inst[12]}}, inst[12], inst[6:2]};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b011 && inst[11:7] == 5'b00010 && inst[1:0] == 2'b01 && {inst[12], inst[6:2]} != 0) begin // c.addi16sp
      op = `ADD;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = 2; // x2
      rs1 = 2; // x2
      rs2 = 0;
      imm = {{22{inst[12]}}, inst[12], inst[4:3], inst[5], inst[2], inst[6], 4'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b011 && inst[1:0] == 2'b01 && {inst[12], inst[6:2]} != 0) begin // c.lui
      op = `LUI;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = inst[11:7];
      rs1 = 0;
      rs2 = 0;
      imm = {{14{inst[12]}}, inst[12], inst[6:2], 12'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b100 && inst[11:10] == 2'b00 && inst[1:0] == 2'b01 && inst[12] == 0) begin // c.srli
      op = `SRL;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = {2'b0, inst[9:7]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = 0;
      imm = {26'b0, inst[12], inst[6:2]};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b100 && inst[11:10] == 2'b01 && inst[1:0] == 2'b01 && inst[12] == 0) begin // c.srai
      op = `SRA;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = {2'b0, inst[9:7]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = 0;
      imm = {26'b0, inst[12], inst[6:2]};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b100 && inst[11:10] == 2'b10 && inst[1:0] == 2'b01) begin // c.andi
      op = `AND;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = {2'b0, inst[9:7]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = 0;
      imm = {{26{inst[12]}}, inst[12], inst[6:2]};
      jalr = 0;
    end

    else if (inst[15:10] == 6'b100011 && inst[6:5] == 2'b00 && inst[1:0] == 2'b01) begin // c.sub
      op = `SUB;
      branch = 0;
      ls = 0;
      use_imm = 0;
      rd = {2'b0, inst[9:7]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = {2'b0, inst[4:2]} + 8;
      imm = 0;
      jalr = 0;
    end

    else if (inst[15:10] == 6'b100011 && inst[6:5] == 2'b01 && inst[1:0] == 2'b01) begin // c.xor
      op = `XOR;
      branch = 0;
      ls = 0;
      use_imm = 0;
      rd = {2'b0, inst[9:7]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = {2'b0, inst[4:2]} + 8;
      imm = 0;
      jalr = 0;
    end

    else if (inst[15:10] == 6'b100011 && inst[6:5] == 2'b10 && inst[1:0] == 2'b01) begin // c.or
      op = `OR;
      branch = 0;
      ls = 0;
      use_imm = 0;
      rd = {2'b0, inst[9:7]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = {2'b0, inst[4:2]} + 8;
      imm = 0;
      jalr = 0;
    end

    else if (inst[15:10] == 6'b100011 && inst[6:5] == 2'b11 && inst[1:0] == 2'b01) begin // c.and
      op = `AND;
      branch = 0;
      ls = 0;
      use_imm = 0;
      rd = {2'b0, inst[9:7]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = {2'b0, inst[4:2]} + 8;
      imm = 0;
      jalr = 0;
    end

    else if (inst[15:13] == 3'b101 && inst[1:0] == 2'b01) begin // c.j
      op = `JAL;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = 0; // x0
      rs1 = 0;
      rs2 = 0;
      imm = {{20{inst[12]}}, inst[12], inst[8], inst[10:9], inst[6], inst[7], inst[2], inst[11], inst[5:3], 1'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b110 && inst[1:0] == 2'b01) begin // c.beqz
      op = `BEQ;
      branch = 1;
      ls = 0;
      use_imm = 1;
      rd = 0;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = 0; // x0
      imm = {{23{inst[12]}}, inst[12], inst[6:5], inst[2], inst[11:10], inst[4:3], 1'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b111 && inst[1:0] == 2'b01) begin // c.bnez
      op = `BNE;
      branch = 1;
      ls = 0;
      use_imm = 1;
      rd = 0;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = 0; // x0
      imm = {{23{inst[12]}}, inst[12], inst[6:5], inst[2], inst[11:10], inst[4:3], 1'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b000 && inst[1:0] == 2'b00 && inst[12:5] != 0) begin // c.addi4spn
      op = `ADD;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = {2'b0, inst[4:2]} + 8;
      rs1 = 0;
      rs2 = 2; // x2
      imm = {22'b0, inst[10:7], inst[12:11], inst[5], inst[6], 2'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b010 && inst[1:0] == 2'b00) begin // c.lw
      op = `LW;
      branch = 0;
      ls = 1;
      use_imm = 1;
      rd = {2'b0, inst[4:2]} + 8;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = 0;
      imm = {25'b0, inst[5], inst[12:10], inst[6], 2'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b110 && inst[1:0] == 2'b00) begin // c.sw
      op = `SW;
      branch = 0;
      ls = 1;
      use_imm = 1;
      rd = 0;
      rs1 = {2'b0, inst[9:7]} + 8;
      rs2 = {2'b0, inst[4:2]} + 8;
      imm = {25'b0, inst[5], inst[12:10], inst[6], 2'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b010 && inst[1:0] == 2'b10 && inst[12] == 0) begin // c.slli
      op = `SLL;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = inst[11:7];
      rs1 = inst[11:7];
      rs2 = 0;
      imm = {26'b0, inst[12], inst[6:2]};
      jalr = 0;
    end

    else if (inst[15:12] == 4'b1000 && inst[6:0] == 7'b000_0010) begin // c.jr
      op = `JALR;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = 0; // x0
      rs1 = inst[11:7];
      rs2 = 0;
      imm = 0;
      jalr = 1;
    end

    else if (inst[15:12] == 4'b1000 && inst[1:0] == 2'b10) begin // c.mv
      op = `ADD;
      branch = 0;
      ls = 0;
      use_imm = 0;
      rd = inst[11:7];
      rs1 = 0; // x0
      rs2 = inst[6:2];
      imm = 0;
      jalr = 0;
    end

    else if (inst[15:12] == 4'b1001 && inst[6:0] == 7'b000_0010) begin // c.jalr
      op = `JALR;
      branch = 0;
      ls = 0;
      use_imm = 1;
      rd = 1; // x1
      rs1 = inst[11:7];
      rs2 = 0;
      imm = 0;
      jalr = 1;
    end

    else if (inst[15:12] == 4'b1001 && inst[1:0] == 2'b10) begin // c.add
      op = `ADD;
      branch = 0;
      ls = 0;
      use_imm = 0;
      rd = inst[11:7];
      rs1 = inst[11:7];
      rs2 = inst[6:2];
      imm = 0;
      jalr = 0;
    end

    else if (inst[15:13] == 3'b010 && inst[1:0] == 2'b10) begin // c.lwsp
      op = `LW;
      branch = 0;
      ls = 1;
      use_imm = 1;
      rd = inst[11:7];
      rs1 = 2; // x2
      rs2 = 0;
      imm = {24'b0, inst[3:2], inst[12], inst[6:4], 2'b0};
      jalr = 0;
    end

    else if (inst[15:13] == 3'b110 && inst[1:0] == 2'b10) begin // c.swsp
      op = `SW;
      branch = 0;
      ls = 1;
      use_imm = 1;
      rd = 0;
      rs1 = 2; // x2
      rs2 = inst[6:2];
      imm = {24'b0, inst[8:7], inst[12:9], 2'b0};
      jalr = 0;
    end
    else begin // invalid
      op = 0;
      branch = 0;
      ls = 0;
      use_imm = 0;
      rd = 0;
      rs1 = 0;
      rs2 = 0;
      imm = 0;
      jalr = 0;
    end
  end
end

endmodule