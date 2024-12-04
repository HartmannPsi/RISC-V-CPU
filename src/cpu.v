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
wire [4:0] cdb_rd_idx;

integer cycle_cnt; // just for debugging


// wire r_nw_ram_ctrl;
// wire [31:0] mem_addr_ram_ctrl;
// wire [7:0] din_mem_ctrl;
// wire [7:0] dout_mem_ctrl;

wire [3:0] push_tag_rob;

wire [31:0] st_val_lsb;
wire [31:0] ls_addr_lsb;
wire r_nw_lsb;
wire [2:0] type_lsb;
wire activate_mem_lsb;

wire predict_fail_bp;

// ram memory(
//   .clk_in(clk_in),
//   .en_in(rdy_in),
//   .r_nw_in(r_nw_ram_ctrl),
//   .a_in(mem_addr_ram_ctrl[17-1:0]),
//   .d_in(din_mem_ctrl),
//   .d_out(dout_mem_ctrl)
// );

wire [31:0] addr_ctrl_icache;
wire available_ctrl;
wire [31:0] data_in_ctrl_icache = 32'b0;
wire r_nw_ctrl_icache = 1'b1;
wire [2:0] type_ctrl_icache = 3'b001; // LHU
// fixed in icache: read only, LW mode
wire [31:0] data_out_ctrl;
wire icache_hit;
wire icache_block;
wire [1:0] task_src_ctrl;
wire not_mem_wr;
assign mem_wr = ~not_mem_wr;

MemController mem_ctrl(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .mem_read(mem_din),
  .mem_write(mem_dout),
  .mem_addr(mem_a),
  .r_nw_out(not_mem_wr),

  // .addr_in(addr_ctrl_icache | ls_addr_lsb),
  // .data_in(data_in_ctrl_icache | st_val_lsb),
  // .r_nw_in(r_nw_ctrl_icache | r_nw_lsb),
  // .type_in(type_ctrl_icache | type_lsb),
  // .activate_in(~icache_hit | activate_mem_lsb),
  .addr_in_icache(addr_ctrl_icache),
  .data_in_icache(data_in_ctrl_icache),
  .r_nw_in_icache(r_nw_ctrl_icache),
  .type_in_icache(type_ctrl_icache),
  .activate_in_icache(~icache_hit),

  .addr_in_lsb(ls_addr_lsb),
  .data_in_lsb(st_val_lsb),
  .r_nw_in_lsb(r_nw_lsb),
  .type_in_lsb(type_lsb),
  .activate_in_lsb(activate_mem_lsb),

  .data_out(data_out_ctrl),
  .data_available(available_ctrl),
  .task_src(task_src_ctrl),
  .icache_block(icache_block),

  .io_buffer_full(io_buffer_full)
);

wire [31:0] addr_icache_prcs;
wire [31:0] data_icache_prcs;
wire inst_length_icache;

