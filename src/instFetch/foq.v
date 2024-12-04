`include "src/macros.v"

module FpOpQueue(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // whether the inst fetched is valid
  input wire inst_in_valid,

  // inst fetched
  input wire [4:0] op_in,
  input wire [4:0] rd_in,
  input wire [4:0] rs1_in,
  input wire [4:0] rs2_in,
  input wire [31:0] imm_in,
  input wire branch_in,
  input wire ls_in,
  input wire use_imm_in,
  input wire jalr_in,

  // addr of inst fetched
  input wire [31:0] addr_in,

  // inst launched
  output wire [4:0] op_out,
  output wire [4:0] rd_out,
  output wire [4:0] rs1_out,
  output wire [4:0] rs2_out,
  output wire [31:0] imm_out,
  output wire branch_out,
  output wire ls_out,
  output wire use_imm_out,
  output wire jalr_out,

  // addr of inst launched
  output wire [31:0] addr_out,

  // whether the inst launched is valid
  output wire inst_out_valid,

  // whether the launching is successful
  input wire launch_fail,
  
  // whether queue is full
  output wire foq_full,

  // clear the queue
  input wire predict_fail
);

reg [87:0] op_queue[`FOQ_SIZE - 1:0];
reg [`FOQ_SIZE_W - 1:0] front, rear;
integer i;

assign inst_out_valid = !(front == rear); // nonempty
assign foq_full = (front == rear + 1) || (front == 0 && rear == `FOQ_SIZE - 1); // full

assign {op_out, rd_out, rs1_out, rs2_out, imm_out,
          branch_out, ls_out, use_imm_out,
          jalr_out, addr_out} = inst_out_valid ? op_queue[front] : 88'b0; // output if nonempty

wire [87:0] inst_total_in = {op_in, rd_in, rs1_in,
          rs2_in, imm_in, branch_in, ls_in,
          use_imm_in, jalr_in, addr_in};

always @(posedge clk_in) begin
  if (rst_in || predict_fail) begin
    for (i = 0; i < `FOQ_SIZE; i = i + 1) begin
      op_queue[i] <= 88'b0;
    end
    front <= 0;
    rear <= 0;
    //i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    if (inst_out_valid && !launch_fail) begin // pop
      op_queue[front] <= 88'b0;
      if (front == `FOQ_SIZE - 1) begin
        front <= 0;
      end
      else begin
        front <= front + 1;
      end
    end

    if (!foq_full) begin
      if (inst_in_valid) begin // push
        op_queue[rear] <= inst_total_in;
        if (rear == `FOQ_SIZE - 1) begin
          rear <= 0;
        end
        else begin
          rear <= rear + 1;
        end
      end
    end

  end
end

endmodule