// ============================================================================
// File Name: riscv_alu.v
// Module: riscv_alu
// Description: RV32I Arithmetic Logic Unit (ALU).
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module riscv_alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero,
    output wire        less_than
);

    wire signed [31:0] signed_a = a;
    wire signed [31:0] signed_b = b;

    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a + b;                                // ADD
            4'b0001: result = a - b;                                // SUB
            4'b0010: result = a << b[4:0];                          // SLL
            4'b0011: result = (signed_a < signed_b) ? 32'd1 : 32'd0; // SLT (Signed)
            4'b0100: result = (a < b) ? 32'd1 : 32'd0;              // SLTU (Unsigned)
            4'b0101: result = a ^ b;                                // XOR
            4'b0110: result = a >> b[4:0];                          // SRL
            4'b0111: result = signed_a >>> b[4:0];                  // SRA (Arithmetic shift)
            4'b1000: result = a | b;                                // OR
            4'b1001: result = a & b;                                // AND
            4'b1010: result = b;                                    // LUI (Pass B / Immediate)
            default: result = 32'd0;
        endcase
    end

    assign zero      = (result == 32'd0);
    assign less_than = result[0];

endmodule
