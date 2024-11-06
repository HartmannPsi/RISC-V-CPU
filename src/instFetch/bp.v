`inlcude "../macros.v"

module BranchPredictor(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // decoded inst from decoder
  input wire branch,
  input wire [31:0] imm,

  // now pc
  input wire [31:0] pc_in,

  // broadcasted value from cdb
  input wire [31:0] cdb_val,
  // broadcasted addr from cdb
  input wire [31:0] cdb_addr,
  // broadcast available
  input wire cdb_active,
  
  // whether former prediction is wrong
  output wire predict_fail,
  // fail addr to reset
  output wire [31:0] fail_addr,

  // whether to branch
  output wire need_branch,
  // branch target
  output wire [31:0] branch_addr
);

reg [64:0] bp_queue [0:`BP_SIZE-1]; // {src_addr, fail_addr, br}
reg [32:0] bp_fsm[0:`BP_SIZE-1]; // [32]: used [31:2] :src_addr, [1:0]: 00: SNT, 01: WNT, 10: WT, 11: ST
reg [`BP_SIZE_W - 1:0] front, rear;

function [`BP_SIZE_W - 1:0] distribute // get the idx of fsm
  input [31:0] src_addr;

  for (i = 0; i < `BP_SIZE; i = i + 1) begin
    if (bp_fsm[i][31:2] == src_addr[31:2]) begin
      distribute = i;
      return;
    end
    else if (!bp_fsm[i][32]) begin
      bp_fsm[i] = {1'b1, src_addr[31:2], 2'b01};
      distribute = i;
      return;
    end
  end
endfunction

wire need_predict = branch && rdy_in;
assign need_branch = need_predict ? bp_fsm[distribute(pc_in)][1:0] > 2'b01 : 1'b0;
assign branch_addr = need_branch ? pc_in + imm : 32'b0;
wire [31:0] fail_addr = need_predict ? (need_branch ? pc_in + 4 : pc_in + imm) : 32'b0;

wire[31:0] head_src_addr = bp_queue[front][64:33], head_fail_addr = bp_queue[front][32:1];
wire head_br = bp_queue[front][0];
wire calc_res = cdb_val[0];

assign predict_fail = cdb_active && head_src_addr == cdb_addr && head_br != calc_res;
assign fail_addr = predict_fail ? head_fail_addr : 32'b0;

wire [`BP_SIZE_W - 1:0] idx_of_head = distribute(head_src_addr);

always @(posedge clk_in) begin
    if (rst_in) begin
      front <= 0;
      rear <= 0;
      for (i = 0; i < `BP_SIZE; i = i + 1) begin
        bp_queue[i] = 65'b0;
        bp_fsm[i] = 33'b0;
      end
    end
    else if (!rdy_in) begin
      // pause
    end
    else begin
      if (need_predict) begin // push
        bp_queue[rear] <= {pc_in, fail_addr, need_branch};
        if (rear == `BP_SIZE - 1) begin
          rear <= 0;
        end
        else begin
          rear <= rear + 1;
        end
      end

      if (cdb_addr == head_src_addr) begin // pop

        // update the fsm state
        if (calc_res) begin // need to branch actually
          if (bp_fsm[idx_of_head][1:0] != 2'b11) begin
            bp_fsm[idx_of_head][1:0] <= bp_fsm[idx_of_head][1:0] + 1;
          end
        end
        else begin // no need to branch actually
          if (bp_fsm[idx_of_head][1:0] != 2'b00) begin
            bp_fsm[idx_of_head][1:0] <= bp_fsm[idx_of_head][1:0] - 1;
          end
        end

        // pop queue
        bp_queue[front] <= 65'b0;
        if (front == `BP_SIZE - 1) begin
          front <= 0;
        end
        else begin
          front <= front + 1;
        end
      end
    end
end

endmodule