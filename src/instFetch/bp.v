`define BP_SIZE_W 4
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
  
  // whether former prediction is wrong
  output wire predict_fail,

  // whether to branch
  output wire need_branch,
  // branch target
  output wire [31:0] branch_addr
);



endmodule