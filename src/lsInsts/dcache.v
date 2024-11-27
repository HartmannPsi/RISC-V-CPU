// deprecated
`include "src/macros.v"

module DataCache(
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
  output wire cache_hit,

  output reg data_available, // 1 for data_out is valid

  // whether to activate cache
  output wire activate_out,
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
wire [31 - 2 - `DCACHE_ADDR_W:0] tag = addr_in[31:2 + `DCACHE_ADDR_W];
wire [`DCACHE_ADDR_W - 1:0] idx = addr_in[1 + `DCACHE_ADDR_W:2];

reg [7:0] cache[`DCACHE_SIZE - 1:0];
reg [31 - 2 - `DCACHE_ADDR_W:0] tags[`DCACHE_SIZE - 1:0];
reg busy[`DCACHE_SIZE - 1:0];
reg update[`DCACHE_SIZE - 1:0];
integer i;
reg [2:0] state;
reg [31:0] tmp_addr;
wire [`DCACHE_ADDR_W - 1:0] tmp_idx = tmp_addr[1 + `DCACHE_ADDR_W:2];
wire [31 - 2 - `DCACHE_ADDR_W:0] tmp_tag = tmp_addr[31:2 + `DCACHE_ADDR_W];
reg tmp_r_nw;
reg [2:0] type_;
reg [31:0] data;
reg cache_miss;

assign cache_hit = activate_cache && busy[idx] && (tags[idx] == tag);
assign data_read = cache_hit ? {24'b0, cache[idx]} : 32'b0;
assign r_nw_out = state[2];
assign activate_out = (activate_cache && !cache_hit) || (tmp_idx != 0 && update[tmp_idx]);

assign addr_out = cache_hit ? 32'b0 : (r_nw_out ? tmp_addr : {tags[tmp_idx], tmp_idx, 2'b0});
assign update_data = (!cache_hit && !r_nw_out) ? cache[idx] : 32'b0;

always @(posedge clk_in) begin
  if (rst_in) begin
    for (i = 0; i < `DCACHE_SIZE; i = i + 1) begin
      cache[i] <= 8'b0;
      tags[i] <= 0;
      busy[i] <= 1'b0;
      update[i] <= 1'b0;
    end
    state <= 3'b0;
    tmp_addr <= 32'b0;
    tmp_r_nw <= 1'b0;
    type_ <= 3'b0;
    data <= 32'b0;
    cache_miss <= 1'b0;
    data_available <= 1'b0;
    //i <= 0;
  end
  else if (!rdy_in) begin
    // pause
  end
  else begin
    case (state)
    3'b000:
    begin
      if (data_available) begin
        data_available <= 1'b0;
      end

      if (activate_cache) begin
        tmp_addr <= addr_in;
        tmp_r_nw <= r_nw_in;
        type_ <= type_in;
        data <= data_write;
        cache_miss <= !cache_hit;
        state <= 3'b100;
      end
    end

    3'b100:
    begin
      if (tmp_r_nw) begin // read
        if (cache_miss) begin
          cache[tmp_idx] <= miss_data[7:0];
          tags[tmp_idx] <= tmp_tag;
          update[tmp_idx] <= 1'b0;
        end
      end
      else begin // write
        cache[tmp_idx] <= data[7:0];
        tags[tmp_idx] <= tmp_tag;
        update[tmp_idx] <= 1'b1;
      end
      busy[tmp_idx] <= 1'b1;

      if (type_[1:0] == 2'b10) begin // byte operation
        state <= 3'b000;
        tmp_addr <= 32'b0;
        tmp_r_nw <= 1'b0;
        type_ <= 3'b0;
        data <= 32'b0;
        cache_miss <= 1'b0;
        data_available <= 1'b1;
      end
      else begin // word or half-word operation
        state <= 3'b001;
        tmp_addr <= tmp_addr + 1;
      end
    end

    3'b001:
    begin
      state <= 3'b101;
    end

    3'b101:
    begin
      if (tmp_r_nw) begin // read
        if (cache_miss) begin
          cache[tmp_idx] <= miss_data[7:0];
          tags[tmp_idx] <= tmp_tag;
          update[tmp_idx] <= 1'b0;
        end
      end
      else begin // write
        cache[tmp_idx] <= data[7:0];
        tags[tmp_idx] <= tmp_tag;
        update[tmp_idx] <= 1'b1;
      end
      busy[tmp_idx] <= 1'b1;

      if (type_[1:0] == 2'b01) begin // half-word operation
        state <= 3'b000;
        tmp_addr <= 32'b0;
        tmp_r_nw <= 1'b0;
        type_ <= 3'b0;
        data <= 32'b0;
        cache_miss <= 1'b0;
        data_available <= 1'b1;
      end
      else begin // word operation
        state <= 3'b010;
        tmp_addr <= tmp_addr + 1;
      end
    end

    3'b010:
    begin
      state <= 3'b110;
    end

    3'b110:
    begin
      if (tmp_r_nw) begin // read
        if (cache_miss) begin
          cache[tmp_idx] <= miss_data[7:0];
          tags[tmp_idx] <= tmp_tag;
          update[tmp_idx] <= 1'b0;
        end
      end
      else begin // write
        cache[tmp_idx] <= data[7:0];
        tags[tmp_idx] <= tmp_tag;
        update[tmp_idx] <= 1'b1;
      end
      busy[tmp_idx] <= 1'b1;
      state <= 3'b011;
      tmp_addr <= tmp_addr + 1;
    end

    3'b011:
    begin
      state <= 3'b111;
    end

    3'b111:
    begin
      if (tmp_r_nw) begin // read
        if (cache_miss) begin
          cache[tmp_idx] <= miss_data[7:0];
          tags[tmp_idx] <= tmp_tag;
          update[tmp_idx] <= 1'b0;
        end
      end
      else begin // write
        cache[tmp_idx] <= data[7:0];
        tags[tmp_idx] <= tmp_tag;
        update[tmp_idx] <= 1'b1;
      end
      busy[tmp_idx] <= 1'b1;

        state <= 3'b000;
        tmp_addr <= 32'b0;
        tmp_r_nw <= 1'b0;
        type_ <= 3'b0;
        data <= 32'b0;
        cache_miss <= 1'b0;
        data_available <= 1'b1;
    end
    endcase
  end
end

endmodule