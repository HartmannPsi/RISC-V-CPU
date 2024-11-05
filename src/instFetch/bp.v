`define BP_SIZE_W 7
`define BP_SIZE (1 << `BP_SIZE_W)

module BranchPredictor(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // decoded inst from decoder
  input wire [4:0] op,
  input wire branch,
  input wire [4:0] rs1,
  input wire [4:0] rs2,
  input wire [31:0] imm,

  // now pc
  input wire [31:0] pc_in,

  // depends of regs
  input wire [3:0] rs1_tag,
  input wire [3:0] rs2_tag,

  // broadcasted tag from cdb
  input wire [3:0] cdb_tag,
  // broadcasted value from cdb
  input wire [31:0] cdb_val,
  
  // whether former prediction is wrong
  output wire predict_fail,

  // whether to branch
  output wire need_branch,
  // branch target
  output wire [31:0] branch_addr
);

reg [54:0] bp_table [0:`BP_SIZE - 1]; // {op, rs1, rs1_tag, rs2, rs2_tag, imm}
reg [31 - 2 - `BP_SIZE_W:0] pc_tag_table [0:`BP_SIZE - 1];
reg busy [0:`BP_SIZE - 1];
reg [1:0] predict_fst [0:`BP_SIZE - 1]; // 00: SNT, 01: WNT, 10: WT, 11: ST

wire need_predict = branch && rdy_in;
wire [`BP_SIZE_W - 1:0] idx = pc_in[1 + `BP_SIZE_W:2];
wire has_former_fst = busy[idx] && (pc_tag_table[idx] == pc_in[31:2 + `BP_SIZE_W]);

assign need_branch = need_predict ?
          (op == `JAL ? 1'b1 :
          (has_former_fst ? (predict_fst[idx] > 2'b01) : 1'b0)) : 1'b0;

assign branch_addr = need_branch ? pc_in + imm : 32'b0;



always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < `BP_SIZE; i = i + 1) begin
      bp_table[i] <= 55'b0;
      pc_table[i] <= 32'b0;
      busy[i] <= 1'b0;
      predict_fst[i] <= 2'b01; // reset to WNT state
    end
  end
  if (!rdy_in) begin
    // pause
  end
  else begin
    if (need_predict && !has_former_fst && op != `JAL) begin // store predict infos
      busy[idx] <= 1'b1;
      predict_fst[idx] <= 2'b01;
      pc_tag_table[idx] <= pc_in[31:2 + `BP_SIZE_W];
      bp_table[idx] <= {op, rs1, rs1_tag, rs2, rs2_tag, imm};
    end
  end
end


endmodule