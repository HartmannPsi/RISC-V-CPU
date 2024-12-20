`include "src/macros.v"

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
  input wire rob_full,

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

  // ls ops to mem_controller
  output wire [31:0] st_val,
  output wire [31:0] ls_addr,
  output wire r_nw_out, // 1: read, 0: write
  output wire [2:0] type_out, // [1:0]: 00: word, 01: half-word, 10: byte, [2]: 1: signed, 0: unsigned
  output wire activate_cache,

  // ls ops from mem_controller
  input wire [31:0] ld_val,
  // input wire mem_working,
  input wire ls_done_in,


  // data from regfile
  input wire [31:0] vj,
  input wire [31:0] vk,
  input wire [3:0] qj,
  input wire [3:0] qk
);

reg [146:0] ls_buffer[9:0]; // {submit_tag, ls_ready, imm, addr, vj, vk, qj, qk, op, busy}
reg [3:0] i, front, rear;
// reg [3:0] ongoing_idx;
// reg pending;

wire empty = front == rear;
wire full = front == rear + 1 || (front == 0 && rear == 9);

function [3:0] getFreeBuf;
  input full;
  input [3:0] rear;
  // begin
  //   for (i = 0; i < 10; i = i + 1) begin
  //     if (!ls_buffer[i][0]) begin
  //       getFreeBuf = i;
  //       return;
  //     end
  //   end
  //   getFreeBuf = 4'b1111;
  // end
  begin
    if (full) begin
      getFreeBuf = 4'b1111;
    end
    else begin
      getFreeBuf = rear;
    end
  end
endfunction

function [3:0] getReadyBuf;
  input empty;
  input [3:0] front;
  // begin
  //   for (i = 0; i < 10; i = i + 1) begin
  //     if (ls_buffer[i][0] && ls_buffer[i][13:10] == `None &&
  //               ls_buffer[i][9:6] == `None) begin // busy && qj == None && qk == None
  //       getReadyBuf = i;
  //       return;
  //     end
  //   end
  //   getReadyBuf = 4'b1111;
  // end
  begin
    if (empty) begin
      getReadyBuf = 4'b1111;
    end
    else begin
      getReadyBuf = front;
    end
  end
endfunction

function [3:0] getTag;
  input [3:0] id;
  begin
    if (id < 10) begin
      getTag = id + 4'b0100;
    end
    else begin
      getTag = `None;
    end
  end
endfunction

function [3:0] getTagReverse;
  input [3:0] tag;
  begin
    if (tag >= 4'b0100 && tag < 4'b1110) begin
      getTagReverse = tag - 4'b0100;
    end
    else begin
      getTagReverse = 4'b1111;
    end
  end
endfunction

// function buf_full
//   begin
//     for (i = 0; i < 10; i = i + 1) begin
//       if (!ls_buffer[i][0]) begin
//         buffer_full = 1'b0;
//         return;
//       end
//     end
//     buffer_full = 1'b1;
//   end
// endfunction

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
wire buffer_full = full;
assign launch_fail = inst_receive && buffer_full;

wire [3:0] free_idx = buffer_full ? 4'b1111 : (inst_receive ? getFreeBuf(full, rear) : 4'b1111);

wire [3:0] actual_qk = input_ld_inst ? `None : qk;

function CDBReceive;
input [3:0] push_tag;
input [3:0] cdb_tag;
input cdb_active;

begin
  CDBReceive = cdb_active && push_tag != `None && push_tag == cdb_tag;
end
endfunction

wire [31:0] push_vj = CDBReceive(qj, cdb_tag, cdb_active) ? cdb_val : vj;
wire [31:0] push_vk = CDBReceive(actual_qk, cdb_tag, cdb_active) ? cdb_val : vk;
wire [3:0] push_qj = CDBReceive(qj, cdb_tag, cdb_active) ? `None : qj;
wire [3:0] push_qk = CDBReceive(actual_qk, cdb_tag, cdb_active) ? `None : actual_qk;

// assign choose_tag = inst_receive ? getTag(free_idx) : `None;
assign rs1_idx = rs1;
assign rs2_idx = rs2;
assign rd_idx = input_ld_inst ? rd : 5'b0;
assign inst_valid_out = inst_receive;

wire [3:0] ready_idx = getReadyBuf(empty, front);

