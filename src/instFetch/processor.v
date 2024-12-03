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

task Monitor;
  input [31:0] fetch_addr, inst, imm;
  input [4:0] op, rd, rs1, rs2;
  input use_imm;
begin

  //$display("pc=%0h; inst=%0h", fetch_addr, inst);
  $write("%0h: ", fetch_addr);

  case (op)
  `LB:
  begin
    $display("LB x%0d, %0h(x%0d)", rd, imm, rs1);
  end

  `LBU:
  begin
    $display("LBU x%0d, %0h(x%0d)", rd, imm, rs1);
  end

  `LH:
  begin
    $display("LH x%0d, %0h(x%0d)", rd, imm, rs1);
  end

  `LHU:
  begin
    $display("LHU x%0d, %0h(x%0d)", rd, imm, rs1);
  end

  `LW:
  begin
    $display("LW x%0d, %0h(x%0d)", rd, imm, rs1);
  end

  `SB:
  begin
    $display("SB x%0d, %0h(x%0d)", rs2, imm, rs1);
  end

  `SH:
  begin
    $display("SH x%0d, %0h(x%0d)", rs2, imm, rs1);
  end

  `SW:
  begin
    $display("SW x%0d, %0h(x%0d)", rs2, imm, rs1);
  end

  `BEQ:
  begin
    $display("BEQ x%0d, x%0d, %0h", rs1, rs2, imm + fetch_addr);
  end

  `BGE:
  begin
    $display("BGE x%0d, x%0d, %0h", rs1, rs2, imm + fetch_addr);
  end

  `BGEU:
  begin
    $display("BGEU x%0d, x%0d, %0h", rs1, rs2, imm + fetch_addr);
  end

  `BLT:
  begin
    $display("BLT x%0d, x%0d, %0h", rs1, rs2, imm + fetch_addr);
  end

  `BLTU:
  begin
    $display("BLTU x%0d, x%0d, %0h", rs1, rs2, imm + fetch_addr);
  end

  `BNE:
  begin
    $display("BNE x%0d, x%0d, %0h", rs1, rs2, imm + fetch_addr);
  end

  `JAL:
  begin
    $display("JAL x%0d, %0h", rd, imm + fetch_addr);
  end

  `JALR:
  begin
    $display("JALR x%0d, x%0d, %0h", rd, rs1, imm);
  end

  `AUIPC:
  begin
    $display("AUIPC x%0d, %0h", rd, imm);
  end

  `ADD:
  begin
    if (use_imm) begin // addi
      $display("ADDI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // add
      $display("ADD x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `SUB:
  begin
    $display("SUB x%0d, x%0d, x%0d", rd, rs1, rs2);
  end

  `AND:
  begin
    if (use_imm) begin // andi
      $display("ANDI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // and
      $display("AND x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `OR:
  begin
    if (use_imm) begin // ori
      $display("ORI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // or
      $display("OR x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `XOR:
  begin
    if (use_imm) begin // xori
      $display("XORI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // xor
      $display("XOR x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `SLL:
  begin
    if (use_imm) begin // slli
      $display("SLLI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // sll
      $display("SLL x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `SRL:
  begin
    if (use_imm) begin // srli
      $display("SRLI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // srl
      $display("SRL x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `SRA:
  begin
    if (use_imm) begin // srai
      $display("SRAI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // sra
      $display("SRA x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `SLT:
  begin
    if (use_imm) begin // slti
      $display("SLTI x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // slt
      $display("SLT x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `SLTU:
  begin
    if (use_imm) begin // sltiu
      $display("SLTIU x%0d, x%0d, %0d", rd, rs1, $signed(imm));
    end
    else begin // sltu
      $display("SLTU x%0d, x%0d, x%0d", rd, rs1, rs2);
    end
  end

  `LUI:
  begin
    $display("LUI x%0d, %0h", rd, imm);
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
    cease <= 1'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    if (predict_fail) begin // reset from predict fail
      pc <= fail_addr;
    end
    else if (inst_available) begin // inst is valid
      // Monitor(fetch_addr, inst, imm, op, rd, rs1, rs2, use_imm);
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
        if (branch) begin // go to predicted branch addr
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