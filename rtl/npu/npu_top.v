// ============================================================================
// File Name: npu_top.v
// Module: npu_top
// Description: Top-Level AI NPU IP with APB Slave, DMA, 4x4 Systolic Array & ReLU/Quantize.
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module npu_top (
    input  wire        pclk,
    input  wire        preset_n,

    // AMBA APB Slave Interface (Memory mapped to 0x9000_0000)
    input  wire [7:0]  paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // DMA Master Interface to SoC Data SRAM
    output wire [31:0] dma_sram_addr,
    output wire        dma_sram_req,
    input  wire [31:0] dma_sram_rdata,
    input  wire        dma_sram_ready,

    // Hardware Interrupt to CPU
    output wire        npu_interrupt
);

    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    // -------------------------------------------------------------------------
    // Control & Configuration Registers
    // -------------------------------------------------------------------------
    reg        reg_start;
    reg        reg_clear_acc;
    reg        reg_load_weight;
    reg        reg_relu_en;
    reg        reg_bias_en;
    reg [3:0]  reg_scale_shift;
    reg signed [23:0] reg_bias;

    reg        npu_busy;
    reg        npu_done;

    // DMA Control Signals
    reg        dma_trigger;
    reg [31:0] reg_dma_src;
    reg [15:0] reg_dma_len;
    reg        reg_dma_target;

    wire       dma_busy;
    wire       dma_done_irq;
    wire       dma_stream_valid;
    wire       dma_stream_target;
    wire [31:0] dma_stream_data;

    assign npu_interrupt = npu_done || dma_done_irq;

    // -------------------------------------------------------------------------
    // Internal Weight & Activation Ping-Pong Storage (4 words = 16 INT8 each)
    // -------------------------------------------------------------------------
    reg signed [7:0] weight_bank [0:3][0:3];
    reg signed [7:0] act_bank    [0:3][0:3];

    // Load from DMA stream
    integer wr_idx;
    reg [1:0] dma_wr_cnt;

    always @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            dma_wr_cnt <= 2'd0;
            for (wr_idx = 0; wr_idx < 4; wr_idx = wr_idx + 1) begin
                weight_bank[wr_idx][0] <= 8'sd0; weight_bank[wr_idx][1] <= 8'sd0;
                weight_bank[wr_idx][2] <= 8'sd0; weight_bank[wr_idx][3] <= 8'sd0;
                act_bank[wr_idx][0]    <= 8'sd0; act_bank[wr_idx][1]    <= 8'sd0;
                act_bank[wr_idx][2]    <= 8'sd0; act_bank[wr_idx][3]    <= 8'sd0;
            end
        end else if (dma_trigger) begin
            dma_wr_cnt <= 2'd0;
        end else if (dma_stream_valid) begin
            if (dma_stream_target == 1'b0) begin
                // Store 4 bytes into weight row
                weight_bank[dma_wr_cnt][0] <= dma_stream_data[7:0];
                weight_bank[dma_wr_cnt][1] <= dma_stream_data[15:8];
                weight_bank[dma_wr_cnt][2] <= dma_stream_data[23:16];
                weight_bank[dma_wr_cnt][3] <= dma_stream_data[31:24];
            end else begin
                // Store 4 bytes into activation row
                act_bank[dma_wr_cnt][0] <= dma_stream_data[7:0];
                act_bank[dma_wr_cnt][1] <= dma_stream_data[15:8];
                act_bank[dma_wr_cnt][2] <= dma_stream_data[23:16];
                act_bank[dma_wr_cnt][3] <= dma_stream_data[31:24];
            end
            dma_wr_cnt <= dma_wr_cnt + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // Systolic Array Feeding Sequencer (Waves weights & activations across steps)
    // -------------------------------------------------------------------------
    reg [3:0] step_cnt;
    reg       feeding_active;

    reg signed [7:0] raw_act_0, raw_act_1, raw_act_2, raw_act_3;
    reg signed [7:0] raw_wgt_0, raw_wgt_1, raw_wgt_2, raw_wgt_3;

    always @(*) begin
        if (feeding_active && step_cnt < 4'd4) begin
            raw_act_0 = act_bank[step_cnt][0];
            raw_act_1 = act_bank[step_cnt][1];
            raw_act_2 = act_bank[step_cnt][2];
            raw_act_3 = act_bank[step_cnt][3];

            raw_wgt_0 = weight_bank[step_cnt][0];
            raw_wgt_1 = weight_bank[step_cnt][1];
            raw_wgt_2 = weight_bank[step_cnt][2];
            raw_wgt_3 = weight_bank[step_cnt][3];
        end else begin
            raw_act_0 = 8'sd0; raw_act_1 = 8'sd0; raw_act_2 = 8'sd0; raw_act_3 = 8'sd0;
            raw_wgt_0 = 8'sd0; raw_wgt_1 = 8'sd0; raw_wgt_2 = 8'sd0; raw_wgt_3 = 8'sd0;
        end
    end

    // Skew Buffers
    wire signed [7:0] skewed_act_0, skewed_act_1, skewed_act_2, skewed_act_3;
    skew_buffer u_skew_act (
        .clk        (pclk),
        .rst_n      (preset_n),
        .enable     (feeding_active),
        .in_data_0  (raw_act_0),
        .in_data_1  (raw_act_1),
        .in_data_2  (raw_act_2),
        .in_data_3  (raw_act_3),
        .out_data_0 (skewed_act_0),
        .out_data_1 (skewed_act_1),
        .out_data_2 (skewed_act_2),
        .out_data_3 (skewed_act_3)
    );

    wire signed [7:0] skewed_wgt_0, skewed_wgt_1, skewed_wgt_2, skewed_wgt_3;
    skew_buffer u_skew_wgt (
        .clk        (pclk),
        .rst_n      (preset_n),
        .enable     (feeding_active),
        .in_data_0  (raw_wgt_0),
        .in_data_1  (raw_wgt_1),
        .in_data_2  (raw_wgt_2),
        .in_data_3  (raw_wgt_3),
        .out_data_0 (skewed_wgt_0),
        .out_data_1 (skewed_wgt_1),
        .out_data_2 (skewed_wgt_2),
        .out_data_3 (skewed_wgt_3)
    );

    // -------------------------------------------------------------------------
    // Systolic Array 4x4 Core
    // -------------------------------------------------------------------------
    wire signed [23:0] raw_acc [0:3][0:3];

    systolic_array_4x4 u_array (
        .clk         (pclk),
        .rst_n       (preset_n),
        .enable      (feeding_active),
        .clear_acc   (reg_clear_acc),
        .load_weight (reg_load_weight),
        .act_in_0    (skewed_act_0),
        .act_in_1    (skewed_act_1),
        .act_in_2    (skewed_act_2),
        .act_in_3    (skewed_act_3),
        .weight_in_0 (skewed_wgt_0),
        .weight_in_1 (skewed_wgt_1),
        .weight_in_2 (skewed_wgt_2),
        .weight_in_3 (skewed_wgt_3),
        .acc_0_0 (raw_acc[0][0]), .acc_0_1 (raw_acc[0][1]), .acc_0_2 (raw_acc[0][2]), .acc_0_3 (raw_acc[0][3]),
        .acc_1_0 (raw_acc[1][0]), .acc_1_1 (raw_acc[1][1]), .acc_1_2 (raw_acc[1][2]), .acc_1_3 (raw_acc[1][3]),
        .acc_2_0 (raw_acc[2][0]), .acc_2_1 (raw_acc[2][1]), .acc_2_2 (raw_acc[2][2]), .acc_2_3 (raw_acc[2][3]),
        .acc_3_0 (raw_acc[3][0]), .acc_3_1 (raw_acc[3][1]), .acc_3_2 (raw_acc[3][2]), .acc_3_3 (raw_acc[3][3])
    );

    // -------------------------------------------------------------------------
    // 16 Post-Processing Units (Bias + ReLU + INT8 Quantization)
    // -------------------------------------------------------------------------
    wire signed [7:0] post_int8 [0:3][0:3];
    genvar pr, pc;
    generate
        for (pr = 0; pr < 4; pr = pr + 1) begin : gen_post_r
            for (pc = 0; pc < 4; pc = pc + 1) begin : gen_post_c
                post_process_unit u_ppu (
                    .in_acc      (raw_acc[pr][pc]),
                    .in_bias     (reg_bias),
                    .bias_en     (reg_bias_en),
                    .relu_en     (reg_relu_en),
                    .scale_shift (reg_scale_shift),
                    .out_int8    (post_int8[pr][pc])
                );
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Execution State Machine (4 cycles feed + 4 cycles drain wavefront = 10 cycles total)
    // -------------------------------------------------------------------------
    always @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            feeding_active <= 1'b0;
            step_cnt       <= 4'd0;
            npu_busy       <= 1'b0;
            npu_done       <= 1'b0;
        end else begin
            if (reg_start && !npu_busy) begin
                npu_busy       <= 1'b1;
                npu_done       <= 1'b0;
                feeding_active <= 1'b1;
                step_cnt       <= 4'd0;
            end else if (feeding_active) begin
                if (step_cnt == 4'd10) begin
                    feeding_active <= 1'b0;
                    npu_busy       <= 1'b0;
                    npu_done       <= 1'b1;
                end else begin
                    step_cnt <= step_cnt + 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // DMA Engine Instance
    // -------------------------------------------------------------------------
    npu_dma u_dma (
        .clk            (pclk),
        .rst_n          (preset_n),
        .dma_start      (dma_trigger),
        .dma_src_addr   (reg_dma_src),
        .dma_word_count (reg_dma_len),
        .dma_target_sel (reg_dma_target),
        .dma_busy       (dma_busy),
        .dma_done_irq   (dma_done_irq),
        .sram_addr      (dma_sram_addr),
        .sram_req       (dma_sram_req),
        .sram_rdata     (dma_sram_rdata),
        .sram_ready     (dma_sram_ready),
        .stream_valid   (dma_stream_valid),
        .stream_target  (dma_stream_target),
        .stream_data    (dma_stream_data)
    );

    // -------------------------------------------------------------------------
    // APB Read/Write Interface
    // -------------------------------------------------------------------------
    wire apb_wr = psel && penable && pwrite;

    always @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            reg_start       <= 1'b0;
            reg_clear_acc   <= 1'b0;
            reg_load_weight <= 1'b0;
            reg_relu_en     <= 1'b1;
            reg_bias_en     <= 1'b1;
            reg_scale_shift <= 4'd4;
            reg_bias        <= 24'sd0;
            dma_trigger     <= 1'b0;
            reg_dma_src     <= 32'd0;
            reg_dma_len     <= 16'd0;
            reg_dma_target  <= 1'b0;
        end else begin
            reg_start   <= 1'b0;
            dma_trigger <= 1'b0;

            if (apb_wr) begin
                case (paddr[7:0])
                    8'h00: begin // NPU_CTRL
                        reg_start       <= pwdata[0];
                        reg_clear_acc   <= pwdata[1];
                        reg_load_weight <= pwdata[2];
                        reg_relu_en     <= pwdata[3];
                        reg_bias_en     <= pwdata[4];
                        reg_scale_shift <= pwdata[8:5];
                    end
                    8'h08: reg_dma_src <= pwdata;
                    8'h0C: begin // DMA_CFG
                        reg_dma_len    <= pwdata[15:0];
                        reg_dma_target <= pwdata[16];
                        dma_trigger    <= pwdata[31];
                    end
                    8'h10: reg_bias <= pwdata[23:0];
                    default: ;
                endcase
            end
        end
    end

    // APB Read Multiplexer
    always @(*) begin
        case (paddr[7:0])
            8'h00: prdata = {23'd0, reg_scale_shift, reg_bias_en, reg_relu_en, reg_load_weight, reg_clear_acc, reg_start};
            8'h04: prdata = {29'd0, dma_busy, npu_done, npu_busy};
            8'h08: prdata = reg_dma_src;
            8'h0C: prdata = {15'd0, reg_dma_target, reg_dma_len};
            8'h10: prdata = {{8{reg_bias[23]}}, reg_bias};
            // Packed INT8 Post-Processed Matrix Outputs (1 word = 4 INT8)
            8'h20: prdata = {post_int8[0][3], post_int8[0][2], post_int8[0][1], post_int8[0][0]}; // Row 0
            8'h24: prdata = {post_int8[1][3], post_int8[1][2], post_int8[1][1], post_int8[1][0]}; // Row 1
            8'h28: prdata = {post_int8[2][3], post_int8[2][2], post_int8[2][1], post_int8[2][0]}; // Row 2
            8'h2C: prdata = {post_int8[3][3], post_int8[3][2], post_int8[3][1], post_int8[3][0]}; // Row 3
            default: prdata = 32'd0;
        endcase
    end

endmodule
