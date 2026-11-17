// ============================================================================
// File Name: skew_buffer.v
// Module: skew_buffer
// Description: Systolic Wavefront Skew Buffer for 4x4 Array (delays channels 0..3 by 0..3 cycles).
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module skew_buffer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,

    // Unskewed parallel inputs from FIFO/SRAM
    input  wire signed [7:0] in_data_0,
    input  wire signed [7:0] in_data_1,
    input  wire signed [7:0] in_data_2,
    input  wire signed [7:0] in_data_3,

    // Skewed outputs to Systolic Array inputs
    output wire signed [7:0] out_data_0,
    output wire signed [7:0] out_data_1,
    output wire signed [7:0] out_data_2,
    output wire signed [7:0] out_data_3
);

    // Channel 0: 0-cycle delay
    assign out_data_0 = in_data_0;

    // Channel 1: 1-cycle delay
    reg signed [7:0] ch1_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ch1_d1 <= 8'sd0;
        else if (enable) ch1_d1 <= in_data_1;
    end
    assign out_data_1 = ch1_d1;

    // Channel 2: 2-cycle delay
    reg signed [7:0] ch2_d1, ch2_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch2_d1 <= 8'sd0;
            ch2_d2 <= 8'sd0;
        end else if (enable) begin
            ch2_d1 <= in_data_2;
            ch2_d2 <= ch2_d1;
        end
    end
    assign out_data_2 = ch2_d2;

    // Channel 3: 3-cycle delay
    reg signed [7:0] ch3_d1, ch3_d2, ch3_d3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ch3_d1 <= 8'sd0;
            ch3_d2 <= 8'sd0;
            ch3_d3 <= 8'sd0;
        end else if (enable) begin
            ch3_d1 <= in_data_3;
            ch3_d2 <= ch3_d1;
            ch3_d3 <= ch3_d2;
        end
    end
    assign out_data_3 = ch3_d3;

endmodule
