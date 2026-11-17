# 🎯 Edge-AI Tensor SoC: Verification Plan (vPlan)

**Verification Lead:** Lý Tuấn Nghi ([@lytuannghi](https://github.com/lytuannghi))  
**Design Role:** Design Verification (DV) Engineer  
**Coverage Target:** 100% Functional & Co-Simulation Verification Pass  

---

## 1. Scope & Goals
- Verify RV32I host processor booting from ROM and executing DMA configuration routines.
- Verify autonomous DMA burst transfer of INT8 weight matrices and activation vectors from Data SRAM to NPU internal buffers without CPU stall.
- Verify $4 \times 4$ 2D Systolic Array MAC operations across 16 PEs.
- Verify Post-Processing Pipeline: Bias addition, ReLU thresholding ($\max(0, x)$), and INT8 saturating truncation.
- Verify end-to-end telemetry: NPU inference completion, result storage in SRAM, and serial transmission via APB UART.

---

## 2. Test Matrix

| Test ID | Feature Under Test | Stimulus & Sequence | Pass Criteria | Status |
| :---: | :--- | :--- | :--- | :---: |
| **AI_RST_01** | Power-On Reset | Assert `rst_n` low for 50ns, verify PC resets to `0x0000_0000`. | Clean boot from address `0x0` | **PASS (100%)** |
| **AI_DMA_01** | Weight DMA Burst | CPU programs DMA to stream 4 words from `0x500` to Weight bank. | 16 weights latched in NPU bank | **PASS (100%)** |
| **AI_DMA_02** | Activation DMA Burst | CPU programs DMA to stream 4 words from `0x540` to Activation bank. | 16 activations latched in NPU bank | **PASS (100%)** |
| **AI_NPU_01** | Systolic Wavefront | NPU computes $4 \times 4$ matrix product in 11 clock cycles. | All 16 PEs accumulate non-zero products | **PASS (100%)** |
| **AI_PPU_01** | Post-Processing | Applies Bias $+5$, ReLU, and 2-bit right-shift scaling. | Result Row 0 equals `0x04030202` | **PASS (100%)** |
| **AI_WB_01** | Matrix Result Writeback | CPU reads `0x9000_0020` and stores to SRAM `0x580`. | `SRAM[96] == 0x04030202` | **PASS (100%)** |
| **AI_UART_01**| Telemetry Stream | CPU prints `"AI NPU INFERENCE: PASS!\n"` to UART console. | 24 characters received | **PASS (100%)** |
| **AI_SIGN_01**| Signature Verification | CPU writes magic word `0xCAFEFACE` to `SRAM[112]` (`0x5C0`). | SRAM holds `0xCAFEFACE` | **PASS (100%)** |

---

## 3. Simulation Benchmark Metrics

- **Clock Frequency:** 50 MHz ($T = 20\text{ ns}$).
- **Inference Latency:** 11 clock cycles (220 ns) for full $4 \times 4$ INT8 tensor dot product.
- **Total Co-Simulation Time:** 220,150 ns (~11,008 clock cycles).
- **Execution Run Time:** ~1.5 seconds under Icarus Verilog VVP engine.
- **Waveform File:** `riscv_ai_soc_waveform.vcd` (362 KB).
