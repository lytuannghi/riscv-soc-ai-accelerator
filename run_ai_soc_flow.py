# ============================================================================
# Master Orchestrator & EDA Simulator for Edge-AI Tensor SoC
# Author: Lý Tuấn Nghi (lytuannghi) & Edge-AI SoC Team
# ============================================================================

import subprocess
import os

IVERILOG_PATH = r"D:\CODE\GGANTIGRAVITY\iverilog\bin\iverilog.exe"
VVP_PATH = r"D:\CODE\GGANTIGRAVITY\iverilog\bin\vvp.exe"

def run_ai_soc():
    print("=" * 70)
    print("🚀 EXECUTING EDGE-AI TENSOR SOC AUTOMATED VERIFICATION FLOW")
    print("=" * 70)

    base_dir = r"D:\CODE\GGANTIGRAVITY\riscv-soc-ai-accelerator"
    rtl_files = [
        os.path.join(base_dir, "rtl", "cpu", "riscv_alu.v"),
        os.path.join(base_dir, "rtl", "cpu", "riscv_regfile.v"),
        os.path.join(base_dir, "rtl", "cpu", "riscv_core.v"),
        os.path.join(base_dir, "rtl", "npu", "pe.v"),
        os.path.join(base_dir, "rtl", "npu", "skew_buffer.v"),
        os.path.join(base_dir, "rtl", "npu", "systolic_array_4x4.v"),
        os.path.join(base_dir, "rtl", "npu", "post_process_unit.v"),
        os.path.join(base_dir, "rtl", "npu", "npu_dma.v"),
        os.path.join(base_dir, "rtl", "npu", "npu_top.v"),
        os.path.join(base_dir, "rtl", "bus", "soc_interconnect.v"),
        os.path.join(base_dir, "rtl", "uart", "fifo_sync.v"),
        os.path.join(base_dir, "rtl", "uart", "baudrate_gen.v"),
        os.path.join(base_dir, "rtl", "uart", "uart_tx.v"),
        os.path.join(base_dir, "rtl", "uart", "uart_rx.v"),
        os.path.join(base_dir, "rtl", "uart", "apb_slave_regs.v"),
        os.path.join(base_dir, "rtl", "uart", "apb_uart_top.v"),
        os.path.join(base_dir, "rtl", "soc_top.v")
    ]
    tb_file = os.path.join(base_dir, "tb", "soc_ai_tb.v")
    vvp_out = r"D:\CODE\GGANTIGRAVITY\minipj\output\ai_soc_sim.vvp"

    print("[Step 1/3] ⚙️ Compiling RISC-V CPU, Systolic NPU, DMA & APB Bus with Icarus Verilog...")
    cmd_compile = [IVERILOG_PATH, "-g2005", "-o", vvp_out] + rtl_files + [tb_file]
    res_comp = subprocess.run(cmd_compile, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)

    if res_comp.returncode != 0:
        print("❌ Compilation Failed:\n", res_comp.stderr)
        return False
    print("✅ Compilation Successful -> Generated:", vvp_out)

    print("[Step 2/3] 🔬 Executing VVP Simulation Engine & Monitoring Tensor Inference...")
    res_sim = subprocess.run([VVP_PATH, vvp_out], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    output = (res_sim.stdout or "") + ("\n" + res_sim.stderr if res_sim.stderr else "")
    print(output)

    if "100% EDGE-AI TENSOR SOC VERIFICATION PASSED" in output:
        print("=" * 70)
        print("🎉 SUCCESS: 100% PASS! EDGE-AI TENSOR SOC COMPLETED INFERENCE & DMA!")
        print("  - Waveform generated: D:/CODE/GGANTIGRAVITY/minipj/output/riscv_ai_soc_waveform.vcd")
        print("=" * 70)
        return True
    else:
        print("⚠️ Simulation did not achieve 100% pass.")
        return False

if __name__ == "__main__":
    run_ai_soc()
