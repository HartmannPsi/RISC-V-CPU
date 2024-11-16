`inlcude "../macros.v"

module LoadStoreBuffer(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // inst from processor
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

  // ls ops to mem_controller
  output wire [31:0] st_val,
  output wire [31:0] ls_addr,
  output wire r_nw_out, // 1: read, 0: write
  output wire [2:0] type_out, // [1:0]: 00: word, 01: half-word, 10: byte, [2]: 1: signed, 0: unsigned
  output activate_mem,

  // ls ops from mem_controller
  input wire [31:0] ld_val,
  input wire ls_done_in,


  // data from regfile
  input wire [31:0] vj,
  input wire [31:0] vk,
  input wire [3:0] qj,
  input wire [3:0] qk
);

reg [142:0] ls_buffer[9:0]; // {ls_done, imm, addr, vj, vk, qj, qk, op, busy}
reg [3:0] i;
reg [3:0] ongoing_idx;

function [3:0] getFreeBuf;
  begin
    for (i = 0; i < 10; i = i + 1) begin
      if (!ls_buffer[i][0]) begin
        getFreeBuf = i;
        return;
      end
    end
    getFreeBuf = 4'b1111;
  end
endfunction

function [3:0] getReadyBuf;
  begin
    for (i = 0; i < 10; i = i + 1) begin
      if (ls_buffer[i][0] && ls_buffer[i][13:10] == `None &&
                ls_buffer[i][9:6] == `None) begin // busy && qj == None && qk == None
        getReadyBuf = i;
        return;
      end
    end
    getReadyBuf = 4'b1111;
  end
endfunction

function [3:0] getTag;
  input [3:0] i;
  begin
    if (i >= 0 && i < 10) begin
      getTag = i + 4'b0100;
    end
    else begin
      getTag = `None;
    end
  end
endfunction

function buf_full
  begin
    for (i = 0; i < 10; i = i + 1) begin
      if (!ls_buffer[i][0]) begin
        buffer_full = 1'b0;
        return;
      end
    end
    buffer_full = 1'b1;
  end
endfunction

function [2:0] getType;
  input [4:0] op;
  if (op == `LB) begin
    getType = 3'b110;
  end
  else if (op == `LBU) begin
    getType = 3'b010;
  end
  else if (op == `LH) begin
    getType = 3'b101;
  end
  else if (op == `LHU) begin
    getType = 3'b001;
  end
  else if (op == `LW) begin
    getType = 3'b000;
  end
  else if (op == `SB) begin
    getType = 3'b010;
  end
  else if (op == `SH) begin
    getType = 3'b001;
  end
  else if (op == `SW) begin
    getType = 3'b000;
  end
  else begin
    getType = 3'b111;
  end
endfunction

wire input_ld_inst = (op == `LB || op == `LBU || op == `LH || op == `LHU || op == `LW);
wire input_st_inst = (op == `SB || op == `SH || op == `SW);

wire inst_receive = inst_valid && (input_ld_inst || input_st_inst); // ls insts
wire buffer_full = buf_full();
assign launch_fail = inst_receive && buffer_full;

wire [2:0] free_idx = buffer_full ? 4'b1111 : (inst_receive ? getFreeBuf() : 4'b1111);

wire [3:0] actual_qk = input_ld_inst ? `None : qk;

assign choose_tag = inst_receive ? getTag(free_idx) : `None;
assign rs1_idx = rs1;
assign rs2_idx = rs2;
assign rd_idx = input_ld_inst ? rd : 5'b0;
assign inst_valid_out = inst_receive;

wire [2:0] ready_idx = getReadyBuf();

wire ready_ld_inst = ready_idx == 4'b1111 ? 1'b0 : (ls_buffer[ready_idx][5:1] == `LB || ls_buffer[ready_idx][5:1] == `LBU ||
                                                      ls_buffer[ready_idx][5:1] == `LH || ls_buffer[ready_idx][5:1] == `LHU ||
                                                      ls_buffer[ready_idx][5:1] == `LW);
// wire ready_st_inst = ready_idx == 4'b1111 ? 1'b0 : (ls_buffer[ready_idx][5:1] == `SB || ls_buffer[ready_idx][5:1] == `SH ||
//                                                       ls_buffer[ready_idx][5:1] == `SW);

assign submit_valid = ongoing_idx != 4'b1111 && ls_done_in;
assign submit_tag = submit_valid ? getTag(ongoing_idx) : `None;
assign submit_val = submit_valid ? ld_val : 32'b0;

assign activate_cache = ready_idx != 4'b1111 && !ls_buffer[ready_idx][142];
assign r_nw_out = ready_ld_inst;
assign type_out = getType(ls_buffer[ready_idx][5:1]);
assign st_val = ls_buffer[ready_idx][45:14]; // vk
assign ls_addr = ls_buffer[ready_idx][141:110] + ls_buffer[ready_idx][77:46]; // imm + vj

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < 10; i = i + 1) begin
      ls_buffer[i] <= 143'b0;
    end
    ongoing_idx <= 4'b1111;
    i <= 4'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    if (cdb_active) begin // update
      for (i = 0; i < 10; i = i + 1) begin
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

    if (free_idx != 4'b1111) begin // push
      rs_buffer[free_idx] <= {1'b0, imm, addr, vj, vk, qj, actual_qk, op, 1'b1};
    end

    if (activate_cache) begin // store the idx to ongoing_idx
      ongoing_idx <= ready_idx;
    end

    if (submit_valid && ongoing_idx != 4'b1111) begin // pop
      rs_buffer[ongoing_idx] <= 143'b0;
      ongoing_idx <= 4'b1111;
    end
  end
end

endmodule