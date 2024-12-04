`include "src/macros.v"

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
  input wire push_valid,

  // data to update from cdb
  input wire [3:0] cdb_tag,
  input wire [31:0] cdb_val,
  input wire [31:0] cdb_addr,
  input wire [4:0] cdb_rd_idx,
  input wire cdb_active,

  // rs res
  input wire [31:0] submit_val_rs,
  input wire [3:0] submit_tag_rs,
  input wire submit_valid_rs,

  // data read from regfile
  output wire [31:0] vj,
  output wire [31:0] vk,
  output wire [3:0] qj,
  output wire [3:0] qk,

  input wire predict_fail
);

reg [31:0] reg_file[31:0];
reg [3:0] depend_file[31:0];
integer i;

// assign reg_file[0] = 32'b0;
// assign depend_file[0] = 4'b0;

assign qj = inst_valid ? depend_file[rs1] : `None;
assign qk = inst_valid ? depend_file[rs2] : `None;

assign vj = (inst_valid && qj == `None) ? reg_file[rs1] : 32'b0;
assign vk = (inst_valid && qk == `None) ? reg_file[rs2] : 32'b0;

wire [31:0] reg_val = reg_file[15];
wire [3:0] reg_depend = depend_file[15];

task Monitor;
input [31:0] val;
input [3:0] dep;
begin
  $display("val=%0h, dep=%0h", val, dep);
end
endtask

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < 32; i = i + 1) begin
      reg_file[i] <= 32'b0;
      depend_file[i] <= 4'b0;
    end
    //i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else if (predict_fail) begin
    for (i = 0; i < 32; i = i + 1) begin // clear all depends
      depend_file[i] <= 4'b0;
    end
  end
  else begin
    reg_file[0] <= 32'b0;
    depend_file[0] <= 4'b0;

    // if (inst_valid) begin
    //   Monitor(reg_val, reg_depend);
    // end

    if (inst_valid && push_valid && rd != 5'b0) begin // update depend of rd according to inst launched
      depend_file[rd] <= rd_tag;
    end

    // may cause problem !!!!!!!
    // if (submit_valid_rs) begin // update reg_file according to inst submitted
    //   for (i = 1; i < 32; i = i + 1) begin
    //     if (depend_file[i] == submit_tag_rs) begin
    //       reg_file[i] <= submit_val_rs;
    //       depend_file[i] <= `None;
    //     end
    //   end
    // end

    if (cdb_active) begin // update depend & val of rd according to inst submitted
      // for (i = 1; i < 32; i = i + 1) begin
      //   if (depend_file[i] == cdb_tag) begin
      //     reg_file[i] <= cdb_val;
      //     depend_file[i] <= `None;
      //   end
      // end
      if (cdb_rd_idx != 5'b0) begin
        reg_file[cdb_rd_idx] <= cdb_val;
        
        if (cdb_tag == depend_file[cdb_rd_idx]) begin
          depend_file[cdb_rd_idx] <= `None;
        end
      end
    end
  end
end

endmodule