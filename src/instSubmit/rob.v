`include "src/macros.v"

module ReorderBuffer(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // push insts from foq & rs & lsb
  //input wire [3:0] push_tag,
  input wire [31:0] push_src_addr,
  input wire push_valid,
  input wire [4:0] push_rd_idx,

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

  // whether rob is full
  output wire rob_full,

  // the tag in rob of the inst pushed
  output wire [3:0] push_rob_tag,

  // cdb broadcast value
  output wire [3:0] cdb_tag,
  output wire [31:0] cdb_val,
  output wire [31:0] cdb_addr,
  output wire [4:0] cdb_rd_idx,
  output wire cdb_active
);

// TODO: pause when rob full

reg [73:0] rob_queue[(1 << `ROB_SIZE_W) - 1:0]; // {rd, tag, val, addr, solved}
reg [`ROB_SIZE_W - 1:0] front, rear;
reg [`ROB_SIZE_W - 1:0] i;

assign cdb_rd_idx = rob_queue[front][73:69];
assign cdb_active = rob_queue[front][0];
assign cdb_addr = rob_queue[front][32:1];
assign cdb_val = rob_queue[front][64:33];
assign cdb_tag = rob_queue[front][68:65];
assign push_rob_tag = push_valid ? (rear + 1) : 0; // tag starts from 1, 0 means None
assign rob_full = (front == rear + 1) || (rear == `ROB_SIZE - 1 && front == 0);

integer idx_rs;
integer idx_lsb;

wire [73:0] push_data = {push_rd_idx, push_rob_tag, 32'b0, push_src_addr, 1'b0};

task Monitor;
input [31:0] addr, val;
input [3:0] tag;

begin
  $display("ROB: tag=%0h, addr=%0h, val=%0h", tag, addr, val);
end
endtask

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < (1 << `ROB_SIZE_W) - 1; i = i + 1) begin
      rob_queue[i] <= 74'b0;
    end
    rob_queue[(1 << `ROB_SIZE_W) - 1] <= 74'b0;
    front <= 0;
    rear <= 0;
    // i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    // if (cdb_active) begin
    //   Monitor(cdb_addr, cdb_val, cdb_tag);
    // end

    if (predict_fail) begin // clear queue
      for (i = 0; i < (1 << `ROB_SIZE_W) - 1; i = i + 1) begin
        rob_queue[i] <= 74'b0;
      end
      rob_queue[(1 << `ROB_SIZE_W) - 1] <= 74'b0;
      front <= 0;
      rear <= 0;
    end

    else begin
      if (push_valid && !rob_full) begin // push
        rob_queue[rear] <= push_data;
        if (rear == `ROB_SIZE - 1) begin
          rear <= 0;
        end
        else begin
          rear <= rear + 1;
        end
      end

      if (submit_valid_rs) begin // submit from rs

        // idx_rs = 0;
        // for (i = front; i != rear; i = i + 1) begin : loop_label_1 // traverse

        //   if (!rob_queue[i][0] && rob_queue[i][68:65] == submit_tag_rs) begin // unsolved && tag match
        //     // idx_rs = i;
        //     // disable loop_label_1; // break
        //     rob_queue[i][0] <= 1'b1;
        //     rob_queue[i][64:33] <= submit_val_rs;
        //     idx_rs = idx_rs + 1;

        //     if (submit_tag_rs - 1 == i) begin
        //       $display("YES tag_rs - 1 = i = %0h", i);
        //     end
        //     else begin
        //       $display("NO tag_rs = %0h, i = %0h", submit_tag_rs, i);
        //     end
        //   end
        //   // if (i == `ROB_SIZE - 1) begin
        //   //   i = 0;
        //   // end
        //   // else begin
        //   //   i = i + 1;
        //   // end
        // end

        if (!rob_queue[submit_tag_rs - 1][0] && rob_queue[submit_tag_rs - 1][68:65] == submit_tag_rs) begin // unsolved && tag match
            // idx_rs = i;
            // disable loop_label_1; // break
            rob_queue[submit_tag_rs - 1][0] <= 1'b1;
            rob_queue[submit_tag_rs - 1][64:33] <= submit_val_rs;
            // idx_rs = idx_rs + 1;

            // if (submit_tag_rs - 1 == i) begin
            //   $display("YES tag_rs - 1 = i = %0h", i);
            // end
            // else begin
            //   $display("NO tag_rs = %0h, i = %0h", submit_tag_rs, i);
            // end
        end

        // $display("idx_rs = %0d, submit_tag_rs = %0h", idx_rs, submit_tag_rs);

        // if (idx_rs != -1) begin
        //   rob_queue[idx_rs][0] <= 1'b1;
        //   rob_queue[idx_rs][64:33] <= submit_val_rs;
        // end
        // rob_queue[submit_tag_rs - 1][0] <= 1'b1;
        // rob_queue[submit_tag_rs - 1][64:33] <= submit_val_rs;
      end

      if (submit_valid_lsb) begin // submit from lsb

        // idx_lsb = -1;
        // for (i = front; i != rear; i = i + 1) begin : loop_label_2 // traverse

        //   if (!rob_queue[i][0] && rob_queue[i][68:65] == submit_tag_lsb) begin // unsolved && tag match
        //     // idx_lsb = i;
        //     // disable loop_label_2; // break
        //     rob_queue[i][0] <= 1'b1;
        //     rob_queue[i][64:33] <= submit_val_lsb;

        //     if (submit_tag_lsb - 1 == i) begin
        //       $display("YES tag_lsb - 1 = i = %0h", i);
        //     end
        //     else begin
        //       $display("NO tag_lsb = %0h, i = %0h", submit_tag_lsb, i);
        //     end
        //   end

        //   // if (i == `ROB_SIZE - 1) begin
        //   //   i = 0;
        //   // end
        //   // else begin
        //   //   i = i + 1;
        //   // end
        // end

        if (!rob_queue[submit_tag_lsb - 1][0] && rob_queue[submit_tag_lsb - 1][68:65] == submit_tag_lsb) begin // unsolved && tag match
            // idx_lsb = i;
            // disable loop_label_2; // break
            rob_queue[submit_tag_lsb - 1][0] <= 1'b1;
            rob_queue[submit_tag_lsb - 1][64:33] <= submit_val_lsb;

            // if (submit_tag_lsb - 1 == i) begin
            //   $display("YES tag_lsb - 1 = i = %0h", i);
            // end
            // else begin
            //   $display("NO tag_lsb = %0h, i = %0h", submit_tag_lsb, i);
            // end
        end

        // if (idx_lsb != -1) begin
        //   rob_queue[idx_lsb][0] <= 1'b1;
        //   rob_queue[idx_lsb][64:33] <= submit_val_lsb;
        // end
        // rob_queue[submit_tag_lsb - 1][0] <= 1'b1;
        // rob_queue[submit_tag_lsb - 1][64:33] <= submit_val_rs;
      end

      if (cdb_active) begin // pop
        rob_queue[front] <= 74'b0;
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