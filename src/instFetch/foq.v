module FpOpQueue(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  input wire [4:0] op_in,
  input wire [4:0] rd_in,
  input wire [4:0] rs1_in,
  input wire [4:0] rs2_in,
  input wire [31:0] imm_in,
  input wire branch_in,
  input wire ls_in,
  input wire use_imm_in,
  input wire rst_block,

  output wire [4:0] op_out,
  output wire [4:0] rd_out,
  output wire [4:0] rs1_out,
  output wire [4:0] rs2_out,
  output wire [31:0] imm_out,
  output wire branch_out,
  output wire ls_out,
  output wire use_imm_out,
  output wire block_out
  output wire full_out
);

reg block, full;
reg [54:0] op_queue[15:0];
reg [3:0] front, rear;

assign {op_out, rd_out, rs1_out, rs2_out, imm_out, branch_out, ls_out, use_imm_out} = block ? 55'b0 : op_queue[front];
assign block_out = block, full_out = full;

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < 16; i = i + 1) begin
      op_queue[i] <= 55'b0;
    end
    front <= 4'b0;
    rear <= 4'b0;
    block <= 1'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    if (!block) begin // launch inst
      op_queue[front] <= 55'b0;
      front <= front + 1;
      if (op_out == `JALR) begin
        block <= 1'b1;
      end
    end

    if (rst_block) begin
      block <= 1'b0;
    end

    if (full) begin
      if (rst_block) begin
        full <= 1'b0;
      end
    end
    else begin
      op_queue[rear] <= {op_in, rd_in, rs1_in, rs2_in, imm_in, branch_in, ls_in, use_imm_in};
      rear <= rear + 1;

      if (block && rear + 2 == front) begin // will be full next cycle
        full <= 1'b1;
      end
    end
  end
end

endmodule