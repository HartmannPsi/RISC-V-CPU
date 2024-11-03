module MemController(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  input wire [7:0] mem_read,
  output wire [7:0] mem_write,
  output wire [31:0] mem_addr,
  output wire r_nw_out,          // read/write select (read: 1, write: 0)

  input wire [31:0] addr_in,
  input wire [31:0] data_in,
  input wire r_nw_in,
  input wire [2:0] type_in, // [1:0]: 00 for word, 01 for half-word, 10 for byte; [2]: 1 for signed, 0 for unsigned
  input wire activate_in,
  output wire [31:0] data_out,
  output reg data_available, // 1 for data_out is valid

  input wire io_buffer_full
);

reg [31:0] data;
reg [31:0] addr;
reg r_nw;
reg [2:0] type;
reg [1:0] state;

wire called = rdy_in && activate_in && !io_buffer_full && !data_available;

assign r_nw_out = (called && state == 2'b0) ? r_nw_in : r_nw;

assign mem_addr = (called && state == 2'b0) ? addr_in : addr;

assign mem_write = r_nw_out ? 8'b0 : ((called && state == 2'b0) ? data_in[7:0] : data[7 + state * 8 : state * 8]);

// 000: LW, 001: LH, 010: LB, 101: LHU, 110: LBU
assign data_out = type[2] ?
                            (type[1:0] == 2'b01 ?
                                                  {16'b0, mem_read, data[7:0]} :                                 // LHU
                                                  {24'b0, mem_read}) :                                           // LBU
                            (type[1:0] == 2'b00 ?
                                                  {mem_read, data[23:0]} :                                       // LW
                                                  (type[1:0] == 2'b01 ?
                                                                        {16{mem_read[7]}, mem_read, data[7:0]} : // LH
                                                                        {24{mem_read[7]}, mem_read}));           // LB

always @(posedge clk_in) begin
  if (rst_in) begin
    data_available <= 1'b0;
    data <= 32'b0;
    addr <= 32'b0;
    r_nw <= 1'b0;
    type <= 3'b0;
    state <= 2'b0;
  end
  else if(!rdy_in) begin
    // pause
  end
  else begin

    if (data_available) begin
      data_available <= 1'b0;
    end
    else begin
      case (state)
      2'b00: // free state
      begin
        if (called) begin

          if (type_in[1:0] == 2'b10) begin // byte operation
            state <= 2'b00;
            data_available <= 1'b1;
          end
          else begin // word or half-word operation
            state <= 2'b01;
            addr <= addr_in + 1;
            r_nw <= r_nw_in;
            type <= type_in;
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
        if (type[1:0] == 2'b01) begin // half-word opertion
          addr <= 32'b0;
          r_nw <= 1'b0;
          type <= 3'b0;
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
        type <= 3'b0;
        data_available <= 1'b1;
      end
      endcase
    end

  end
end

endmodule