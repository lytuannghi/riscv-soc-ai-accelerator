// ============================================================================
// File Name: soc_ai_tb.v
// Module: soc_ai_tb
// Description: Self-Checking Verification Testbench for Edge-AI Tensor SoC.
// ============================================================================

`timescale 1ns / 1ps

module soc_ai_tb;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire uart_txd;
    reg  uart_rxd = 1'b1;
    wire npu_irq;
    wire uart_irq;

    soc_top u_soc (
        .clk      (clk),
        .rst_n    (rst_n),
        .uart_txd (uart_txd),
        .uart_rxd (uart_rxd),
        .npu_irq  (npu_irq),
        .uart_irq (uart_irq)
    );

    always #10 clk = ~clk; // 50 MHz

    // Genuine external UART_TXD pin decoder (baud_div=2 -> 1 bit = 640 ns)
    localparam integer BIT_NS = 640;
    reg [7:0] pin_bytes [0:31];
    integer pin_char_count = 0;
    integer b;
    reg [7:0] rx_shifter;

    initial begin
        forever begin
            @(negedge uart_txd);
            if (rst_n) begin
                #(BIT_NS / 2);
                if (uart_txd == 1'b0) begin
                    for (b = 0; b < 8; b = b + 1) begin
                        #(BIT_NS);
                        rx_shifter[b] = uart_txd;
                    end
                    #(BIT_NS);
                    if (pin_char_count < 32) begin
                        pin_bytes[pin_char_count] = rx_shifter;
                        pin_char_count = pin_char_count + 1;
                        $write("%c", rx_shifter);
                        $fflush();
                    end
                end
            end
        end
    end

    reg [31:0] sig_val;
    reg [31:0] npu_res_row0;
    reg [8*23-1:0] expected_msg;
    reg [8*23-1:0] captured_msg;
    integer idx;
    integer errors = 0;

    initial begin
        $dumpfile("sim/riscv_ai_soc_waveform.vcd");
        $dumpvars(2, soc_ai_tb);

        expected_msg = "AI NPU INFERENCE: PASS!";
        $display("\n========================================================");
        $display("  STARTING EDGE-AI TENSOR SOC HARDWARE VERIFICATION");
        $display("========================================================");
        $display("[INFO] Architecture: RV32I CPU + 4x4 Systolic Array + DMA + PPU");

        #50 rst_n = 1'b1;
        $write("[UART PIN RX] ");
        $fflush();

        #220000;

        $display("\n--------------------------------------------------------");
        $display("  VERIFYING NPU ACCELERATOR & DATA SRAM INFERENCE RESULTS:");

        sig_val = u_soc.u_interconnect.ram[112];
        if (sig_val == 32'hCAFEFACE) begin
            $display("[PASS] Firmware Completion Signature Verified: 0x%08X", sig_val);
        end else begin
            $display("[FAIL] Firmware Completion Signature Mismatch! Got 0x%08X", sig_val);
            errors = errors + 1;
        end

        npu_res_row0 = u_soc.u_interconnect.ram[96];
        if (npu_res_row0 == 32'h04030202) begin
            $display("[PASS] AI NPU Matrix Row 0 Verified: 0x%08X (Exact INT8 Quantized Tensor)", npu_res_row0);
        end else begin
            $display("[FAIL] NPU Matrix Row 0 Mismatch! Expected 0x04030202, Got 0x%08X", npu_res_row0);
            errors = errors + 1;
        end

        for (idx = 0; idx < 23; idx = idx + 1) begin
            captured_msg[8*(22-idx) +: 8] = (idx < pin_char_count) ? pin_bytes[idx] : 8'h00;
        end

        if (pin_char_count >= 23 && captured_msg == expected_msg) begin
            $display("[PASS] External UART_TXD Serial Pin Decoded: \"%s\" (%0d chars)!", captured_msg, pin_char_count);
        end else begin
            $display("[FAIL] External UART_TXD mismatch! Count=%0d, Got=\"%s\"", pin_char_count, captured_msg);
            errors = errors + 1;
        end

        $display("========================================================");
        if (errors == 0) begin
            $display("STATUS: 100%% EDGE-AI TENSOR SOC VERIFICATION PASSED!");
        end else begin
            $display("STATUS: VERIFICATION FAILED (%0d errors)!", errors);
        end
        $display("========================================================\n");

        #100 $finish;
    end

endmodule
