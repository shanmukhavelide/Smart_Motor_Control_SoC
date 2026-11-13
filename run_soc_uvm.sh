#!/bin/bash
# =============================================================================
# Smart ControlSoC - SoC-Level UVM Verification Runner (tb_soc_uvm_top)
# Compiles & executes tb_soc_uvm_top integrating 6 peripherals:
# UART, Timer, GPIO, SPI, Seven-Segment Display (SEG7), PWM
# =============================================================================

set -e

# Setup Synopsys EDA environment
export VCS_HOME="${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}"
export VERDI_HOME="${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27021@14.139.1.126}"
export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Available directed tests
VALID_TESTS=(
    "soc_reset_test"
    "soc_smoke_test"
    "soc_uart_test"
    "soc_gpio_test"
    "soc_timer_test"
    "soc_spi_test"
    "soc_pwm_test"
    "soc_seg7_test"
    "soc_multi_peripheral_test"
    "soc_concurrent_test"
    "soc_reset_recovery_test"
    "soc_test"
    "uart_connectivity_test"
    "gpio_test"
    "pwm_test"
    "spi_test"
)

# Default test
TEST_NAME="soc_multi_peripheral_test"
EXTRA_ARGS=()

show_help() {
    echo "=================================================================="
    echo "   Smart ControlSoC: Top-Level SoC UVM Simulation Runner          "
    echo "=================================================================="
    echo "Usage: ./run_soc_uvm.sh [TEST_NAME | +UVM_TESTNAME=<name>] [EXTRA_ARGS...]"
    echo ""
    echo "Available Directed Tests (11 SoC Tests):"
    for t in "${VALID_TESTS[@]}"; do
        echo "  - $t"
    done
    echo ""
    echo "Examples:"
    echo "  ./run_soc_uvm.sh                                # Runs default: soc_multi_peripheral_test"
    echo "  ./run_soc_uvm.sh soc_smoke_test                 # Runs peripheral smoke test"
    echo "  ./run_soc_uvm.sh soc_seg7_test                  # Runs Seven-Segment SoC integration test"
    echo "  ./run_soc_uvm.sh soc_concurrent_test            # Runs concurrent peripheral activity test"
    echo "  ./run_soc_uvm.sh +UVM_VERBOSITY=UVM_HIGH        # Runs with high verbosity"
    echo "=================================================================="
    exit 0
}

# Parse command line arguments
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        show_help
    elif [[ "$arg" == +UVM_TESTNAME=* ]]; then
        TEST_NAME="${arg#+UVM_TESTNAME=}"
    elif [[ "$arg" =~ ^[+-] ]]; then
        EXTRA_ARGS+=("$arg")
    else
        is_known_test=0
        for vt in "${VALID_TESTS[@]}"; do
            if [[ "$arg" == "$vt" ]]; then
                TEST_NAME="$arg"
                is_known_test=1
                break
            fi
        done
        if [[ $is_known_test -eq 0 ]]; then
            echo "ERROR: Unknown test name: '$arg'"
            show_help
        fi
    fi
done

echo "=================================================================="
echo "   [1/2] Compiling SoC-Level UVM Testbench (tb_soc_uvm_top)       "
echo "=================================================================="

PLI_ARGS=()
if [ -d "$VERDI_HOME" ]; then
    PLI_ARGS+=(-P "$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab" "$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a" +define+FSDB)
fi

vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm \
    -top tb_soc_uvm_top \
    "${PLI_ARGS[@]}" \
    -debug_access+all \
    -f tb/uvm/soc/filelist_soc_uvm.f \
    -o simv_soc_uvm

echo ""
echo "=================================================================="
echo "   [2/2] Running SoC UVM Test: $TEST_NAME                        "
echo "=================================================================="
./simv_soc_uvm +UVM_TESTNAME="$TEST_NAME" -no_save "${EXTRA_ARGS[@]}"

echo ""
echo "=================================================================="
echo "   SoC UVM Simulation Complete! Target test: $TEST_NAME          "
echo "=================================================================="
