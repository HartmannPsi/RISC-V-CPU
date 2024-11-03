module InstDecoder(
  input wire [31:0] inst,

  output wire [4:0] op,
  output wire branch,
  output wire ls,
  output wire use_imm,
  output wire [4:0] rd,
  output wire [4:0] rs1,
  output wire [4:0] rs2,
  output wire [31:0] imm,
  output wire jalr
);

assign wire [6:0] opcode = inst[6:0];
assign wire [2:0] funct3 = inst[14:12];
assign wire [6:0] funct7 = inst[31:25];

always @(*) begin
  ls = (opcode == `LD_OP) || (opcode == `ST_OP);
  branch = (opcode == `BR_OP) || (opcode == `JAL_OP) || (opcode == `JALR_OP);
  rd = inst[11:7];
  rs1 = inst[19:15];
  rs2 = inst[24:20];

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
      imm = {20{inst[31]}, inst[31:20]};

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

    imm = {20{inst[31]}, inst[31:20]};
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

    imm = {20{inst[31]}, inst[31:25], inst[11:7]};
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

    imm = {20{inst[31]}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    use_imm = 1;
  end

  `JAL_OP:
  begin
    op = `JAL;
    imm = {20{inst[31]}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
    use_imm = 1;
  end

  `JALR_OP:
  begin
    op = `JALR;
    imm = {20{inst[31]}, inst[31:20]};
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
  jalr = (op == `JALR);
end

endmodule