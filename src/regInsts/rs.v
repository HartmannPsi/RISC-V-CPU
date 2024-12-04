`include "src/macros.v"
//`include "src/regInsts/alu.v"

module ReservationStation(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // inst from foq
  input wire [4:0] op,
  input wire branch_in,
  input wire ls,
  input wire use_imm,
  input wire [4:0] rd,
  input wire [4:0] rs1,
  input wire [4:0] rs2,
  input wire [31:0] imm,
  input wire jalr,
  input wire [31:0] addr,
  input wire inst_valid,

  // data to update from cdb
  input wire [3:0] cdb_tag,
  input wire [31:0] cdb_val,
  input wire [31:0] cdb_addr,
  input wire cdb_active,

  // whether pending
  output wire launch_fail,
  // tag of inst launched
  input wire [3:0] choose_tag,
  // idx of register needed
  output wire [4:0] rs1_idx,
  output wire [4:0] rs2_idx,
  output wire [4:0] rd_idx,
  output wire inst_valid_out,

  // inst to rob
  output wire [31:0] submit_val,
  output wire [3:0] submit_tag,
  output wire submit_valid,

  // jalr addr to processor
  output wire jalr_done,
  output wire [31:0] jalr_addr,

  // data from regfile
  input wire [31:0] vj,
  input wire [31:0] vk,
  input wire [3:0] qj,
  input wire [3:0] qk
);

reg [113:0] rs_buffer[2:0]; // {submit_tag, addr, vj, vk, qj, qk, op, busy}
reg [2:0] i;

function [2:0] getFreeBuf;
  // input [109:0] rs_buffer[2:0];
  input [113:0] rs_buffer0, rs_buffer1, rs_buffer2;

  begin
    // integer i;
    // getFreeBuf = 3'b111;
    // for (i = 0; i < 3; i = i + 1) begin : func_loop_1
    //   if (!rs_buffer[i[1:0]][0]) begin
    //     getFreeBuf = i[2:0];
    //     disable func_loop_1;
    //   end
    // end
    if (!rs_buffer0[0]) begin
      getFreeBuf = 3'b000;
    end
    else if (!rs_buffer1[0]) begin
      getFreeBuf = 3'b001;
    end
    else if (!rs_buffer2[0]) begin
      getFreeBuf = 3'b010;
    end
    else begin
      getFreeBuf = 3'b111;
    end
  end
endfunction

function [2:0] getReadyBuf;
  // input [109:0] rs_buffer[2:0];
  input [113:0] rs_buffer0, rs_buffer1, rs_buffer2;

  begin
    // integer i;
    // getReadyBuf = 3'b111;
    // for (i = 0; i < 3; i = i + 1) begin : func_loop_2
    //   if (rs_buffer[i[1:0]][0] && rs_buffer[i[1:0]][13:10] == `None &&
    //             rs_buffer[i[1:0]][9:6] == `None) begin // busy && qj == None && qk == None
    //     getReadyBuf = i[2:0];
    //     disable func_loop_2;
    //   end
    // end
    if (rs_buffer0[0] && rs_buffer0[13:10] == `None && rs_buffer0[9:6] == `None) begin // busy && qj == None && qk == None
      getReadyBuf = 3'b000;
    end
    else if (rs_buffer1[0] && rs_buffer1[13:10] == `None && rs_buffer1[9:6] == `None) begin // busy && qj == None && qk == None
      getReadyBuf = 3'b001;
    end
    else if (rs_buffer2[0] && rs_buffer2[13:10] == `None && rs_buffer2[9:6] == `None) begin // busy && qj == None && qk == None
      getReadyBuf = 3'b010;
    end
    else begin
      getReadyBuf = 3'b111;
    end
  end
endfunction

function [3:0] getTag;
  input [2:0] id;
  begin
    if (id == 0) begin
      getTag = `Add1;
    end
    else if (id == 1) begin
      getTag = `Add2;
    end
    else if (id == 2) begin 
      getTag = `Add3;
    end
    else begin // exception
      getTag = `None;
    end
  end
endfunction

wire inst_receive = inst_valid && op != `NONE && op != `LB && op != `LBU &&
            op != `LH && op != `LHU && op != `LW && op != `SB && op != `SH && op != `SW; // non-ls insts

wire buffer_full = rs_buffer[2][0] && rs_buffer[1][0] && rs_buffer[0][0];
assign launch_fail = inst_receive && buffer_full;

wire [2:0] free_idx = buffer_full ? 3'b111 : (inst_receive ? getFreeBuf(rs_buffer[0], rs_buffer[1], rs_buffer[2]) : 3'b111);

function CDBReceive;
input [3:0] push_tag;
input [3:0] cdb_tag;
input cdb_active;

begin
  CDBReceive = cdb_active && push_tag != `None && push_tag == cdb_tag;
end
endfunction

