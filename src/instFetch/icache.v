`include "src/macros.v"

module InstCache(
  input wire clk_in,
  input wire rst_in,
  input wire rdy_in,

  // addr get from decoder
  input wire [31:0] addr_in,
  // inst to decoder
  output wire [31:0] data_out,
  // inst length to decoder, 1 for 32-bit, 0 for 16-bit
  output wire inst_length,

  // data get from ram
  input wire [31:0] rewrite_data,
  // addr to ram
  output wire [31:0] addr_out,
  // whether to write data to cache
  input wire write_enable,

  input wire icache_block,

  // whether hit cache
  output wire cache_hit
);

// addr: [31:7]: tag, [6:1]: idx, [0]: 1'b0
wire [31 - 1 - `ICACHE_ADDR_W:0] tag1 = addr_in[31:1 + `ICACHE_ADDR_W];
wire [`ICACHE_ADDR_W - 1:0] idx1 = addr_in[`ICACHE_ADDR_W:1];

wire [31:0] addr2 = addr_in + 2;
wire [31 - 1 - `ICACHE_ADDR_W:0] tag2 = addr2[31:1 + `ICACHE_ADDR_W];
wire [`ICACHE_ADDR_W - 1:0] idx2 = addr2[`ICACHE_ADDR_W:1];

wire we = write_enable && !icache_block;

reg [15:0] cache[`ICACHE_SIZE - 1:0];
reg [31 - 1 - `ICACHE_ADDR_W:0] tags[`ICACHE_SIZE - 1:0];
reg busy[`ICACHE_SIZE - 1:0];
integer i;

wire cache_hit1 = busy[idx1] && (tags[idx1] == tag1);
assign inst_length = cache[idx1][1:0] == 2'b11; // 1 for 32-bit, 0 for 16-bit
wire cache_hit2 = inst_length ? (busy[idx2] && (tags[idx2] == tag2)) : 1'b1;

assign cache_hit = cache_hit1 && cache_hit2;

function [31:0] getInst;
  input cache_hit, inst_length;
  // input [`ICACHE_ADDR_W - 1:0] idx1, idx2;
  input [15:0] cache_idx1, cache_idx2;
  begin
    if (cache_hit) begin
      if (inst_length) begin // 32-bit
        getInst = {cache_idx2, cache_idx1};
      end
      else begin // 16-bit
        getInst = {16'b0, cache_idx1};
      end
    end
    else begin
      getInst = 32'b0;
    end
  end
endfunction

// assign data_out = {16'b0, cache_hit ? cache[idx1] : 16'b0};
assign data_out = getInst(cache_hit, inst_length, cache[idx1], cache[idx2]);

function [31:0] getAddr;
  //input m;
  input cache_hit1, cache_hit2, inst_length;
  input [31:0] addr_in, addr2;
  begin
    if (cache_hit1) begin
      if (inst_length && !cache_hit2) begin // read part2
        getAddr = addr2;
      end
      else begin // do nothing
        getAddr = 32'b0;
      end
    end
    else begin // read part1
      getAddr = addr_in;
    end

    // getAddr = addr2;
  end
endfunction

// assign addr_out = cache_hit ? 32'b0 : addr_in;
assign addr_out = getAddr(cache_hit1, cache_hit2, inst_length, addr_in, addr2);
wire [31 - 1 - `ICACHE_ADDR_W:0] tag_rewrite = addr_out[31:1 + `ICACHE_ADDR_W];
wire [`ICACHE_ADDR_W - 1:0] idx_rewrite = addr_out[`ICACHE_ADDR_W:1];


always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < `ICACHE_SIZE; i = i + 1) begin
      cache[i] <= 16'b0;
      tags[i] <= 0;
      busy[i] <= 1'b0;
    end
    //i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    if (we) begin
      cache[idx_rewrite] <= rewrite_data[15:0];
      tags[idx_rewrite] <= tag_rewrite;
      busy[idx_rewrite] <= 1'b1;
    end
  end
end

endmodule