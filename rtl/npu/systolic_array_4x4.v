// ============================================================================
// File Name: systolic_array_4x4.v
// Module: systolic_array_4x4
// Description: 4x4 INT8 Systolic Array Grid (16 PEs) for Matrix Multiplication.
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module systolic_array_4x4 (
    input  wire        clk,
    input  wire        rst_n,

    // Control Signals
    input  wire        enable,
    input  wire        clear_acc,
    input  wire        load_weight,

    // 4-Channel Input Activations (West boundary)
    input  wire signed [7:0] act_in_0,
    input  wire signed [7:0] act_in_1,
    input  wire signed [7:0] act_in_2,
    input  wire signed [7:0] act_in_3,

    // 4-Channel Input Weights (North boundary)
    input  wire signed [7:0] weight_in_0,
    input  wire signed [7:0] weight_in_1,
    input  wire signed [7:0] weight_in_2,
    input  wire signed [7:0] weight_in_3,

    // 16 Accumulator Results (Row-Major: [r*4 + c])
    output wire signed [23:0] acc_0_0, output wire signed [23:0] acc_0_1, output wire signed [23:0] acc_0_2, output wire signed [23:0] acc_0_3,
    output wire signed [23:0] acc_1_0, output wire signed [23:0] acc_1_1, output wire signed [23:0] acc_1_2, output wire signed [23:0] acc_1_3,
    output wire signed [23:0] acc_2_0, output wire signed [23:0] acc_2_1, output wire signed [23:0] acc_2_2, output wire signed [23:0] acc_2_3,
    output wire signed [23:0] acc_3_0, output wire signed [23:0] acc_3_1, output wire signed [23:0] acc_3_2, output wire signed [23:0] acc_3_3
);

    // Horizontal activation interconnect wires [row][col]
    wire signed [7:0] act_wire [0:3][0:4];
    // Vertical weight interconnect wires [row][col]
    wire signed [7:0] weight_wire [0:4][0:3];

    // Boundary Assignments
    assign act_wire[0][0] = act_in_0;
    assign act_wire[1][0] = act_in_1;
    assign act_wire[2][0] = act_in_2;
    assign act_wire[3][0] = act_in_3;

    assign weight_wire[0][0] = weight_in_0;
    assign weight_wire[0][1] = weight_in_1;
    assign weight_wire[0][2] = weight_in_2;
    assign weight_wire[0][3] = weight_in_3;

    // 2D Array of Processing Elements
    genvar r, c;
    generate
        for (r = 0; r < 4; r = r + 1) begin : gen_row
            for (c = 0; c < 4; c = c + 1) begin : gen_col
                wire signed [23:0] pe_acc;
                pe u_pe (
                    .clk         (clk),
                    .rst_n       (rst_n),
                    .enable      (enable),
                    .clear_acc   (clear_acc),
                    .load_weight (load_weight),
                    .in_act      (act_wire[r][c]),
                    .in_weight   (weight_wire[r][c]),
                    .out_act     (act_wire[r][c+1]),
                    .out_weight  (weight_wire[r+1][c]),
                    .out_acc     (pe_acc)
                );

                // Map to outputs
                if (r == 0 && c == 0) assign acc_0_0 = pe_acc;
                if (r == 0 && c == 1) assign acc_0_1 = pe_acc;
                if (r == 0 && c == 2) assign acc_0_2 = pe_acc;
                if (r == 0 && c == 3) assign acc_0_3 = pe_acc;
                if (r == 1 && c == 0) assign acc_1_0 = pe_acc;
                if (r == 1 && c == 1) assign acc_1_1 = pe_acc;
                if (r == 1 && c == 2) assign acc_1_2 = pe_acc;
                if (r == 1 && c == 3) assign acc_1_3 = pe_acc;
                if (r == 2 && c == 0) assign acc_2_0 = pe_acc;
                if (r == 2 && c == 1) assign acc_2_1 = pe_acc;
                if (r == 2 && c == 2) assign acc_2_2 = pe_acc;
                if (r == 2 && c == 3) assign acc_2_3 = pe_acc;
                if (r == 3 && c == 0) assign acc_3_0 = pe_acc;
                if (r == 3 && c == 1) assign acc_3_1 = pe_acc;
                if (r == 3 && c == 2) assign acc_3_2 = pe_acc;
                if (r == 3 && c == 3) assign acc_3_3 = pe_acc;
            end
        end
    endgenerate

endmodule
