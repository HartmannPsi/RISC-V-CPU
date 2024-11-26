`include "../macros.v"

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
  output wire [3:0] choose_tag,
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

reg [109:0] rs_buffer[2:0]; // {addr, vj, vk, qj, qk, op, busy}
reg [2:0] i;

function [2:0] getFreeBuf;
  begin
    for (i = 0; i < 3; i = i + 1) begin
      if (!rs_buffer[i][0]) begin
        getFreeBuf = i;
        return;
      end
    end
    getFreeBuf = 3'b111;
  end
endfunction

function [2:0] getReadyBuf;
  begin
    for (i = 0; i < 3; i = i + 1) begin
      if (rs_buffer[i][0] && rs_buffer[i][13:10] == `None &&
                rs_buffer[i][9:6] == `None) begin // busy && qj == None && qk == None
        getReadyBuf = i;
        return;
      end
    end
    getReadyBuf = 3'b111;
  end
endfunction

function [3:0] getTag;
  input [2:0] i;
  begin
    if (i == 0) begin
      getTag = `Add1;
    end
    else if (i == 1) begin
      getTag = `Add2;
    end
    else if (i == 2) begin 
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

wire [2:0] free_idx = buffer_full ? 3'b111 : (inst_receive ? getFreeBuf() : 3'b111);
wire [3:0] actual_qj = (op == `JAL || op == `AUIPC || op == `LUI) ? `None : qj;
wire [31:0] actual_vk = use_imm ? imm : vk;
wire [3:0] actual_qk = use_imm ? `None : qk;

assign choose_tag = inst_receive ? getTag(free_idx) : `None;
assign rs1_idx = rs1;
assign rs2_idx = rs2;
assign rd_idx = branch_in ? 5'b0 : rd;
assign inst_valid_out = inst_receive;

wire [2:0] ready_idx = getReadyBuf();
assign submit_valid = ready_idx != 3'b111;
assign submit_tag = submit_valid ? getTag(ready_idx) : `None;
wire [31:0] compute_addr = submit_valid ? rs_buffer[ready_idx][109:78] : 32'b0;
wire [31:0] op1 = submit_valid ? rs_buffer[ready_idx][77:46] : 32'b0;
wire [31:0] op2 = submit_valid ? rs_buffer[ready_idx][45:14] : 32'b0;
wire [4:0] alu_op = submit_valid ? rs_buffer[ready_idx][5:1] : 5'b0;

ALU alu(
  .op1(op1),
  .op2(op2),
  .addr(compute_addr),
  .alu_op(alu_op),
  .result(submit_val),
  .zero(),
  .c_out(),
  .overflow()
  .jalr_done(jalr_done),
  .jalr_addr(jalr_addr)
);


always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < 3; i = i + 1) begin
      rs_buffer[i] <= 110'b0;
    end
    i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    if (submit_valid) begin // inner update
      for (i = 0; i < 3; i = i + 1) begin
        if (rs_buffer[i][0] && rs_buffer[i][13:10] == submit_tag) begin // qj == submit_tag
          rs_buffer[i][13:10] <= `None; // qj <= None
          rs_buffer[i][77:46] <= submit_val; // vj <= submit_val
        end
        if (rs_buffer[i][0] && rs_buffer[i][9:6] == submit_tag) begin // qk == submit_tag
          rs_buffer[i][9:6] <= `None; // qk <= None
          rs_buffer[i][45:14] <= submit_val; // vk <= submit_val
        end
      end
    end

    if (cdb_active) begin // update
      for (i = 0; i < 3; i = i + 1) begin
        if (rs_buffer[i][0] && rs_buffer[i][13:10] == cdb_tag) begin // qj == cdb_tag
          rs_buffer[i][13:10] <= `None; // qj <= None
          rs_buffer[i][77:46] <= cdb_val; // vj <= cdb_val
        end
        if (rs_buffer[i][0] && rs_buffer[i][9:6] == cdb_tag) begin // qk == cdb_tag
          rs_buffer[i][9:6] <= `None; // qk <= None
          rs_buffer[i][45:14] <= cdb_val; // vk <= cdb_val
        end
      end
    end

    if (free_idx != 3'b111) begin // push
      rs_buffer[free_idx] <= {addr, vj, actual_vk, actual_qj, actual_qk, op, 1'b1};
    end

    if (ready_idx != 3'b111) begin // pop
      rs_buffer[ready_idx] <= 110'b0;
    end
  end
end

endmodule