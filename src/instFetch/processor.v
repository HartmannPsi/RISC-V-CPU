`include "src/macros.v"
//`include "src/instFetch/decoder.v"

module InstProcessor(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // cache_hit from icache
  input wire inst_available,
  // inst from icache
  input wire [31:0] inst,
  // inst length from icache, 1 for 32-bit, 0 for 16-bit
  input wire inst_length,
  // pc to icache
  output wire [31:0] fetch_addr,

  // whether to branch from bp
  input wire branch,
  // branch target from bp
  input wire [31:0] branch_addr,

  // jalr done from alu
  input wire jalr_compute,
  input wire [31:0] jalr_addr,

  // whether former prediction is wrong from bp
  input wire predict_fail,
  // fail addr to reset from bp
  input wire [31:0] fail_addr,

  // whther the inst is valid
  output wire decode_valid,

  // jalr done from cdb
  //input wire jalr_done,

  // pause signal from foq
  input wire foq_full,

  // decoded inst from decoder
  output wire [4:0] op,
  output wire branch_out,
  output wire ls,
  output wire use_imm,
  output wire [4:0] rd,
  output wire [4:0] rs1,
  output wire [4:0] rs2,
  output wire [31:0] imm,
  output wire jalr
  // Other i/o TODO
);

reg [31:0] pc;
reg cease;

//integer nxt_offset;
wire [31:0] nxt_offset = inst_length ? 4 : 2;

assign fetch_addr = pc;
assign decode_valid = cease ? 1'b0 : inst_available;

InstDecoder decoder(
  .inst(inst),
  .inst_length(inst_length),
  .op(op),
  .branch(branch_out),
  .ls(ls),
  .use_imm(use_imm),
  .rd(rd),
  .rs1(rs1),
  .rs2(rs2),
  .imm(imm),
  .jalr(jalr)
);

task printInst;
  input [31:0] fetch_addr, inst, imm;
  input [4:0] op, rd, rs1, rs2;
  input use_imm;
begin

  $display("pc=%h; inst=%h", fetch_addr, inst);

  case (op)
  `LB:
  begin
    $display("LB x%d %d(x%d)", rd, imm, rs1);
  end

  `LBU:
  begin
    $display("LBU x%d %d(x%d)", rd, imm, rs1);
  end

  `LH:
  begin
    $display("LH x%d %d(x%d)", rd, imm, rs1);
  end

  `LHU:
  begin
    $display("LHU x%d %d(x%d)", rd, imm, rs1);
  end

  `LW:
  begin
    $display("LW x%d %d(x%d)", rd, imm, rs1);
  end

  `SB:
  begin
    $display("SB x%d %d(x%d)", rs2, imm, rs1);
  end

  `SH:
  begin
    $display("SH x%d %d(x%d)", rs2, imm, rs1);
  end

  `SW:
  begin
    $display("SW x%d %d(x%d)", rs2, imm, rs1);
  end

  `BEQ:
  begin
    $display("BEQ x%d x%d offset=%d", rs1, rs2, imm);
  end

  `BGE:
  begin
    $display("BGE x%d x%d offset=%d", rs1, rs2, imm);
  end

  `BGEU:
  begin
    $display("BGEU x%d x%d offset=%d", rs1, rs2, imm);
  end

  `BLT:
  begin
    $display("BLT x%d x%d offset=%d", rs1, rs2, imm);
  end

  `BLTU:
  begin
    $display("BLTU x%d x%d offset=%d", rs1, rs2, imm);
  end

  `BNE:
  begin
    $display("BNE x%d x%d offset=%d", rs1, rs2, imm);
  end

  `JAL:
  begin
    $display("JAL x%d offset=%d", rd, imm);
  end

  `JALR:
  begin
    $display("JALR x%d x%d %d", rd, rs1, imm);
  end

  `AUIPC:
  begin
    $display("AUIPC x%d %d", rd, imm);
  end

  `ADD:
  begin
    if (use_imm) begin // addi
      $display("ADDI x%d x%d %d", rd, rs1, imm);
    end
    else begin // add
      $display("ADD x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `SUB:
  begin
    $display("SUB x%d x%d x%d", rd, rs1, rs2);
  end

  `AND:
  begin
    if (use_imm) begin // andi
      $display("ANDI x%d x%d %d", rd, rs1, imm);
    end
    else begin // and
      $display("AND x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `OR:
  begin
    if (use_imm) begin // ori
      $display("ORI x%d x%d %d", rd, rs1, imm);
    end
    else begin // or
      $display("OR x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `XOR:
  begin
    if (use_imm) begin // xori
      $display("XORI x%d x%d %d", rd, rs1, imm);
    end
    else begin // xor
      $display("XOR x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `SLL:
  begin
    if (use_imm) begin // slli
      $display("SLLI x%d x%d %d", rd, rs1, imm);
    end
    else begin // sll
      $display("SLL x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `SRL:
  begin
    if (use_imm) begin // srli
      $display("SRLI x%d x%d %d", rd, rs1, imm);
    end
    else begin // srl
      $display("SRL x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `SRA:
  begin
    if (use_imm) begin // srai
      $display("SRAI x%d x%d %d", rd, rs1, imm);
    end
    else begin // sra
      $display("SRA x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `SLT:
  begin
    if (use_imm) begin // slti
      $display("SLTI x%d x%d %d", rd, rs1, imm);
    end
    else begin // slt
      $display("SLT x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `SLTU:
  begin
    if (use_imm) begin // sltiu
      $display("SLTIU x%d x%d %d", rd, rs1, imm);
    end
    else begin // sltu
      $display("SLTU x%d x%d x%d", rd, rs1, rs2);
    end
  end

  `LUI:
  begin
    $display("LUI x%d %d", rd, imm);
  end

  default:
  begin
    $display("Invalid Inst!");
  end
  endcase
end
endtask

always @(posedge clk_in) begin
  if (rst_in) begin
    pc <= 32'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    if (inst_available) begin // inst is valid
      printInst(fetch_addr, inst, imm, op, rd, rs1, rs2, use_imm);
      if (jalr) begin // pause fetching util jalr is done
        // pause
        cease <= 1'b1;
      end
      else if (cease && !jalr_compute) begin // pause fetching util jalr is done
        // pause
      end
      else if (foq_full) begin // pause fetching util foq is not full
        // pause
      end
      else begin // ordinary fetching
        if (predict_fail) begin // reset from predict fail
          pc <= fail_addr;
        end
        else if (branch) begin // go to predicted branch addr
          pc <= branch_addr;
        end
        else if (op == `JAL) begin // go to unconditional branch addr
          pc <= pc + imm;
        end
        else begin // normal pc increment
          pc <= pc + nxt_offset;
        end
      end
    end

    if (jalr_compute) begin // reset cease
      cease <= 1'b0;
      pc <= jalr_addr;
    end

  end
end

endmodule