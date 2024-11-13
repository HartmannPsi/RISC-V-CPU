// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire [31:0] cdb_val;
wire [31:0] cdb_addr;
wire cdb_active;
wire [3:0] cdb_tag;


wire r_nw_ram_ctrl;
wire [31:0] mem_addr_ram_ctrl;
wire [7:0] din_mem_ctrl;
wire [7:0] dout_mem_ctrl;

ram memory(
  .clk_in(clk_in),
  .en_in(rdy_in),
  .r_nw_in(r_nw_ram_ctrl),
  .a_in(mem_addr_ram_ctrl[ADDR_WIDTH-1:0]),
  .d_in(din_mem_ctrl),
  .d_out(dout_mem_ctrl)
);

wire [31:0] addr_ctrl_icache;
wire available_ctrl_icache;
wire [31:0] data_in_ctrl_icache = 32'b0;
wire r_nw_ctrl_icache = 1'b1;
wire [2:0] type_ctrl_icache = 3'b000;
// fixed in icache: read only, LW mode
wire [31:0] data_out_ctrl_icache;
wire icache_hit;

MemController mem_ctrl(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .mem_read(dout_mem_ctrl),
  .mem_write(mem_din),
  .mem_addr(mem_addr_ram_ctrl),
  .r_nw_out(r_nw_ram_ctrl),

  .addr_in(addr_ctrl_icache),
  .data_in(data_in_ctrl_icache),
  .r_nw_in(r_nw_ctrl_icache),
  .type_in(type_ctrl_icache),
  .activate_in(~icache_hit),
  .data_out(data_out_ctrl_icache),
  .data_available(available_ctrl_icache),

  .io_buffer_full(io_buffer_full)
);

wire [31:0] addr_icache_prcs;
wire [31:0] data_icache_prcs;

InstCache icache(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .addr_in(addr_icache_prcs),
  .data_out(data_icache_prcs),

  .rewrite_data(data_out_ctrl_icache),
  .addr_out(addr_ctrl_icache),
  .write_enable(available_ctrl_icache),

  .cache_hit(icache_hit)
);

wire [4:0] op_push;
wire branch_op_push;
wire ls_op_push;
wire use_imm_op_push;
wire [4:0] rd_push;
wire [4:0] rs1_push;
wire [4:0] rs2_push;
wire [31:0] imm_push;
wire jalr_op_push;

wire branch_bp;
wire [31:0] branch_addr_bp;
wire predict_fail_bp;
wire [31:0] fail_addr_bp;
wire jalr_compute_alu;
wire [31:0] jalr_addr_alu;
wire decode_valid_prcs;
wire foq_full_foq;

InstProcessor processor(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .inst_available(icache_hit),
  .inst(data_icache_prcs),
  .fetch_addr(addr_icache_prcs),

  .branch(branch_bp),
  .branch_addr(branch_addr_bp),

  .jalr_compute(jalr_compute_alu),
  .jalr_addr(jalr_addr_alu),

  .predict_fail(predict_fail_bp),
  .fail_addr(fail_addr_bp),

  .decode_valid(decode_valid_prcs),

  .foq_full(foq_full_foq),

  .op(op_push),
  .branch_out(branch_op_push),
  .ls(ls_op_push),
  .use_imm(use_imm_op_push),
  .rd(rd_push),
  .rs1(rs1_push),
  .rs2(rs2_push),
  .imm(imm_push),
  .jalr(jalr_op_push)
);

wire [4:0] op_foq;
wire [4:0] rd_foq;
wire [4:0] rs1_foq;
wire [4:0] rs2_foq;
wire [31:0] imm_foq;
wire branch_foq;
wire ls_foq;
wire use_imm_foq;
wire jalr_foq;
wire addr_foq;
wire inst_valid_foq;


FpOpQueue foq(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .inst_in_valid(decode_valid_prcs),

  .op_in(op_push),
  .rd_in(rd),
  .rs1_in(rs1),
  .rs2_in(rs2),
  .imm_in(imm),
  .branch_in(branch_op),
  .ls_in(ls_op),
  .use_imm_in(use_imm_op),
  .jalr_in(jalr_op),

  .addr_in(addr_icache_prcs),

  .op_out(op_foq),
  .rd_out(rd_foq),
  .rs1_out(rs1_foq),
  .rs2_out(rs2_foq),
  .imm_out(imm_foq),
  .branch_out(branch_foq),
  .ls_out(ls_foq),
  .use_imm_out(use_imm_foq),
  .jalr_out(jalr_foq),

  .addr_out(addr_foq),

  .inst_out_valid(inst_valid_foq),

  .inst_out_success(1'b1), // TODO

  .foq_full(foq_full_foq),

  .predict_fail(predict_fail_bp)
);

BranchPredictor bp(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .branch(branch_op_push),
  .imm(imm_push),
  .pc_in(addr_icache_prcs),

  .cdb_val(cdb_val),
  .cdb_addr(cdb_addr),
  .cdb_active(cdb_active),

  .predict_fail(predict_fail_bp),
  .fail_addr(fail_addr_bp),

  .need_branch(branch_bp),
  .branch_addr(branch_addr_bp)
);

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
      
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
      
      end
  end

endmodule