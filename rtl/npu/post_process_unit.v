// ============================================================================
// File Name: post_process_unit.v
// Module: post_process_unit
// Description: Post-Processing Unit: Bias Addition, ReLU Activation, & INT8 Saturation.
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module post_process_unit (
    input  wire signed [23:0] in_acc,        // 24-bit raw accumulated sum from PE
    input  wire signed [23:0] in_bias,       // 24-bit layer bias
    input  wire               bias_en,       // Enable bias addition
    input  wire               relu_en,       // Enable ReLU activation
    input  wire [3:0]         scale_shift,   // Right shift scaling factor (0..15)
    output reg  signed [7:0]  out_int8       // Saturated 8-bit INT8 activation
);

    // 1. Bias Addition
    wire signed [23:0] with_bias = bias_en ? (in_acc + in_bias) : in_acc;

    // 2. ReLU Activation: max(0, with_bias)
    wire signed [23:0] after_relu = (relu_en && with_bias < 24'sd0) ? 24'sd0 : with_bias;

    // 3. Right-shift scaling for Quantization
    wire signed [23:0] scaled = after_relu >>> scale_shift;

    // 4. Saturating Truncation to 8-bit signed range [-128, 127]
    always @(*) begin
        if (scaled > 24'sd127) begin
            out_int8 = 8'sd127;
        end else if (scaled < -24'sd128) begin
            out_int8 = -8'sd128;
        end else begin
            out_int8 = scaled[7:0];
        end
    end

endmodule
