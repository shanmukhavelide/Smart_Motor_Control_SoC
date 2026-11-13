#!/bin/bash
# =============================================================================
# Smart ControlSoC - Synthesizable VeeR EL2 Core Simulation Runner Script
# Compiles and simulates smart_controlsoc_veer_top with firmware_veer.hex
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Setup Synopsys EDA environment
export VCS_HOME=${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}
export VERDI_HOME=${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}
export SNPSLMD_LICENSE_FILE=${SNPSLMD_LICENSE_FILE:-27021@14.139.1.126}
export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH

MODE="${1:-vcs}"

if [ "$MODE" = "--lint" ] || [ "$MODE" = "lint" ]; then
    echo "=================================================================="
    echo "   Running Verilator Lint Check on Synthesizable VeeR EL2 SoC    "
    echo "=================================================================="
    verilator --lint-only -sv \
        +define+RV_OPENSOURCE \
        -f filelist_veer.f \
        --top-module tb_smart_controlsoc_veer_top \
        -Wno-fatal
    echo "[LINT PASSED] Verilator static check completed."
    exit 0
fi

echo "=================================================================="
echo "   [1/3] Building Bare-Metal VeeR Firmware Stack                 "
echo "=================================================================="
make -C sw veer

echo ""
echo "=================================================================="
echo "   [2/3] Compiling Synthesizable VeeR EL2 SoC with Synopsys VCS  "
echo "=================================================================="
if command -v vcs >/dev/null 2>&1; then
    vcs -full64 -sverilog -timescale=1ns/1ps \
        -top tb_smart_controlsoc_veer_top \
        -P "$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab" "$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a" \
        +define+VCS_DEBUG \
        -debug_access+all \
        -f filelist_veer.f \
        -o simv_veer
    
    echo ""
    echo "=================================================================="
    echo "   [3/3] Executing VCS Simulation with Synthesizable VeeR Core   "
    echo "=================================================================="
    ./simv_veer "$@"
else
    echo "[WARNING] VCS is not available in current environment."
    echo "Running Verilator lint check instead..."
    verilator --lint-only -sv +define+RV_OPENSOURCE -f filelist_veer.f --top-module tb_smart_controlsoc_veer_top -Wno-fatal
fi

