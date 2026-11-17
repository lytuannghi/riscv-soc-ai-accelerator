// ============================================================================
// File Name: soc_top.v
// Module: soc_top
// Description: Top-Level Integration of Edge-AI Tensor SoC (RISC-V + NPU + UART).
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module soc_top (
    input  wire        clk,
    input  wire        rst_n,

    // Serial Communication Pins
    output wire        uart_txd,
    input  wire        uart_rxd,

    // Interrupt Monitor Pins
    output wire        npu_irq,
    output wire        uart_irq
);

    // CPU Instruction Bus
    wire [31:0] cpu_instr_addr;
    wire [31:0] cpu_instr_data;

    // CPU Data Bus
    wire [31:0] cpu_data_addr;
    wire [31:0] cpu_data_wdata;
    wire [3:0]  cpu_data_wstrb;
    wire        cpu_data_we;
    wire        cpu_data_req;
    wire [31:0] cpu_data_rdata;
    wire        cpu_data_ready;

    // NPU DMA Master Bus to SRAM
    wire [31:0] dma_sram_addr;
    wire        dma_sram_req;
    wire [31:0] dma_sram_rdata;
    wire        dma_sram_ready;

    // APB UART Signals
    wire [3:0]  uart_paddr;
    wire        uart_psel;
    wire        uart_penable;
    wire        uart_pwrite;
    wire [31:0] uart_pwdata;
    wire [31:0] uart_prdata;
    wire        uart_pready;
    wire        uart_pslverr;

    // APB NPU Signals
    wire [7:0]  npu_paddr;
    wire        npu_psel;
    wire        npu_penable;
    wire        npu_pwrite;
    wire [31:0] npu_pwdata;
    wire [31:0] npu_prdata;
    wire        npu_pready;
    wire        npu_pslverr;

    assign uart_irq = uart_interrupt;
    assign npu_irq  = npu_interrupt;
    wire uart_interrupt;
    wire npu_interrupt;

    // 1. RISC-V RV32I Processor Core
    riscv_core u_cpu (
        .clk          (clk),
        .rst_n        (rst_n),
        .instr_addr   (cpu_instr_addr),
        .instr_data   (cpu_instr_data),
        .data_addr    (cpu_data_addr),
        .data_wdata   (cpu_data_wdata),
        .data_wstrb   (cpu_data_wstrb),
        .data_we      (cpu_data_we),
        .data_req     (cpu_data_req),
        .data_rdata   (cpu_data_rdata),
        .data_ready   (cpu_data_ready),
        .external_irq (npu_interrupt || uart_interrupt)
    );

    // 2. SoC Interconnect & Memory Map Bridge
    soc_interconnect u_interconnect (
        .clk            (clk),
        .rst_n          (rst_n),
        .cpu_instr_addr (cpu_instr_addr),
        .cpu_instr_data (cpu_instr_data),
        .cpu_data_addr  (cpu_data_addr),
        .cpu_data_wdata (cpu_data_wdata),
        .cpu_data_wstrb (cpu_data_wstrb),
        .cpu_data_we    (cpu_data_we),
        .cpu_data_req   (cpu_data_req),
        .cpu_data_rdata (cpu_data_rdata),
        .cpu_data_ready (cpu_data_ready),
        // NPU DMA Port
        .dma_addr       (dma_sram_addr),
        .dma_req        (dma_sram_req),
        .dma_rdata      (dma_sram_rdata),
        .dma_ready      (dma_sram_ready),
        // UART APB
        .uart_paddr     (uart_paddr),
        .uart_psel      (uart_psel),
        .uart_penable   (uart_penable),
        .uart_pwrite    (uart_pwrite),
        .uart_pwdata    (uart_pwdata),
        .uart_prdata    (uart_prdata),
        .uart_pready    (uart_pready),
        // NPU APB
        .npu_paddr      (npu_paddr),
        .npu_psel       (npu_psel),
        .npu_penable    (npu_penable),
        .npu_pwrite     (npu_pwrite),
        .npu_pwdata     (npu_pwdata),
        .npu_prdata     (npu_prdata),
        .npu_pready     (npu_pready)
    );

    // 3. APB UART IP
    apb_uart_top u_uart (
        .pclk           (clk),
        .preset_n       (rst_n),
        .paddr          (uart_paddr),
        .psel           (uart_psel),
        .penable        (uart_penable),
        .pwrite         (uart_pwrite),
        .pwdata         (uart_pwdata),
        .prdata         (uart_prdata),
        .pready         (uart_pready),
        .pslverr        (uart_pslverr),
        .uart_txd       (uart_txd),
        .uart_rxd       (uart_rxd),
        .uart_interrupt (uart_interrupt)
    );

    // 4. Edge-AI Tensor NPU IP
    npu_top u_npu (
        .pclk           (clk),
        .preset_n       (rst_n),
        .paddr          (npu_paddr),
        .psel           (npu_psel),
        .penable        (npu_penable),
        .pwrite         (npu_pwrite),
        .pwdata         (npu_pwdata),
        .prdata         (npu_prdata),
        .pready         (npu_pready),
        .pslverr        (npu_pslverr),
        // DMA to SRAM
        .dma_sram_addr  (dma_sram_addr),
        .dma_sram_req   (dma_sram_req),
        .dma_sram_rdata (dma_sram_rdata),
        .dma_sram_ready (dma_sram_ready),
        .npu_interrupt  (npu_interrupt)
    );

endmodule
