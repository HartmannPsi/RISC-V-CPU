module InstProcessor(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  input wire [31:0] pc,

  output reg [31:0] inst
  //output wire [31:0] next_pc
);

always @(posedge clk_in) begin
  if (rst_in) begin
    inst <= 32'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    // fetch instruction from memory
    ram ram(
      .clk_in(clk_in),
      .en_in(1'b1),
      .r_nw_in(1'b1),
      .a_in(pc[ADDR_WIDTH-1:0]),
      ,
      .d_out(inst[7:0])
    );

    ram ram(
      .clk_in(clk_in),
      .en_in(1'b1),
      .r_nw_in(1'b1),
      .a_in(pc[ADDR_WIDTH-1:0] + 1),
      ,
      .d_out(inst[15:8])
    );

    ram ram(
      .clk_in(clk_in),
      .en_in(1'b1),
      .r_nw_in(1'b1),
      .a_in(pc[ADDR_WIDTH-1:0] + 2),
      ,
      .d_out(inst[23:16])
    );

    ram ram(
      .clk_in(clk_in),
      .en_in(1'b1),
      .r_nw_in(1'b1),
      .a_in(pc[ADDR_WIDTH-1:0] + 3),
      ,
      .d_out(inst[31:24])
    );

  end
end

endmodule