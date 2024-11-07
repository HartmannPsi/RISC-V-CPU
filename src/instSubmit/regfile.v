`inlcude "../macros.v"

module RegFile(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // inst regs from rs / lsb
  input wire [4:0] rd,
  input wire [4:0] rs1,
  input wire [4:0] rs2,
  input wire [3:0] rd_tag,
  input wire inst_valid,

  // data to update from cdb
  input wire [3:0] cdb_tag,
  input wire [31:0] cdb_val,
  input wire [31:0] cdb_addr,
  input wire cdb_active,

  // data read from regfile
  output wire [31:0] vj,
  output wire [31:0] vk,
  output wire [3:0] qj,
  output wire [3:0] qk
);

reg [31:0] reg_file[31:0];
reg [3:0] depend_file[31:0];
reg [4:0] i;

assign reg_file[0] = 32'b0;
assign depend_file[0] = 4'b0;

assign qj = inst_valid ? depend_file[rs1] : `None;
assign qk = inst_valid ? depend_file[rs2] : `None;

assign vj = (inst_valid && qj == `None) ? reg_file[rs1] : 32'b0;
assign vk = (inst_valid && qk == `None) ? reg_file[rs2] : 32'b0;

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 1; i < 32; i = i + 1) begin
      reg_file[i] <= 32'b0;
      depend_file[i] <= 4'b0;
    end
    i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    if (inst_valid && rd != 5'b0) begin // update depend of rd according to inst launched
      depend_file[rd] <= rd_tag;
    end

    if (cdb_active) begin // update depend & val of rd according to inst submitted
      for (i = 1; i < 32; i = i + 1) begin
        if (depend_file[i] == cdb_tag) begin
          reg_file[i] <= cdb_val;
          depend_file[i] <= `None;
        end
      end
    end
  end
end

endmodule