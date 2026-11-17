// ============================================================================
// File Name: soc_ai_tb.v
// Module: soc_ai_tb
// Description: Complete Self-Checking Verification Testbench for Edge-AI Tensor SoC.
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module soc_ai_tb;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire uart_txd;
    reg  uart_rxd = 1'b1;
    wire npu_irq;
    wire uart_irq;

    // Instantiate Edge-AI SoC Top
    soc_top u_soc (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_txd (uart_txd),
        .uart_rxd (uart_rxd),
        .npu_irq  (npu_irq),
        .uart_irq (uart_irq)
    );

    // 50 MHz Clock Generator (20ns period)
    always #10 clk = ~clk;

    reg [31:0] sig_val;
    reg [31:0] npu_res_row0;

    // -------------------------------------------------------------------------
    // Synchronous UART Console Monitor
    // -------------------------------------------------------------------------
    integer char_count = 0;
    always @(posedge clk) begin
        if (rst_n && u_soc.u_uart.tx_trigger) begin
            $write("%c", u_soc.u_uart.tx_fifo_rd_data);
            $fflush();
            char_count = char_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Main Verification Flow
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("D:/CODE/GGANTIGRAVITY/minipj/output/riscv_ai_soc_waveform.vcd");
        $dumpvars(2, soc_ai_tb);

        $display("\n========================================================");
        $display("🚀 STARTING EDGE-AI TENSOR SOC HARDWARE VERIFICATION");
        $display("========================================================");
        $display("ℹ️  Architecture: RV32I CPU + 4x4 Systolic Array + DMA + Post-Processing");

        // Assert Reset
        #50 rst_n = 1'b1;
        $display("ℹ️  System Reset Released. Booting RISC-V CPU from ROM...\n");
        $write("📡 UART CONSOLE: ");
        $fflush();

        // Run simulation for 220,000 ns (11,000 clock cycles)
        // Allows full DMA weight/activation transfers, systolic wave compute, post-processing, and 24-char UART print
        #220000;

        $display("\n--------------------------------------------------------");
        $display("📊 VERIFYING NPU ACCELERATOR & DATA SRAM INFERENCE RESULTS:");

        // 1. Verify Completion Signature in SRAM (0x5C0 -> Word Index 112)
        // 0x5C0 = 0x400 (SRAM Base) + 0x1C0 (448 bytes = 112 words)
        sig_val = u_soc.u_interconnect.ram[112];
        if (sig_val == 32'hCAFEFACE) begin
            $display("✅ [PASS] Firmware Completion Signature Verified: 0x%08X", sig_val);
        end else begin
            $display("❌ [FAIL] Firmware Completion Signature Mismatch! Expected 0xCAFEFACE, Got 0x%08X", sig_val);
        end

        // 2. Verify NPU Post-Processed Inference Output in SRAM (0x580 -> Word Index 96)
        npu_res_row0 = u_soc.u_interconnect.ram[96];
        if (npu_res_row0 != 32'd0) begin
            $display("✅ [PASS] AI NPU Matrix Result Row 0 Verified: 0x%08X (Non-zero INT8 Tensor)", npu_res_row0);
        end else begin
            $display("❌ [FAIL] NPU Matrix Result Row 0 is 0! (Check compute pipeline)");
        end

        // 3. Verify UART Stream
        if (char_count >= 20) begin
            $display("✅ [PASS] UART Serial Console Transmission Verified (%0d characters received)!", char_count);
        end else begin
            $display("❌ [FAIL] Incomplete UART Transmission! Received %0d characters", char_count);
        end

        $display("========================================================");
        if (sig_val == 32'hCAFEFACE && npu_res_row0 != 32'd0 && char_count >= 20) begin
            $display("🏆 STATUS: 100%% EDGE-AI TENSOR SOC VERIFICATION PASSED!");
        end else begin
            $display("⚠️ STATUS: VERIFICATION FAILED!");
        end
        $display("========================================================\n");

        #100 $finish;
    end

endmodule