InstCache icache(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .addr_in(addr_icache_prcs),
  .data_out(data_icache_prcs),
  .inst_length(inst_length_icache),

  .rewrite_data(data_out_ctrl),
  .addr_out(addr_ctrl_icache),
  .write_enable(available_ctrl && task_src_ctrl == 2'b10),
  .icache_block(icache_block),

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
  .inst_length(inst_length_icache),
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
wire [31:0] addr_foq;
wire inst_valid_foq;
wire launch_fail_lsb;
wire launch_fail_rs;

FpOpQueue foq(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .inst_in_valid(decode_valid_prcs),

  .op_in(op_push),
  .rd_in(rd_push),
  .rs1_in(rs1_push),
  .rs2_in(rs2_push),
  .imm_in(imm_push),
  .branch_in(branch_op_push),
  .ls_in(ls_op_push),
  .use_imm_in(use_imm_op_push),
  .jalr_in(jalr_op_push),

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

  .launch_fail(launch_fail_rs | launch_fail_lsb), // TODO

  .foq_full(foq_full_foq),

  .predict_fail(predict_fail_bp)
);

BranchPredictor bp(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .branch(branch_op_push),
  .imm(imm_push),
  .inst_length(inst_length_icache),
  .foq_full(foq_full_foq),
  .pc_in(addr_icache_prcs),

  .cdb_val(cdb_val),
  .cdb_addr(cdb_addr),
  .cdb_active(cdb_active),

  .predict_fail(predict_fail_bp),
  .fail_addr(fail_addr_bp),

  .need_branch(branch_bp),
  .branch_addr(branch_addr_bp)
);

// wire [3:0] choose_tag_rs;
wire [4:0] rs1_idx_rs;
wire [4:0] rs2_idx_rs;
wire [4:0] rd_idx_rs;
wire inst_valid_rs;
wire [31:0] submit_val_rs;
wire [3:0] submit_tag_rs;
wire submit_valid_rs;
wire [31:0] vj_regfile;
wire [31:0] vk_regfile;
wire [3:0] qj_regfile;
wire [3:0] qk_regfile;

ReservationStation rs(
  .clk_in(clk_in),
  .rst_in(rst_in | predict_fail_bp),
  .rdy_in(rdy_in),

  .op(op_foq),
  .branch_in(branch_foq),
  .ls(ls_foq),
  .use_imm(use_imm_foq),
  .rd(rd_foq),
  .rs1(rs1_foq),
  .rs2(rs2_foq),
  .imm(imm_foq),
  .jalr(jalr_foq),
  .addr(addr_foq),
  .inst_valid(inst_valid_foq),

  .cdb_tag(cdb_tag),
  .cdb_val(cdb_val),
  .cdb_addr(cdb_addr),
  .cdb_active(cdb_active),

  .launch_fail(launch_fail_rs),
  .choose_tag(push_tag_rob),
  .rs1_idx(rs1_idx_rs),
  .rs2_idx(rs2_idx_rs),
  .rd_idx(rd_idx_rs),
  .inst_valid_out(inst_valid_rs),

  .submit_val(submit_val_rs),
  .submit_tag(submit_tag_rs),
  .submit_valid(submit_valid_rs),

  .jalr_done(jalr_compute_alu),
  .jalr_addr(jalr_addr_alu),

  .vj(vj_regfile),
  .vk(vk_regfile),
  .qj(qj_regfile),
  .qk(qk_regfile)
);

// wire [3:0] choose_tag_lsb;
wire [4:0] rs1_idx_lsb;
wire [4:0] rs2_idx_lsb;
wire [4:0] rd_idx_lsb;
wire inst_valid_lsb;
wire [31:0] submit_val_lsb;
wire [3:0] submit_tag_lsb;
wire submit_valid_lsb;

LoadStoreBuffer lsb(
  .clk_in(clk_in),
  .rst_in(rst_in | predict_fail_bp),
  .rdy_in(rdy_in),

  .op(op_foq),
  .branch_in(branch_foq),
  .ls(ls_foq),
  .use_imm(use_imm_foq),
  .rd(rd_foq),
  .rs1(rs1_foq),
  .rs2(rs2_foq),
  .imm(imm_foq),
  .jalr(jalr_foq),
  .addr(addr_foq),
  .inst_valid(inst_valid_foq),

  .cdb_tag(cdb_tag),
  .cdb_val(cdb_val),
  .cdb_addr(cdb_addr),
  .cdb_active(cdb_active),

  .launch_fail(launch_fail_lsb),
  .choose_tag(push_tag_rob),
  .rs1_idx(rs1_idx_lsb),
  .rs2_idx(rs2_idx_lsb),
  .rd_idx(rd_idx_lsb),
  .inst_valid_out(inst_valid_lsb),

  .submit_val(submit_val_lsb),
  .submit_tag(submit_tag_lsb),
  .submit_valid(submit_valid_lsb),

  .st_val(st_val_lsb),
  .ls_addr(ls_addr_lsb),
  .r_nw_out(r_nw_lsb),
  .type_out(type_lsb),
  .activate_cache(activate_mem_lsb),

  .ld_val(data_out_ctrl),
  .ls_done_in(available_ctrl && task_src_ctrl == 2'b01),

  .vj(vj_regfile),
  .vk(vk_regfile),
  .qj(qj_regfile),
  .qk(qk_regfile)
);

RegFile reg_file(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .rd(rd_idx_rs | rd_idx_lsb),
  .rs1(rs1_idx_rs | rs1_idx_lsb),
  .rs2(rs2_idx_rs | rs2_idx_lsb),
  .rd_tag(push_tag_rob),
  .inst_valid(inst_valid_rs | inst_valid_lsb),

  .cdb_tag(cdb_tag),
  .cdb_val(cdb_val),
  .cdb_addr(cdb_addr),
  .cdb_rd_idx(cdb_rd_idx),
  .cdb_active(cdb_active),

  .submit_val_rs(submit_val_rs),
  .submit_tag_rs(submit_tag_rs),
  .submit_valid_rs(submit_valid_rs),

  .vj(vj_regfile),
  .vk(vk_regfile),
  .qj(qj_regfile),
  .qk(qk_regfile),

  .predict_fail(predict_fail_bp)
);

ReorderBuffer rob(
  .clk_in(clk_in),
  .rst_in(rst_in | predict_fail_bp),
  .rdy_in(rdy_in),
  .push_src_addr(addr_foq),
  .push_valid(inst_valid_foq & !(launch_fail_rs | launch_fail_lsb)),
  .push_rd_idx(rd_idx_rs | rd_idx_lsb),

  .submit_tag_rs(submit_tag_rs),
  .submit_val_rs(submit_val_rs),
  .submit_valid_rs(submit_valid_rs),

  .submit_tag_lsb(submit_tag_lsb),
  .submit_val_lsb(submit_val_lsb),
  .submit_valid_lsb(submit_valid_lsb),

  .predict_fail(predict_fail_bp),

  .push_rob_tag(push_tag_rob),

  .cdb_tag(cdb_tag),
  .cdb_val(cdb_val),
  .cdb_addr(cdb_addr),
  .cdb_rd_idx(cdb_rd_idx),
  .cdb_active(cdb_active)
);

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
        cycle_cnt <= 0;
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
        cycle_cnt <= cycle_cnt + 1;
      end
  end

endmodule