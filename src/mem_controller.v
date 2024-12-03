`include "src/macros.v"

module MemController(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  input wire [7:0] mem_read,
  output wire [7:0] mem_write,
  output wire [31:0] mem_addr,
  output wire r_nw_out,          // read/write select (read: 1, write: 0)

  input wire [31:0] addr_in_icache,
  input wire [31:0] data_in_icache,
  input wire r_nw_in_icache,
  input wire [2:0] type_in_icache, // [1:0]: 00 for word, 01 for half-word, 10 for byte; [2]: 1 for signed, 0 for unsigned
  input wire activate_in_icache,

  input wire [31:0] addr_in_lsb,
  input wire [31:0] data_in_lsb,
  input wire r_nw_in_lsb,
  input wire [2:0] type_in_lsb, // [1:0]: 00 for word, 01 for half-word, 10 for byte; [2]: 1 for signed, 0 for unsigned
  input wire activate_in_lsb,

  output wire [31:0] data_out,
  output reg data_available, // 1 for data_out is valid
  output reg [1:0] task_src, // 00: none, 01: lsb, 10: icache
  output wire icache_block, // 1 for icache pending
  //output wire working, // 1 for working

  input wire io_buffer_full
);

wire [31:0] addr_in = activate_in_lsb ? addr_in_lsb : addr_in_icache;
wire [31:0] data_in = activate_in_lsb ? data_in_lsb : data_in_icache;
wire r_nw_in = activate_in_lsb ? r_nw_in_lsb : r_nw_in_icache;
wire [2:0] type_in = activate_in_lsb ? type_in_lsb : type_in_icache;
wire activate_in  = activate_in_lsb || activate_in_icache;
// 00: none, 01: lsb, 10: icache
wire [1:0] task_src_in = activate_in_lsb ? 2'b01 : (activate_in_icache ? 2'b10 : 2'b00);

reg [31:0] data;
reg [31:0] addr;
reg r_nw;
// reg r_nw_buf;
reg block;
reg [2:0] type_;
reg [1:0] state;

task Monitor;
input [1:0] task_src_in;
input [31:0] addr_in;
input [31:0] data_in;
input [2:0] type_in;
input r_nw_in;

begin
  if (task_src_in == 2'b01) begin
    case (type_in)
    3'b000: // W
    if (r_nw_in) begin
      $display("LW addr=%0h, data=%0h", addr_in, data_in);
    end
    else begin
      $display("SW addr=%0h, data=%0h", addr_in, data_in);
    end

    3'b001: // HU
    if (r_nw_in) begin
      $display("LHU addr=%0h, data=%0h", addr_in, data_in);
    end
    else begin
      $display("SH addr=%0h, data=%0h", addr_in, data_in);
    end

    3'b010: // BU
    if (r_nw_in) begin
      $display("LBU addr=%0h, data=%0h", addr_in, data_in);
    end
    else begin
      $display("SB addr=%0h, data=%0h", addr_in, data_in);
    end

    3'b101: // H
    begin
      $display("LH addr=%0h, data=%0h", addr_in, data_in);
    end

    3'b110: // B
    begin
      $display("LB addr=%0h, data=%0h", addr_in, data_in);
    end
    endcase
  end
end
endtask

// assign working = state != 2'b0;

wire called = rdy_in && activate_in && !io_buffer_full && !data_available;

assign icache_block = block || activate_in_lsb;

assign r_nw_out = (called && state == 2'b0) ? r_nw_in : r_nw;

assign mem_addr = (called && state == 2'b0) ? addr_in : addr;

function [7:0] memWrite;
  input [1:0] state_arg;
  input r_nw_arg;
  input [31:0] data_arg;
  input called_arg;
  input [7:0] data_in_arg;

  begin
    if (r_nw_arg) begin
      memWrite = 8'b0;
    end
    else begin
      if (called_arg && state_arg == 2'b0) begin
        memWrite = data_in_arg;
      end
      else begin
        // memWrite = data_arg[7 + (state_arg << 3) : (state_arg << 3)];
        case (state_arg)
         2'b01:
         begin
          memWrite = data_arg[15:8];
         end
         2'b10:
          begin
            memWrite = data_arg[23:16];
          end
          2'b11:
          begin
            memWrite = data_arg[31:24];
          end
        endcase
      end
    end
  end

endfunction

assign mem_write = memWrite(state, r_nw_out, data, called, data_in[7:0]);

// assign mem_write = r_nw_out ? 8'b0 : ((called && state == 2'b0) ? data_in[7:0] : data[7 + state * 8 : state * 8]);

// 000: LW, 001: LHU, 010: LBU, 101: LH, 110: LB
// assign data_out = type_[2] ?
//                             (type_[1:0] == 2'b01 ?
//                                                   {16'b0, mem_read, data[7:0]} :                                 // LHU
//                                                   {24'b0, mem_read}) :                                           // LBU
//                             (type_[1:0] == 2'b00 ?
//                                                   {mem_read, data[23:0]} :                                       // LW
//                                                   (type_[1:0] == 2'b01 ?
//                                                                         {{16{mem_read[7]}}, mem_read, data[7:0]} : // LH
//                                                                         {{24{mem_read[7]}}, mem_read}));           // LB

function [31:0] getDataOut;
input [2:0] type_arg;
input [7:0] mem_read;
input [31:0] data;

begin
  case (type_arg)
  3'b000: // LW
  begin
    getDataOut = {mem_read, data[23:0]};
  end
  3'b001: // LHU
  begin
    getDataOut = {16'b0, mem_read, data[7:0]};
  end
  3'b010: // LBU
  begin
    getDataOut = {24'b0, mem_read};
  end
  3'b101: // LH
  begin
    getDataOut = {{16{mem_read[7]}}, mem_read, data[7:0]};
  end
  3'b110: // LB
  begin
    getDataOut = {{24{mem_read[7]}}, mem_read};
  end
  default: // exception
  begin
    // $display("Error: invalid ls type: %d", type_arg);
    // $finish;
    getDataOut = 32'b0;
  end
  endcase
end
endfunction

assign data_out = getDataOut(type_, mem_read, data);

always @(posedge clk_in) begin
  if (rst_in) begin
    data_available <= 1'b0;
    data <= 32'b0;
    addr <= 32'b0;
    r_nw <= 1'b1;
    // r_nw_buf <= 1'b1;
    type_ <= 3'b0;
    state <= 2'b0;
    block <= 1'b0;
    task_src <= 2'b00;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    if (data_available) begin

      // if (addr == 32'h30004 && type_[1:0] == 2'b10 && !r_nw_buf) begin // sb 0x30004 (halt)
      //   $finish;
      // end

      data_available <= 1'b0;
      block <= 1'b0;
      type_ <= 3'b0;
      task_src <= 2'b00;
    end
    else begin
      case (state)
      2'b00: // free state
      begin
        if (called) begin

          // Monitor(task_src_in, addr_in, data_in, type_in, r_nw_in);

          if (activate_in_lsb) begin // icache block
            block <= 1'b1;
          end

          if (type_in[1:0] == 2'b10) begin // byte operation
            state <= 2'b00;
            data_available <= 1'b1;
            type_ <= type_in;
            addr <= addr_in;
            // r_nw <= r_nw_in;
          end
          else begin // word or half-word operation
            state <= 2'b01;
            addr <= addr_in + 1;
            r_nw <= r_nw_in;
            type_ <= type_in;
            if (!r_nw_in) begin // write
              data <= data_in;
            end
          end
          // r_nw_buf <= r_nw_in;
          task_src <= task_src_in;

        end
      end

      2'b01:
      begin
        if (r_nw) begin
          data[7:0] <= mem_read;
        end
        if (type_[1:0] == 2'b01) begin // half-word opertion
          addr <= 32'b0;
          r_nw <= 1'b1;
          //type_ <= 3'b0;
          data_available <= 1'b1;
          state <= 2'b00;
        end
        else begin // word operation
          state <= 2'b10;
          addr <= addr + 1;
        end
      end

      2'b10:
      begin
        if (r_nw) begin
          data[15:8] <= mem_read;
        end
        state <= 2'b11;
        addr <= addr + 1;
      end

      2'b11:
      begin
        if (r_nw) begin
          data[23:16] <= mem_read;
        end
        state <= 2'b00;
        addr <= 32'b0;
        r_nw <= 1'b1;
        //type_ <= 3'b0;
        data_available <= 1'b1;
      end
      endcase
    end

  end
end

endmodule