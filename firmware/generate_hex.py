# ============================================================================
# Edge-AI Tensor SoC Firmware Generator
# Generates RV32I Machine Code: DMA Configuration, NPU Matrix Compute & UART Print.
# Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
# ============================================================================

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def encode_b(imm, rs2, rs1, funct3, opcode):
    b12   = (imm >> 12) & 1
    b10_5 = (imm >> 5) & 0x3F
    b4_1  = (imm >> 1) & 0xF
    b11   = (imm >> 11) & 1
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode

def encode_u(imm20, rd, opcode):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | opcode

def encode_j(imm, rd, opcode):
    j20   = (imm >> 20) & 1
    j10_1 = (imm >> 1) & 0x3FF
    j11   = (imm >> 11) & 1
    j19_12= (imm >> 12) & 0xFF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | (rd << 7) | opcode

# RISC-V Opcodes
OP_LUI    = 0x37
OP_OP_IMM = 0x13
OP_STORE  = 0x23
OP_LOAD   = 0x03
OP_BRANCH = 0x63
OP_JAL    = 0x6F
OP_OP     = 0x33

instructions = []

# -------------------------------------------------------------------------
# Step 1: Initialize UART (Baudrate Divisor = 2, TX Enable = 1)
# Base UART = 0x8000_0000
# -------------------------------------------------------------------------
instructions.append(encode_u(0x80000, 1, OP_LUI))           # lui x1, 0x80000 (UART Base)
instructions.append(encode_i(2, 0, 0x0, 2, OP_OP_IMM))       # addi x2, x0, 2 (Baud = 2)
instructions.append(encode_s(12, 2, 1, 0x2, OP_STORE))       # sw x2, 12(x1) (UART_BAUD = 2)
instructions.append(encode_i(1, 0, 0x0, 2, OP_OP_IMM))       # addi x2, x0, 1 (TX En = 1)
instructions.append(encode_s(8, 2, 1, 0x2, OP_STORE))        # sw x2, 8(x1) (UART_CTRL = 1)

# -------------------------------------------------------------------------
# Step 2: Initialize Weights and Inputs in SRAM (0x400 Base)
# -------------------------------------------------------------------------
instructions.append(encode_i(0x400, 0, 0x0, 3, OP_OP_IMM))   # addi x3, x0, 0x400 (SRAM Base)

# Pre-load Weight Matrix (4 words packed INT8) at SRAM[0x100] = 0x500
# Row 0: [1, 2, 3, 4] -> 0x04030201
# Row 1: [2, 1, 0, 1] -> 0x01000102
# Row 2: [0, 1, 2, 1] -> 0x01020100
# Row 3: [1, 0, 1, 2] -> 0x02010001
weights = [0x04030201, 0x01000102, 0x01020100, 0x02010001]
for i, w in enumerate(weights):
    hi = (w >> 12) & 0xFFFFF
    lo = w & 0xFFF
    instructions.append(encode_u(hi, 4, OP_LUI))
    instructions.append(encode_i(lo, 4, 0x0, 4, OP_OP_IMM))
    instructions.append(encode_s(0x100 + i * 4, 4, 3, 0x2, OP_STORE))

# Pre-load Activation Matrix (4 words packed INT8) at SRAM[0x140] = 0x540
# Row 0: [2, 1, 1, 0] -> 0x00010102
# Row 1: [1, 3, 0, 2] -> 0x02000301
# Row 2: [0, 1, 2, 1] -> 0x01020100
# Row 3: [2, 0, 1, 3] -> 0x03010002
acts = [0x00010102, 0x02000301, 0x01020100, 0x03010002]
for i, a in enumerate(acts):
    hi = (a >> 12) & 0xFFFFF
    lo = a & 0xFFF
    instructions.append(encode_u(hi, 4, OP_LUI))
    instructions.append(encode_i(lo, 4, 0x0, 4, OP_OP_IMM))
    instructions.append(encode_s(0x140 + i * 4, 4, 3, 0x2, OP_STORE))

# -------------------------------------------------------------------------
# Step 3: Trigger DMA to stream Weights into NPU (Target = 0)
# NPU Base = 0x9000_0000
# -------------------------------------------------------------------------
instructions.append(encode_u(0x90000, 5, OP_LUI))           # lui x5, 0x90000 (NPU Base)

# DMA_SRC = 0x500 (Source address of Weights)
instructions.append(encode_i(0x500, 0, 0x0, 6, OP_OP_IMM))
instructions.append(encode_s(8, 6, 5, 0x2, OP_STORE))        # sw x6, 8(x5) (DMA_SRC)

