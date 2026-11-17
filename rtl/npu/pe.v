// ============================================================================
// File Name: pe.v
// Module: pe
// Description: Processing Element (PE) for INT8 Systolic Array with 24-bit Accumulator.
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module pe (
    input  wire        clk,
    input  wire        rst_n,

    // Control Signals
    input  wire        enable,          // Enable MAC operation
    input  wire        clear_acc,       // Clear accumulator to 0
    input  wire        load_weight,     // Latch new stationary weight

    // Data Inputs (Systolic streaming)
    input  wire signed [7:0]  in_act,    // Input activation flowing West-to-East
    input  wire signed [7:0]  in_weight, // Input weight flowing North-to-South

    // Data Outputs (Forwarded to adjacent PEs)
    output reg  signed [7:0]  out_act,   // Registered activation to East neighbor
    output reg  signed [7:0]  out_weight,// Registered weight to South neighbor
    output wire signed [23:0] out_acc    // 24-bit current accumulator value
);

    reg signed [7:0]  stationary_weight;
    reg signed [23:0] acc;

    // 8-bit x 8-bit Signed Multiplication -> 16-bit signed product
    wire signed [15:0] product = in_act * in_weight;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_act    <= 8'sd0;
            out_weight <= 8'sd0;
            acc        <= 24'sd0;
        end else begin
            // Forward systolic data to neighbors
            out_act    <= in_act;
            out_weight <= in_weight;

            // Accumulator logic
            if (clear_acc) begin
                acc <= (enable) ? {{8{product[15]}}, product} : 24'sd0;
            end else if (enable) begin
                acc <= acc + {{8{product[15]}}, product};
            end
        end
    end

    assign out_acc = acc;

endmodule
