// ============================================================================
// File Name: npu_dma.v
// Module: npu_dma
// Description: Direct Memory Access (DMA) Engine for NPU Weight & Activation Bursts.
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module npu_dma (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Control Interface
    input  wire        dma_start,
    input  wire [31:0] dma_src_addr,
    input  wire [15:0] dma_word_count,      // Number of 32-bit words (each word = 4 INT8)
    input  wire        dma_target_sel,      // 0: Weight buffer, 1: Activation buffer
    output reg         dma_busy,
    output reg         dma_done_irq,

    // Master Bus Interface to Data SRAM
    output reg  [31:0] sram_addr,
    output reg         sram_req,
    input  wire [31:0] sram_rdata,
    input  wire        sram_ready,

    // Streaming Output to NPU Buffer
    output reg         stream_valid,
    output reg         stream_target,
    output reg  [31:0] stream_data
);

    localparam DMA_IDLE  = 2'b00;
    localparam DMA_READ  = 2'b01;
    localparam DMA_PUSH  = 2'b10;
    localparam DMA_DONE  = 2'b11;

    reg [1:0]  state;
    reg [31:0] curr_addr;
    reg [15:0] words_left;
    reg        curr_target;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= DMA_IDLE;
            curr_addr     <= 32'd0;
            words_left    <= 16'd0;
            curr_target   <= 1'b0;
            dma_busy      <= 1'b0;
            dma_done_irq  <= 1'b0;
            sram_addr     <= 32'd0;
            sram_req      <= 1'b0;
            stream_valid  <= 1'b0;
            stream_target <= 1'b0;
            stream_data   <= 32'd0;
        end else begin
            dma_done_irq <= 1'b0;
            stream_valid <= 1'b0;
            sram_req     <= 1'b0;

            case (state)
                DMA_IDLE: begin
                    dma_busy <= 1'b0;
                    if (dma_start && dma_word_count > 0) begin
                        curr_addr   <= dma_src_addr + 32'd4;
                        sram_addr   <= dma_src_addr;
                        sram_req    <= 1'b1;
                        words_left  <= dma_word_count;
                        curr_target <= dma_target_sel;
                        dma_busy    <= 1'b1;
                        state       <= DMA_READ;
                    end
                end

                DMA_READ: begin
                    sram_req <= 1'b1;
                    if (sram_ready) begin
                        stream_data   <= sram_rdata;
                        stream_target <= curr_target;
                        stream_valid  <= 1'b1;

                        sram_addr  <= curr_addr;
                        curr_addr  <= curr_addr + 32'd4;
                        words_left <= words_left - 1'b1;

                        if (words_left == 16'd1) begin
                            state    <= DMA_DONE;
                            sram_req <= 1'b0;
                        end else begin
                            state <= DMA_READ;
                        end
                    end
                end

                DMA_DONE: begin
                    dma_done_irq <= 1'b1;
                    dma_busy     <= 1'b0;
                    state        <= DMA_IDLE;
                end

                default: state <= DMA_IDLE;
            endcase
        end
    end

endmodule
