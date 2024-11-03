module InstProcessor(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // cache_hit from icache
  input wire inst_available,
  // inst from icache
  input wire [31:0] inst,
  // pc to icache
  output wire [31:0] fetch_addr,

  // whether to branch from bp
  input wire branch,
  // branch target from bp
  input wire [31:0] branch_addr,

  // whther the inst is valid
  output wire decode_valid,

  // jalr done from cdb
  input wire jalr_done,

  // decoded inst from decoder
  output wire [4:0] op,
  output wire branch,
  output wire ls,
  output wire use_imm,
  output wire [4:0] rd,
  output wire [4:0] rs1,
  output wire [4:0] rs2,
  output wire [31:0] imm,
  output wire jalr
  // Other i/o TODO
);

reg [31:0] pc;
reg cease;

assign fetch_addr = pc;
assign decode_valid = inst_available;

InstDecoder decoder(
  .inst(inst),
  .op(op),
  .branch(branch),
  .ls(ls),
  .use_imm(use_imm),
  .rd(rd),
  .rs1(rs1),
  .rs2(rs2),
  .imm(imm),
  .jalr(jalr)
);

always @(posedge clk_in) begin
  if (rst_in) begin
    pc <= 32'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    if (inst_available) begin // inst is valid
      if (jalr) begin // pause fetching util jalr is done
        // pause
        cease <= 1'b1;
      end
      else if (cease && !jalr_done) begin // pause fetching util jalr is done
        // pause
      end
      else begin // ordinary fetching
        if (branch) begin
          pc <= branch_addr;
        end
        else begin
          pc <= pc + 4;
        end
      end

      if (jalr_done) begin // reset cease
        cease <= 1'b0;
      end
    end

  end
end

endmodule