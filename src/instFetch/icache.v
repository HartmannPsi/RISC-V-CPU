`inlcude "../macros.v"

module InstCache(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // addr get from decoder
  input wire [31:0] addr_in,
    // inst to decoder
  output wire [31:0] data_out,

  // data get from ram
  input wire [31:0] rewrite_data,
  // addr to ram
  output wire [31:0] addr_out,
  // whether to write data to cache
  input wire write_enable,

  // whether hit cache
  output wire cache_hit
);

// addr: [31:7]: tag, [6:2]: idx, [1:0]: 2'b00
wire tag = addr_in[31:2 + `ICACHE_ADDR_W];
wire idx = addr_in[1 + `ICACHE_ADDR_W:2];

reg [31:0] cache[`ICACHE_SIZE - 1:0];
reg [31 - 2 - `ICACHE_ADDR_W:0] tags[`ICACHE_SIZE - 1:0];
reg busy[`ICACHE_SIZE - 1:0];
reg [`ICACHE_SIZE_W - 1:0] i;

assign cache_hit = busy[idx] && (tags[idx] == tag);
assign data_out = cache_hit ? cache[idx] : 32'b0;
assign addr_out = cache_hit ? 32'b0 : addr_in;

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < `ICACHE_SIZE; i = i + 1) begin
      cache[i] <= 32'b0;
      tags[i] <= 0;
      busy[i] <= 1'b0;
    end
    i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    if (write_enable) begin
      cache[idx] <= rewrite_data;
      tags[idx] <= tag;
      busy[idx] <= 1'b1;
    end
  end
end

endmodule