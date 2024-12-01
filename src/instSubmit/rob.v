`include "src/macros.v"

module ReorderBuffer(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // push insts from foq & rs & lsb
  input wire [3:0] push_tag,
  input wire [31:0] push_src_addr,
  input wire push_valid,

  // submit insts from rs
  input wire [3:0] submit_tag_rs,
  input wire [31:0] submit_val_rs,
  input wire submit_valid_rs,

  // submit insts from lsb
  input wire [3:0] submit_tag_lsb,
  input wire [31:0] submit_val_lsb,
  input wire submit_valid_lsb,

  // clear signal from bp
  input wire predict_fail,

  // cdb broadcast value
  output wire [3:0] cdb_tag,
  output wire [31:0] cdb_val,
  output wire [31:0] cdb_addr,
  output wire cdb_active
);

reg [68:0] rob_queue[`ROB_SIZE - 1:0]; // {tag, val, addr, solved}
reg [`ROB_SIZE_W - 1:0] front, rear;
integer i;

assign cdb_active = rob_queue[front][0];
assign cdb_addr = rob_queue[front][32:1];
assign cdb_val = rob_queue[front][64:33];
assign cdb_tag = rob_queue[front][68:65];

integer idx_rs;
integer idx_lsb;

wire [68:0] push_data = {push_tag, 32'b0, push_src_addr, 1'b0};

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < `ROB_SIZE; i = i + 1) begin
      rob_queue[i] <= 69'b0;
    end
    front <= 0;
    rear <= 0;
    //i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    if (predict_fail) begin // clear queue
      for (i = 0; i < `ROB_SIZE; i = i + 1) begin
        rob_queue[i] <= 69'b0;
      end
      front <= 0;
      rear <= 0;
    end

    else begin
      if (push_valid) begin // push
        rob_queue[rear] <= push_data;
        if (rear == `ROB_SIZE - 1) begin
          rear <= 0;
        end
        else begin
          rear <= rear + 1;
        end
      end

      if (submit_valid_rs) begin // submit from rs

      idx_rs = -1;
        for (i = {28'b0, front}; i != {28'b0, rear}; i = (i == `ROB_SIZE - 1) ? 0 : i + 1) begin : loop_label_1 // traverse

          if (!rob_queue[i][0] && rob_queue[i][68:65] == submit_tag_rs) begin // unsolved && tag match
            idx_rs = i;
            disable loop_label_1; // break
          end

          // if (i == `ROB_SIZE - 1) begin
          //   i = 0;
          // end
          // else begin
          //   i = i + 1;
          // end
        end

        if (idx_rs != -1) begin
          rob_queue[idx_rs][0] <= 1'b1;
          rob_queue[idx_rs][64:33] <= submit_val_rs;
        end
      end

      if (submit_valid_lsb) begin // submit from lsb

        idx_lsb = -1;
        for (i = {28'b0, front}; i != {28'b0, rear}; i = (i == `ROB_SIZE - 1) ? 0 : i + 1) begin : loop_label_2 // traverse

          if (!rob_queue[i][0] && rob_queue[i][68:65] == submit_tag_lsb) begin // unsolved && tag match
            idx_lsb = i;
            disable loop_label_2; // break
          end

          // if (i == `ROB_SIZE - 1) begin
          //   i = 0;
          // end
          // else begin
          //   i = i + 1;
          // end
        end

        if (idx_lsb != -1) begin
          rob_queue[idx_lsb][0] <= 1'b1;
          rob_queue[idx_lsb][64:33] <= submit_val_lsb;
        end
      end

      if (cdb_active) begin // pop
        rob_queue[front] <= 69'b0;
        if (front == `ROB_SIZE - 1) begin
          front <= 0;
        end
        else begin
          front <= front + 1;
        end
      end
    end

  end
end

endmodule