`inlcude "../macros.v"

module InstCache(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // addr get from lsb
  input wire [31:0] addr_in,
  // write data from lsb
  input wire [31:0] data_write,
  input wire r_nw_in, // 1: read, 0: write
  input wire [2:0] type_in, // [1:0]: 00: word, 01: half-word, 10: byte, [2]: 1: signed, 0: unsigned
  input wire activate_cache,

  // read data to lsb
  output wire [31:0] data_read,
  // whether hit cache
  output wire cache_hit

  // data get from ram
  input wire [31:0] miss_data,
  // data to ram
  output wire [31:0] update_data,
  // addr to ram
  output wire [31:0] addr_out,
  // whether to write data to cache
  input wire write_enable,
  output wire r_nw_out // 1: read, 0: write
);

// addr: [31:9]: tag, [8:2]: idx, [1:0]: 2'b00
wire tag = addr_in[31:2 + `DCACHE_ADDR_W];
wire idx = addr_in[1 + `DCACHE_ADDR_W:2];

reg [7:0] cache[`DCACHE_SIZE - 1:0];
reg [31 - 2 - `DCACHE_ADDR_W:0] tags[`DCACHE_SIZE - 1:0];
reg busy[`DCACHE_SIZE - 1:0];
reg update[`DCACHE_SIZE - 1:0];
reg [`DCACHE_SIZE_W - 1:0] i;
reg [2:0] state;

assign cache_hit = activate_cache && busy[idx] && (tags[idx] == tag);
assign data_read = cache_hit ? cache[idx] : 32'b0;
assign addr_out = cache_hit ? 32'b0 : addr_in;

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < `DCACHE_SIZE; i = i + 1) begin
      cache[i] <= 8'b0;
      tags[i] <= 0;
      busy[i] <= 1'b0;
      update[i] <= 1'b0;
      state <= 2'b0;
    end
    i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    case (state)
    2'b000:
    begin
      if (activate_cache) begin
        if (type_in[1:0] == 2'b10) begin // byte operation
          if ()
        end
      end
    end

    2'b100:

    2'b001:

    2'b101:

    2'b010:

    2'b110:

    2'b011:

    2'b111:
    endcase
  end
end

endmodule