wire ready_ld_inst = ready_idx == 4'b1111 ? 1'b0 : (ls_buffer[ready_idx][5:1] == `LB || ls_buffer[ready_idx][5:1] == `LBU ||
                                                      ls_buffer[ready_idx][5:1] == `LH || ls_buffer[ready_idx][5:1] == `LHU ||
                                                      ls_buffer[ready_idx][5:1] == `LW);
// wire ready_st_inst = ready_idx == 4'b1111 ? 1'b0 : (ls_buffer[ready_idx][5:1] == `SB || ls_buffer[ready_idx][5:1] == `SH ||
//                                                       ls_buffer[ready_idx][5:1] == `SW);

wire input_ready = input_ld_inst && (imm + push_vj != 32'h30000); // ld inst && not input inst

assign submit_valid = ready_idx != 4'b1111 && ls_done_in;
assign submit_tag = submit_valid ? ls_buffer[ready_idx][146:143] : `None;
assign submit_val = submit_valid ? ld_val : 32'b0;

assign activate_cache = ready_idx != 4'b1111 && (ls_buffer[ready_idx][142] || (!cdb_active && ls_buffer[ready_idx][146:143] == cdb_tag)) && (ls_buffer[ready_idx][13:10] == `None) && (ls_buffer[ready_idx][9:6] == `None); // ls_ready
assign r_nw_out = ready_ld_inst;
assign type_out = getType(ls_buffer[ready_idx][5:1]);
assign st_val = ls_buffer[ready_idx][45:14]; // vk
assign ls_addr = ls_buffer[ready_idx][141:110] + ls_buffer[ready_idx][77:46]; // imm + vj

task Monitor;
  input [146:0] buffer;
  input [3:0] idx;

begin
  if (idx != 4'b1111 && buffer[109:78] == 32'h194) begin // addr == 0x194
    $display("vk = %0h, imm = %0h, vj = %0h, qj = %0h, qk = %0h", buffer[45:14], buffer[141:110], buffer[77:46], buffer[13:10], buffer[9:6]);
  end
  else if (idx != 4'b1111 && buffer[141:110] + buffer[77:46] == 32'h1c8) begin // imm + vj == 0x1c8
    $display("vk = %0h, qj = %0h, qk = %0h, addr = %0h", buffer[45:14], buffer[13:10], buffer[9:6], buffer[109:78]);
  end
end
endtask

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < 10; i = i + 1) begin
      ls_buffer[i] <= 147'b0;
    end
    // ongoing_idx <= 4'b1111;
    i <= 4'b0;
    front <= 4'b0;
    rear <= 4'b0;
    // pending <= 1'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    // Monitor(ls_buffer[ready_idx], ready_idx);

    if (cdb_active) begin // update
      for (i = 0; i < 10; i = i + 1) begin
        if (ls_buffer[i][0] && ls_buffer[i][13:10] == cdb_tag) begin // qj == cdb_tag
          ls_buffer[i][13:10] <= `None; // qj <= None
          ls_buffer[i][77:46] <= cdb_val; // vj <= cdb_val
        end
        if (ls_buffer[i][0] && ls_buffer[i][9:6] == cdb_tag) begin // qk == cdb_tag
          ls_buffer[i][9:6] <= `None; // qk <= None
          ls_buffer[i][45:14] <= cdb_val; // vk <= cdb_val
        end
      end
    end
    else begin // renew st inst
      if (ls_buffer[ready_idx][146:143] == cdb_tag) begin // tag == cdb_tag
        ls_buffer[ready_idx][142] <= 1'b1; // ls_ready
      end
    end

    if (free_idx != 4'b1111 && !rob_full) begin // push
      ls_buffer[free_idx] <= {choose_tag, input_ready, imm, addr, push_vj, push_vk, push_qj, push_qk, op, 1'b1};
      if (rear == 9) begin
        rear <= 4'b0;
      end
      else begin
        rear <= rear + 1;
      end
    end

    // if (activate_cache) begin // store the idx to ongoing_idx
    //   ongoing_idx <= ready_idx;

    //   // if (mem_working) begin // wait for next submission
    //   //   pending <= 1'b1;
    //   // end
    // end

    if (submit_valid) begin // pop

      // if (pending) begin // wait for next submission
      //   pending <= 1'b0;
      // end
      // else begin
      ls_buffer[ready_idx] <= 147'b0;
      // ongoing_idx <= 4'b1111;
      if (front == 9) begin
        front <= 4'b0;
      end
      else begin
        front <= front + 1;
      end
      // end
      
    end
  end
end

endmodule