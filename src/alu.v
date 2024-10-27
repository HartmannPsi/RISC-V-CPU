module ALU
#(
  parameter AUIPC = 4'b0000,
  parameter ADD = 4'b0001,
  parameter SUB = 4'b0010,
  parameter AND = 4'b0011,
  parameter OR = 4'b0100,
  parameter XOR = 4'b0101,
  parameter SLL = 4'b0110,
  parameter SRL = 4'b0111,
  parameter SRA = 4'b1000,
  parameter SLT = 4'b1001,
  parameter SLTU = 4'b1010,
  parameter LUI = 4'b1011
)
(
  // input wire clk_in,     // system clock signal
  // input wire rst_in,			// reset signal
	// input wire rdy_in,			// ready signal, pause cpu when low

  input wire[31:0] op1,
  input wire[31:0] op2,
  input wire[3:0] alu_op,

  output wire[31:0] result,
  output wire zero,         // 1 if result is zero
  output wire c_out,        // carry out
  output wire overflow      // 1 if overflow occurs
);

always @(*) begin
    case(alu_op)
    4'b0000: // auipc
    begin
      result = (op1 << 12) + op2;
      overflow = (op1[31 - 12] == op2[31]) && (~op1[31 - 12] == result[31]);
      zero = (result == 0);
      c_out = 0;
    end

    4'b0001: // add
    begin
      result = op1 + op2;
      overflow = (op1[31] == op2[31]) && (~op1[31] == result[31]);
      zero = (result == 0);
      c_out = 0;
    end

    4'b0010: // sub
    begin
      result = op1 - op2;
      overflow = (op1[31] == 0 && op2[31] == 1 && result[31] == 1) || (op1[31] == 1 && op2[31] == 0 && result[31] == 0);
      zero = (op1 == op2);
      c_out = 0;
    end

    4'b0011: // and
    begin
      result = op1 & op2;
      overflow = 0;
      zero = (result == 0);
      c_out = 0;
    end

    4'b0100: // or
    begin
      result = op1 | op2;
      overflow = 0;
      zero = (result == 0);
      c_out = 0;
    end

    4'b0101: // xor
    begin
      result = op1 ^ op2;
      overflow = 0;
      zero = (result == 0);
      c_out = 0;
    end

    4'b0110: // sll
    begin
      {c_out, result} = op1 << op2;
      overflow = 0;
      zero = (result == 0);
    end

    4'b0111: // srl
    begin
      result = op1 >> op2;
      c_out = op1[op2 - 1];
      overflow = 0;
      zero = (result == 0);
    end

    4'b1000: // sra
    begin
      result = $signed(op1) >>> op2;
      c_out = op1[op2 - 1];
      overflow = 0;
      zero = (result == 0);
    end

    4'b1001: // slt
    begin
      if (op1[31] == 0 && op2[31] == 1) begin
        result = 0;
      end
      else if (op1[31] == 1 && op2[31] == 0) begin
        result = 1;
      end
      else begin
        result = (op1 < op2);
      end
      overflow = 0;
      zero = ~result[0];
      c_out = result[0];
    end

    4'b1010: // sltu
    begin
      result = (op1 < op2);
      overflow = 0;
      zero = ~result[0];
      c_out = result[0];
    end

    4'b1011: // lui
    begin
      result = (op1 << 12);
      overflow = 0;
      zero = (op1 == 0);
      c_out = 0;
    end

    4'b1100:
    4'b1101:
    4'b1110:
    4'b1111:
    endcase
end


endmodule