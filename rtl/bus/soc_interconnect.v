// ============================================================================
// File Name: soc_interconnect.v
// Module: soc_interconnect
// Description: Multi-Master Interconnect & APB Bridge for Edge-AI Tensor SoC.
// Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
// ============================================================================

`timescale 1ns / 1ps

module soc_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Instruction Bus
    input  wire [31:0] cpu_instr_addr,
    output wire [31:0] cpu_instr_data,

    // CPU Data Bus
    input  wire [31:0] cpu_data_addr,
    input  wire [31:0] cpu_data_wdata,
    input  wire [3:0]  cpu_data_wstrb,
    input  wire        cpu_data_we,
    input  wire        cpu_data_req,
    output reg  [31:0] cpu_data_rdata,
    output reg         cpu_data_ready,

    // DMA Master Interface from NPU
    input  wire [31:0] dma_addr,
    input  wire        dma_req,
    output wire [31:0] dma_rdata,
    output wire        dma_ready,

    // APB Slave Interface: UART (0x8000_0000)
    output wire [3:0]  uart_paddr,
    output reg         uart_psel,
    output reg         uart_penable,
    output wire        uart_pwrite,
    output wire [31:0] uart_pwdata,
    input  wire [31:0] uart_prdata,
    input  wire        uart_pready,

    // APB Slave Interface: AI NPU (0x9000_0000)
    output wire [7:0]  npu_paddr,
    output reg         npu_psel,
    output reg         npu_penable,
    output wire        npu_pwrite,
    output wire [31:0] npu_pwdata,
    input  wire [31:0] npu_prdata,
    input  wire        npu_pready
);

    // -------------------------------------------------------------------------
    // Address Decoding
    // -------------------------------------------------------------------------
    wire is_ram      = (cpu_data_addr >= 32'h0000_0400 && cpu_data_addr < 32'h0000_1000);
    wire is_apb_uart = (cpu_data_addr[31:28] == 4'h8); // 0x8000_0000
    wire is_apb_npu  = (cpu_data_addr[31:28] == 4'h9); // 0x9000_0000
    wire is_apb      = is_apb_uart || is_apb_npu;

    // -------------------------------------------------------------------------
    // 1. Instruction Boot ROM (512 words = 2 KB)
    // -------------------------------------------------------------------------
    reg [31:0] rom [0:511];
    wire [8:0] rom_addr = cpu_instr_addr[10:2];

    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1) rom[i] = 32'h00000013; // NOP
        $readmemh("firmware/boot_firmware.hex", rom, 0, 277);
    end

    assign cpu_instr_data = rom[rom_addr];

    // -------------------------------------------------------------------------
    // 2. Dual-Port Scratchpad Data SRAM (768 words = 3 KB)
    // -------------------------------------------------------------------------
    reg [31:0] ram [0:767];
    wire [9:0] cpu_ram_addr = (cpu_data_addr - 32'h0000_0400) >> 2;
    wire [9:0] dma_ram_addr = (dma_addr - 32'h0000_0400) >> 2;

    // CPU Port (Synchronous Write, Continuous Read)
    always @(posedge clk) begin
        if (cpu_data_req && is_ram && cpu_data_we) begin
            if (cpu_data_wstrb[0]) ram[cpu_ram_addr][7:0]   <= cpu_data_wdata[7:0];
            if (cpu_data_wstrb[1]) ram[cpu_ram_addr][15:8]  <= cpu_data_wdata[15:8];
            if (cpu_data_wstrb[2]) ram[cpu_ram_addr][23:16] <= cpu_data_wdata[23:16];
            if (cpu_data_wstrb[3]) ram[cpu_ram_addr][31:24] <= cpu_data_wdata[31:24];
        end
    end

    wire [31:0] ram_cpu_rdata = ram[cpu_ram_addr];

    // DMA Read Port
    assign dma_rdata = ram[dma_ram_addr];
    assign dma_ready = 1'b1; // Zero-wait-state DMA read

    // -------------------------------------------------------------------------
    // 3. APB Master Protocol Bridge
    // -------------------------------------------------------------------------
    localparam APB_IDLE   = 2'b00;
    localparam APB_SETUP  = 2'b01;
    localparam APB_ACCESS = 2'b10;

    reg [1:0] apb_state;

    assign uart_paddr  = cpu_data_addr[3:0];
    assign uart_pwrite = cpu_data_we;
    assign uart_pwdata = cpu_data_wdata;

    assign npu_paddr   = cpu_data_addr[7:0];
    assign npu_pwrite  = cpu_data_we;
    assign npu_pwdata  = cpu_data_wdata;

    wire active_pready = is_apb_uart ? uart_pready :
                         is_apb_npu  ? npu_pready  : 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            apb_state    <= APB_IDLE;
            uart_psel    <= 1'b0;
            uart_penable <= 1'b0;
            npu_psel     <= 1'b0;
            npu_penable  <= 1'b0;
        end else begin
            case (apb_state)
                APB_IDLE: begin
                    uart_penable <= 1'b0;
                    npu_penable  <= 1'b0;
                    if (cpu_data_req && is_apb) begin
                        uart_psel <= is_apb_uart;
                        npu_psel  <= is_apb_npu;
                        apb_state <= APB_SETUP;
                    end else begin
                        uart_psel <= 1'b0;
                        npu_psel  <= 1'b0;
                    end
                end

                APB_SETUP: begin
                    if (uart_psel) uart_penable <= 1'b1;
                    if (npu_psel)  npu_penable  <= 1'b1;
                    apb_state <= APB_ACCESS;
                end

                APB_ACCESS: begin
                    if (active_pready) begin
                        uart_psel    <= 1'b0;
                        uart_penable <= 1'b0;
                        npu_psel     <= 1'b0;
                        npu_penable  <= 1'b0;
                        apb_state    <= APB_IDLE;
                    end
                end

                default: apb_state <= APB_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Response Multiplexer to CPU
    // -------------------------------------------------------------------------
    always @(*) begin
        if (is_ram) begin
            cpu_data_rdata = ram_cpu_rdata;
            cpu_data_ready = 1'b1;
        end else if (is_apb_uart) begin
            cpu_data_rdata = uart_prdata;
            cpu_data_ready = (apb_state == APB_ACCESS && uart_pready);
        end else if (is_apb_npu) begin
            cpu_data_rdata = npu_prdata;
            cpu_data_ready = (apb_state == APB_ACCESS && npu_pready);
        end else begin
            cpu_data_rdata = 32'd0;
            cpu_data_ready = 1'b1;
        end
    end

endmodule