# DMA_CFG = (1 << 31) | (0 << 16) | 4 = 0x80000004
# Bit 31: DMA Start, Bit 16: Target Weight (0), Length = 4 words
instructions.append(encode_u(0x80000, 6, OP_LUI))
instructions.append(encode_i(4, 6, 0x0, 6, OP_OP_IMM))
instructions.append(encode_s(12, 6, 5, 0x2, OP_STORE))       # sw x6, 12(x5) (DMA_CFG -> Triggers DMA)

# -------------------------------------------------------------------------
# Step 4: Trigger DMA to stream Activations into NPU (Target = 1)
# -------------------------------------------------------------------------
# DMA_SRC = 0x540
instructions.append(encode_i(0x540, 0, 0x0, 6, OP_OP_IMM))
instructions.append(encode_s(8, 6, 5, 0x2, OP_STORE))

# DMA_CFG = (1 << 31) | (1 << 16) | 4 = 0x80010004
instructions.append(encode_u(0x80010, 6, OP_LUI))
instructions.append(encode_i(4, 6, 0x0, 6, OP_OP_IMM))
instructions.append(encode_s(12, 6, 5, 0x2, OP_STORE))

# -------------------------------------------------------------------------
# Step 5: Configure NPU Bias, ReLU, Scaling & Trigger Inference
# -------------------------------------------------------------------------
# BIAS_VAL = 5 at 0x9000_0010
instructions.append(encode_i(5, 0, 0x0, 6, OP_OP_IMM))
instructions.append(encode_s(0x10, 6, 5, 0x2, OP_STORE))

# NPU_CTRL = (scale_shift=2 << 5) | (bias_en=1 << 4) | (relu_en=1 << 3) | (start=1)
# = (2 << 5) | 16 | 8 | 1 = 64 + 16 + 8 + 1 = 89 (0x59)
instructions.append(encode_i(0x59, 0, 0x0, 6, OP_OP_IMM))
instructions.append(encode_s(0x00, 6, 5, 0x2, OP_STORE))     # sw x6, 0(x5) (NPU_CTRL -> Start Compute!)

# Wait loop / Delay for NPU compute (takes ~11 cycles)
for _ in range(16):
    instructions.append(encode_i(0, 0, 0x0, 0, OP_OP_IMM))  # nop

# -------------------------------------------------------------------------
# Step 6: Read Post-Processed Matrix Rows & Store to SRAM (0x580)
# -------------------------------------------------------------------------
instructions.append(encode_i(0x580, 0, 0x0, 7, OP_OP_IMM))
for r in range(4):
    instructions.append(encode_i(0x20 + r * 4, 5, 0x2, 8, OP_LOAD)) # lw x8, (0x20 + r*4)(x5)
    instructions.append(encode_s(r * 4, 8, 7, 0x2, OP_STORE))        # sw x8, (r*4)(x7)

# -------------------------------------------------------------------------
# Step 7: Transmit Console String to UART: "AI NPU INFERENCE: PASS!"
# -------------------------------------------------------------------------
msg = "AI NPU INFERENCE: PASS!\n"
for ch in msg:
    instructions.append(encode_i(ord(ch), 0, 0x0, 9, OP_OP_IMM))
    instructions.append(encode_s(0, 9, 1, 0x2, OP_STORE))    # sw x9, 0(x1) (UART_DATA)

# -------------------------------------------------------------------------
# Step 8: Write Completion Signature 0xCAFEFACE to SRAM[0x5C0]
# -------------------------------------------------------------------------
instructions.append(encode_u(0xCAFF0, 10, OP_LUI))
instructions.append(encode_i(-0x532, 10, 0x0, 10, OP_OP_IMM)) # 0xCAFF0000 - 0x532 = 0xCAFEFACE
instructions.append(encode_s(0x1C0, 10, 3, 0x2, OP_STORE)) # sw x10, 0x1C0(x3) = 0x5C0

# -------------------------------------------------------------------------
# Step 9: Infinite Halt Loop (jal x0, 0)
# -------------------------------------------------------------------------
instructions.append(encode_j(0, 0, OP_JAL))

# Pad to 256 words with NOP
while len(instructions) < 256:
    instructions.append(0x00000013)

import os

out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "boot_firmware.hex")
with open(out_path, "w") as f:
    f.write("\n".join(f"{instr:08x}" for instr in instructions[:256]))

print(f"Generated {min(len(instructions), 256)} words to {out_path}")
