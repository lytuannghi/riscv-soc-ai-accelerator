# ============================================================================
# Master Orchestrator & EDA Simulator for Edge-AI Tensor SoC
# Author: Ly Tuan Nghi (lytuannghi) & Edge-AI SoC Team
# ============================================================================

import os
import shutil
import subprocess
import sys


def resolve_tool(name):
    found = shutil.which(name)
    if found:
        return found
    base_dir = os.path.dirname(os.path.abspath(__file__))
    sibling = os.path.join(os.path.dirname(base_dir), "iverilog", "bin", name + ".exe")
    return sibling if os.path.exists(sibling) else name


def run_ai_soc():
    print("=" * 70)
    print("  EXECUTING EDGE-AI TENSOR SOC AUTOMATED VERIFICATION FLOW")
    print("=" * 70)

    base_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(base_dir)
    os.makedirs("sim", exist_ok=True)

    iverilog_exe = resolve_tool("iverilog")
    vvp_exe = resolve_tool("vvp")

    rtl_files = [
        "rtl/cpu/riscv_alu.v",
        "rtl/cpu/riscv_regfile.v",
        "rtl/cpu/riscv_core.v",
        "rtl/npu/pe.v",
        "rtl/npu/skew_buffer.v",
        "rtl/npu/systolic_array_4x4.v",
        "rtl/npu/post_process_unit.v",
        "rtl/npu/npu_dma.v",
        "rtl/npu/npu_top.v",
        "rtl/bus/soc_interconnect.v",
        "rtl/uart/fifo_sync.v",
        "rtl/uart/baudrate_gen.v",
        "rtl/uart/uart_tx.v",
        "rtl/uart/uart_rx.v",
        "rtl/uart/apb_slave_regs.v",
        "rtl/uart/apb_uart_top.v",
        "rtl/soc_top.v",
    ]
    tb_file = "tb/soc_ai_tb.v"
    vvp_out = "sim/ai_soc_sim.vvp"

    print("[Step 1/2] Compiling RISC-V CPU, Systolic NPU, DMA & APB Bus (-Wall)...")
    cmd_compile = [iverilog_exe, "-Wall", "-g2005", "-o", vvp_out] + rtl_files + [tb_file]
    res_comp = subprocess.run(cmd_compile, capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)

    if res_comp.returncode != 0 or res_comp.stderr.strip():
        print("[COMPILE FAILURE/WARNINGS]:\n", res_comp.stderr, res_comp.stdout)
        return 1
    print("[PASS] Compilation Clean (0 warnings) ->", vvp_out)

    print("[Step 2/2] Executing VVP Simulation Engine & Monitoring Tensor Inference...")
    res_sim = subprocess.run([vvp_exe, vvp_out], capture_output=True, text=True, encoding="utf-8", errors="replace", check=False)
    output = (res_sim.stdout or "") + ("\n" + res_sim.stderr if res_sim.stderr else "")
    print(output)

    if "100% EDGE-AI TENSOR SOC VERIFICATION PASSED" in output and "[FAIL]" not in output and res_sim.returncode == 0:
        print("=" * 70)
        print("SUCCESS: 100% PASS! EDGE-AI TENSOR SOC COMPLETED INFERENCE & DMA!")
        print("  - Waveform generated: sim/riscv_ai_soc_waveform.vcd")
        print("=" * 70)
        return 0
    print("[FAILURE] Simulation did not achieve 100% pass.")
    return 1


if __name__ == "__main__":
    sys.exit(run_ai_soc())