wire [3:0] actual_qj = (op == `JAL || op == `AUIPC || op == `LUI) ? `None : qj;
wire [31:0] actual_vk = (use_imm && !branch_in) ? imm : vk;
wire [3:0] actual_qk = (use_imm && !branch_in) ? `None : qk;

wire [31:0] push_vj = CDBReceive(actual_qj, cdb_tag, cdb_active) ? cdb_val : vj;
wire [31:0] push_vk = CDBReceive(actual_qk, cdb_tag, cdb_active) ? cdb_val : actual_vk;
wire [3:0] push_qj = CDBReceive(actual_qj, cdb_tag, cdb_active) ? `None : actual_qj;
wire [3:0] push_qk = CDBReceive(actual_qk, cdb_tag, cdb_active) ? `None : actual_qk;

// assign choose_tag = inst_receive ? getTag(free_idx) : `None;
assign rs1_idx = rs1;
assign rs2_idx = rs2;
assign rd_idx = (inst_receive && !branch_in) ? rd : 5'b0;
assign inst_valid_out = inst_receive;

wire [2:0] ready_idx = getReadyBuf(rs_buffer[0], rs_buffer[1], rs_buffer[2]);
assign submit_valid = ready_idx != 3'b111;
assign submit_tag = submit_valid ? rs_buffer[ready_idx[1:0]][113:110] : `None;
wire [31:0] compute_addr = submit_valid ? rs_buffer[ready_idx[1:0]][109:78] : 32'b0;
wire [31:0] op1 = submit_valid ? rs_buffer[ready_idx[1:0]][77:46] : 32'b0;
wire [31:0] op2 = submit_valid ? rs_buffer[ready_idx[1:0]][45:14] : 32'b0;
wire [4:0] alu_op = submit_valid ? rs_buffer[ready_idx[1:0]][5:1] : 5'b0;

ALU alu(
  .op1(op1),
  .op2(op2),
  .addr(compute_addr),
  .alu_op(alu_op),
  .result(submit_val),
  .zero(),
  .c_out(),
  .overflow(),
  .jalr_done(jalr_done),
  .jalr_addr(jalr_addr)
);

task Monitor;
  input [31:0] fetch_addr, inst, imm;
  input [4:0] op, rd, rs1, rs2;
  input use_imm;
  input [31:0] vj, vk;
  input [3:0] qj, qk;
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

  $display("vj=%0h, vk=%0h, qj=%0h, qk=%0h", vj, vk, qj, qk);
end
endtask

task Monitor1;
input [31:0] op1, op2;
input [4:0] alu_op;
input [31:0] res;

begin
  if (alu_op == `ADD) begin
    $display("ADDI OP: op1=%0h, op2=%0h, res=%0h", op1, op2, res);
  end
end

endtask


always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < 3; i = i + 1) begin
      rs_buffer[i[1:0]] <= 114'b0;
    end
    //i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    // Monitor(op1, op2, alu_op, submit_val);

    if (submit_valid) begin // inner update
      for (i = 0; i < 3; i = i + 1) begin
        if (rs_buffer[i[1:0]][0] && rs_buffer[i[1:0]][13:10] == submit_tag) begin // qj == submit_tag
          rs_buffer[i[1:0]][13:10] <= `None; // qj <= None
          rs_buffer[i[1:0]][77:46] <= submit_val; // vj <= submit_val
        end
        if (rs_buffer[i[1:0]][0] && rs_buffer[i[1:0]][9:6] == submit_tag) begin // qk == submit_tag
          rs_buffer[i[1:0]][9:6] <= `None; // qk <= None
          rs_buffer[i[1:0]][45:14] <= submit_val; // vk <= submit_val
        end
      end
    end

    if (cdb_active) begin // update
      for (i = 0; i < 3; i = i + 1) begin
        if (rs_buffer[i[1:0]][0] && rs_buffer[i[1:0]][13:10] == cdb_tag) begin // qj == cdb_tag
          rs_buffer[i[1:0]][13:10] <= `None; // qj <= None
          rs_buffer[i[1:0]][77:46] <= cdb_val; // vj <= cdb_val
        end
        if (rs_buffer[i[1:0]][0] && rs_buffer[i[1:0]][9:6] == cdb_tag) begin // qk == cdb_tag
          rs_buffer[i[1:0]][9:6] <= `None; // qk <= None
          rs_buffer[i[1:0]][45:14] <= cdb_val; // vk <= cdb_val
        end
      end
    end

    if (free_idx != 3'b111) begin // push
      rs_buffer[free_idx[1:0]] <= {choose_tag, addr, push_vj, push_vk, push_qj, push_qk, op, 1'b1};
      
      // Monitor(addr, 32'b0, imm, op, rd, rs1, rs2, use_imm, vj, actual_vk, actual_qj, actual_qk);
    end

    if (ready_idx != 3'b111) begin // pop
      rs_buffer[ready_idx[1:0]] <= 114'b0;
    end
  end
end

endmodule