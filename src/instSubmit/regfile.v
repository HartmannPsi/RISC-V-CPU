module RegFile(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  input wire mode,    // 0: foq update, 1: rob update
  input wire [4:0] rd,
  input wire [4:0] rs1,
  input wire [4:0] rs2,
  input wire [3:0] foq_depend,
  input wire [31:0] rob_data,
  input wire [3:0] rob_depend,

  output wire [31:0] vj,
  output wire [31:0] vk,
  output wire [3:0] qj,
  output wire [3:0] qk
);

reg [31:0] reg_file[31:0];
reg [3:0] depend_file[31:0];

assign reg_file[0] = 32'b0;
assign depend_file[0] = 4'b0;

assign vj = (depend_file[rs1] == `None) ? reg_file[rs1] : 32'b0;
assign vk = (depend_file[rs2] == `None) ? reg_file[rs2] : 32'b0;
assign qj = depend_file[rs1];
assign qk = depend_file[rs2];
// assign rd_depend = (!dep_en && !rob_en) ? depend_file[rd] : 0;
// assign rd_en = (!dep_en && !rob_en && depend_file[rd] == `None) ? 1 : 0;

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < 32; i = i + 1) begin
      reg_file[i] <= 32'b0;
      depend_file[i] <= 4'b0;
    end
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    if (mode) begin  // rob update
      for (i = 0; i < 32; i = i + 1) begin
        if (depend_file[i] == rob_depend) begin
          depend_file[i] <= `None;
          reg_file[i] <= rob_data;
        end
      end

    end
    else begin  // foq update
      if (rd != 0) begin
        depend_file[rd] <= foq_depend;
      end
    end
  end
end

endmodule