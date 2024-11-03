module InstProcessor(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  input wire block,
  input wire branch,
  input wire [31:0] next_pc,
  output reg [31:0] inst_out,
  output wire [31:0] pc_out
);

reg [31:0] pc;
assign pc_out = pc;

always @(posedge clk_in) begin
  if (rst_in) begin
    inst <= 32'b0;
    pc <= 32'b0;
  end
  else if (!rdy_in || block) begin
    // pause
  end
  else begin
    // fetch instruction from memory

  end
end

endmodule