`include "src/macros.v"

module ALU(
  // input wire clk_in,     // system clock signal
  // input wire rst_in,			// reset signal
	// input wire rdy_in,			// ready signal, pause cpu when low

  input wire [31:0] op1,
  input wire [31:0] op2,
  input wire [31:0] addr,
  input wire [4:0] alu_op,
  input wire inst_length, // 1 for 32-bit, 0 for 16-bit

  output reg [31:0] result,
  output reg zero,         // 1 if result is zero
  output reg c_out,        // carry out
  output reg overflow,     // 1 if overflow occurs
  output reg jalr_done,
  output reg [31:0] jalr_addr
);

always @(*) begin
    case (alu_op)
    `AUIPC: // auipc
    begin
      result = addr + op2;
      overflow = (addr[31] == op2[31]) && (~addr[31] == result[31]);
      zero = (result == 0);
      c_out = 0;
    end

    `ADD: // add
    begin
      result = op1 + op2;
      overflow = (op1[31] == op2[31]) && (~op1[31] == result[31]);
      zero = (result == 0);
      c_out = 0;
    end

    `SUB: // sub
    begin
      result = op1 - op2;
      overflow = (op1[31] == 0 && op2[31] == 1 && result[31] == 1) || (op1[31] == 1 && op2[31] == 0 && result[31] == 0);
      zero = (op1 == op2);
      c_out = 0;
    end

    `AND: // and
    begin
      result = op1 & op2;
      overflow = 0;
      zero = (result == 0);
      c_out = 0;
    end

    `OR: // or
    begin
      result = op1 | op2;
      overflow = 0;
      zero = (result == 0);
      c_out = 0;
    end

    `XOR: // xor
    begin
      result = op1 ^ op2;
      overflow = 0;
      zero = (result == 0);
      c_out = 0;
    end

    `SLL: // sll
    begin
      {c_out, result} = {1'b0, op1} << op2;
      overflow = 0;
      zero = (result == 0);
    end

    `SRL: // srl
    begin
      result = op1 >> op2;
      c_out = op1[op2 - 1];
      overflow = 0;
      zero = (result == 0);
    end

    `SRA: // sra
    begin
      result = $signed(op1) >>> op2;
      c_out = op1[op2 - 1];
      overflow = 0;
      zero = (result == 0);
    end

    `SLT: // slt
    begin
      if (op1[31] == 0 && op2[31] == 1) begin
        result = 0;
      end
      else if (op1[31] == 1 && op2[31] == 0) begin
        result = 1;
      end
      else begin
        result = {31'b0, (op1 < op2)};
      end
      overflow = 0;
      zero = ~result[0];
      c_out = result[0];
    end

    `SLTU: // sltu
    begin
      result = {31'b0, (op1 < op2)};
      overflow = 0;
      zero = ~result[0];
      c_out = result[0];
    end

    `LUI: // lui
    begin
      result = op2;
      overflow = 0;
      zero = (op2 == 0);
      c_out = 0;
    end

    
    `BGE: // bge
    begin
      if (op1[31] == 0 && op2[31] == 1) begin
        result[0] = 1'b1;
      end
      else if (op1[31] == 1 && op2[31] == 0) begin
        result[0] = 1'b0;
      end
      else begin
        result[0] = (op1 >= op2);
      end
      result[31:1] = 31'b0;
      overflow = 0;
      zero = ~result[0];
      c_out = 0;
    end

    `BGEU:
    begin
      result = {31'b0, (op1 >= op2)};
      overflow = 0;
      zero = ~result[0];
      c_out = 0;
    end

    `BLT:
    begin
      if (op1[31] == 0 && op2[31] == 1) begin
        result[0] = 1'b0;
      end
      else if (op1[31] == 1 && op2[31] == 0) begin
        result[0] = 1'b1;
      end
      else begin
        result[0] = (op1 < op2);
      end
      result[31:1] = 31'b0;
      overflow = 0;
      zero = ~result[0];
      c_out = 0;
    end

    `BLTU:
    begin
      result = {31'b0, (op1 < op2)};
      overflow = 0;
      zero = ~result[0];
      c_out = 0;
    end

    `BNE:
    begin
      result = {31'b0, (op1 != op2)};
      overflow = 0;
      zero = ~result[0];
      c_out = 0;
    end

    `BEQ:
    begin
      result = {31'b0, (op1 == op2)};
      overflow = 0;
      zero = ~result[0];
      c_out = 0;
    end

    `JAL:
    begin
      result = addr + (inst_length ? 4 : 2);
      overflow = 0;
      zero = 0;
      c_out = 0;
    end

    `JALR:
    begin
      result = addr + (inst_length ? 4 : 2);
      overflow = 0;
      zero = 0;
      c_out = 0;
      jalr_done = 1'b1;
      jalr_addr = op1 + op2;
    end
    endcase

    if (alu_op != `JALR) begin
      jalr_done = 1'b0;
      jalr_addr = 32'b0;
    end
end


endmodule