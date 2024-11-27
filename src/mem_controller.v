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
  output wire icache_block, // 1 for icache pending

  input wire io_buffer_full
);

wire [31:0] addr_in = activate_in_lsb ? addr_in_lsb : addr_in_icache;
wire [31:0] data_in = activate_in_lsb ? data_in_lsb : data_in_icache;
wire r_nw_in = activate_in_lsb ? r_nw_in_lsb : r_nw_in_icache;
wire [2:0] type_in = activate_in_lsb ? type_in_lsb : type_in_icache;
wire activate_in  = activate_in_lsb || activate_in_icache;

reg [31:0] data;
reg [31:0] addr;
reg r_nw;
reg block;
reg [2:0] type_;
reg [1:0] state;

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

assign mem_write = memWrite(state, r_nw, data, called, data_in[7:0]);

// assign mem_write = r_nw_out ? 8'b0 : ((called && state == 2'b0) ? data_in[7:0] : data[7 + state * 8 : state * 8]);

// 000: LW, 001: LH, 010: LB, 101: LHU, 110: LBU
assign data_out = type_[2] ?
                            (type_[1:0] == 2'b01 ?
                                                  {16'b0, mem_read, data[7:0]} :                                 // LHU
                                                  {24'b0, mem_read}) :                                           // LBU
                            (type_[1:0] == 2'b00 ?
                                                  {mem_read, data[23:0]} :                                       // LW
                                                  (type_[1:0] == 2'b01 ?
                                                                        {{16{mem_read[7]}}, mem_read, data[7:0]} : // LH
                                                                        {{24{mem_read[7]}}, mem_read}));           // LB

always @(posedge clk_in) begin
  if (rst_in) begin
    data_available <= 1'b0;
    data <= 32'b0;
    addr <= 32'b0;
    r_nw <= 1'b0;
    type_ <= 3'b0;
    state <= 2'b0;
    block <= 1'b0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin

    if (data_available) begin
      data_available <= 1'b0;
      block <= 1'b0;
    end
    else begin
      case (state)
      2'b00: // free state
      begin
        if (called) begin

          if (activate_in_lsb) begin // icache block
            block <= 1'b1;
          end

          if (type_in[1:0] == 2'b10) begin // byte operation
            state <= 2'b00;
            data_available <= 1'b1;
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

        end
      end

      2'b01:
      begin
        if (r_nw) begin
          data[7:0] <= mem_read;
        end
        if (type_[1:0] == 2'b01) begin // half-word opertion
          addr <= 32'b0;
          r_nw <= 1'b0;
          type_ <= 3'b0;
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
        r_nw <= 1'b0;
        type_ <= 3'b0;
        data_available <= 1'b1;
      end
      endcase
    end

  end
end

endmodule