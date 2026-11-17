# 🧠 Edge-AI Tensor SoC: Architecture & Hardware Specification

**Design Lead:** Lý Tuấn Nghi ([@lytuannghi](https://github.com/lytuannghi))  
**Specialization:** AI Silicon Architecture, Digital RTL & SoC Integration  
**Target Architecture:** Heterogeneous RISC-V RV32I Processor + 4x4 Systolic Tensor Accelerator (NPU) + DMA Engine  

---

## 1. System Overview

The **Edge-AI Tensor SoC** is a commercial-grade, domain-specific embedded System-on-Chip designed for real-time neural network edge inference (e.g., TinyML, CNN, Dense Layers).

### Key Architectural Pillars:
1. **Host Processor:** 32-bit RISC-V RV32I Base Integer Core with 32 general-purpose registers (`x0-x31`) and multi-cycle bus handshake stall support.
2. **AI Tensor Accelerator (NPU):**
   - **Compute Engine:** $4 \times 4$ 2D Systolic Array consisting of 16 Processing Elements (PEs) performing INT8 Multiply-Accumulate (MAC) operations in parallel.
   - **Post-Processing Pipeline:** Hardware Bias Addition, Non-Linear **ReLU Activation** ($\max(0, x)$), and INT8 Re-quantization with Saturating Truncation.
3. **Data Movement & DMA Engine:**
   - Autonomous **Hardware DMA Controller** capable of bursting matrix tensors directly from SRAM to the NPU input buffers with **Zero CPU Overhead**.
   - Input and Weight **Skew Buffers** generating triangular wavefront timing.
4. **On-Chip Interconnect & Protocol Bridge:**
   - Multi-master interconnect bridging the CPU and DMA to dual-port Data SRAM and peripherals via AMBA 3 APB protocol.
5. **Peripheral & Console:** Industrial APB UART Controller with 64-byte deep FIFO for serial telemetry.

---

## 2. Address Memory Map

| Address Range | Device / Subsystem | Size | Bus Protocol | Description |
| :---: | :---: | :---: | :---: | :--- |
| `0x0000_0000 - 0x0000_07FF` | **Instruction Boot ROM** | 2 KB | Direct CPU | Holds pre-compiled bootloader & AI driver firmware. |
| `0x0000_0400 - 0x0000_0FFF` | **Data SRAM** | 3 KB | Dual-Port | Scratchpad for activations, weights, DMA buffers, and stack. |
| `0x8000_0000 - 0x8000_000F` | **APB UART IP** | 16 B | AMBA 3 APB | Serial TX/RX FIFOs, baud divisor, and status registers. |
| `0x9000_0000 - 0x9000_003F` | **Edge-AI NPU IP** | 64 B | AMBA 3 APB | NPU control, DMA configuration, bias, and output tensors. |

---

## 3. NPU Register Map (Base: `0x9000_0000`)

| Offset | Register Name | Access | Field Definitions |
| :---: | :---: | :---: | :--- |
| `0x00` | **`NPU_CTRL`** | R/W | `[0]` Start Compute, `[1]` Clear Acc, `[2]` Load Weight, `[3]` ReLU Enable, `[4]` Bias Enable, `[8:5]` Scale Shift (0..15). |
| `0x04` | **`NPU_STATUS`** | R | `[0]` NPU Busy, `[1]` NPU Done, `[2]` DMA Busy. |
| `0x08` | **`DMA_SRC_ADDR`**| R/W | 32-bit SRAM source byte address for DMA burst transfer. |
| `0x0C` | **`DMA_CFG`** | R/W | `[15:0]` Word Count (Number of 32-bit words), `[16]` Target Select (0: Weight Bank, 1: Activation Bank), `[31]` Trigger DMA Start. |
| `0x10` | **`BIAS_VAL`** | R/W | 24-bit signed layer bias value. |
| `0x20` | **`RES_ROW_0`** | R | Packed 4x INT8 post-processed matrix result for Row 0: `{C[0,3], C[0,2], C[0,1], C[0,0]}`. |
| `0x24` | **`RES_ROW_1`** | R | Packed 4x INT8 post-processed matrix result for Row 1: `{C[1,3], C[1,2], C[1,1], C[1,0]}`. |
| `0x28` | **`RES_ROW_2`** | R | Packed 4x INT8 post-processed matrix result for Row 2: `{C[2,3], C[2,2], C[2,1], C[2,0]}`. |
| `0x2C` | **`RES_ROW_3`** | R | Packed 4x INT8 post-processed matrix result for Row 3: `{C[3,3], C[3,2], C[3,1], C[3,0]}`. |

---

## 4. Systolic Array Wavefront Architecture

In the Output-Stationary $4 \times 4$ array, matrix inputs stream across space and time:
- Row $i$ of activations is delayed by $i$ clock cycles.
- Column $j$ of weights is delayed by $j$ clock cycles.
- Each PE $(i, j)$ accumulates the scalar product:
  $$Y_{i, j} = \text{ReLU}\left(\left(\sum_{k=0}^{3} A_{i, k} \times W_{k, j} + \text{Bias}\right) \gg \text{scale\_shift}\right)$$
- Total compute latency for a $4 \times 4$ tile: **11 clock cycles**.

```text
                  Weight W0    Weight W1    Weight W2    Weight W3
                     ↓            ↓            ↓            ↓
Feature X0 → [  PE (0,0)  ] → [  PE (0,1)  ] → [  PE (0,2)  ] → [  PE (0,3)  ]
                     ↓            ↓            ↓            ↓
Feature X1 → [  PE (1,0)  ] → [  PE (1,1)  ] → [  PE (1,2)  ] → [  PE (1,3)  ]
                     ↓            ↓            ↓            ↓
Feature X2 → [  PE (2,0)  ] → [  PE (2,1)  ] → [  PE (2,2)  ] → [  PE (2,3)  ]
                     ↓            ↓            ↓            ↓
Feature X3 → [  PE (3,0)  ] → [  PE (3,1)  ] → [  PE (3,2)  ] → [  PE (3,3)  ]
                     ↓            ↓            ↓            ↓
                [ PPU 0 ]    [ PPU 1 ]    [ PPU 2 ]    [ PPU 3 ]  (Bias + ReLU + Quantize)
```

---

## 5. Verification & Co-Simulation Results

```text
========================================================
🚀 STARTING EDGE-AI TENSOR SOC HARDWARE VERIFICATION
========================================================
ℹ️  Architecture: RV32I CPU + 4x4 Systolic Array + DMA + Post-Processing
ℹ️  System Reset Released. Booting RISC-V CPU from ROM...

📡 UART CONSOLE: AI NPU INFERENCE: PASS!

--------------------------------------------------------
📊 VERIFYING NPU ACCELERATOR & DATA SRAM INFERENCE RESULTS:
✅ [PASS] Firmware Completion Signature Verified: 0xcafeface
✅ [PASS] AI NPU Matrix Result Row 0 Verified: 0x04030202 (Non-zero INT8 Tensor)
✅ [PASS] UART Serial Console Transmission Verified (24 characters received)!
========================================================
🏆 STATUS: 100% EDGE-AI TENSOR SOC VERIFICATION PASSED!
========================================================
```
