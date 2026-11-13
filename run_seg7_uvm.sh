#!/bin/bash
# =============================================================================
# Smart ControlSoC - Seven-Segment Display (SEG7) Standalone UVM Runner
# Compiles & executes tb_seg7_top integrating AXI4-Lite VIP, SEG7 VIP, and DUT
# =============================================================================

set -e

# Setup Synopsys EDA environment
export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export VERDI_HOME=/home/student/snps_tools_target/verdi/U-2023.03-SP1
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126
export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Available directed tests
VALID_TESTS=(
    "seg7_basic_reg_test"
    "seg7_hex_display_test"
    "seg7_scan_mask_test"
    "seg7_dp_control_test"
    "seg7_polarity_test"
    "seg7_full_hex_sweep_test"
    "seg7_refresh_boundary_test"
    "seg7_async_reset_test"
)

# Default test
TEST_NAME="seg7_basic_reg_test"
EXTRA_ARGS=()

show_help() {
    echo "=================================================================="
    echo "   Smart ControlSoC: Standalone SEG7 UVM Simulation Runner       "
    echo "=================================================================="
    echo "Usage: ./run_seg7_uvm.sh [TEST_NAME | +UVM_TESTNAME=<name>] [EXTRA_ARGS...]"
    echo ""
    echo "Available Directed Tests:"
    for t in "${VALID_TESTS[@]}"; do
        echo "  - $t"
    done
    echo ""
    echo "Examples:"
    echo "  ./run_seg7_uvm.sh                                # Runs default: seg7_basic_reg_test"
    echo "  ./run_seg7_uvm.sh seg7_full_hex_sweep_test       # Runs full 128-cross hex sweep"
    echo "  ./run_seg7_uvm.sh seg7_refresh_boundary_test     # Runs divider boundary test"
    echo "  ./run_seg7_uvm.sh seg7_async_reset_test          # Runs asynchronous reset test"
    echo "  ./run_seg7_uvm.sh +UVM_VERBOSITY=UVM_HIGH        # Runs with high verbosity"
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
            echo "ERROR: Unknown test name or unrecognized argument: '$arg'"
            echo "Available tests:"
            for vt in "${VALID_TESTS[@]}"; do
                echo "  - $vt"
            done
            exit 1
        fi
    fi
done

# Validate selected TEST_NAME against registered tests
test_is_valid=0
for vt in "${VALID_TESTS[@]}"; do
    if [[ "$TEST_NAME" == "$vt" ]]; then
        test_is_valid=1
        break
    fi
done

if [[ $test_is_valid -eq 0 ]]; then
    echo "ERROR: Invalid UVM test name: '$TEST_NAME'"
    echo "Available tests:"
    for vt in "${VALID_TESTS[@]}"; do
        echo "  - $vt"
    done
    exit 1
fi

echo "=================================================================="
echo "   [1/2] Compiling Standalone SEG7 UVM Testbench (tb_seg7_top)   "
echo "=================================================================="

# Optional Verdi PLI linking if VERDI_HOME exists
PLI_ARGS=()
if [ -d "$VERDI_HOME" ]; then
    PLI_ARGS+=(-P "$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab" "$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a" +define+FSDB)
fi

# Note: -debug_access+all enables VPI backdoor visibility required for uvm_hdl_force/release
vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm \
    -top tb_seg7_top \
    "${PLI_ARGS[@]}" \
    -debug_access+all \
    -f tb/uvm/seg7/filelist_seg7_uvm.f \
    -o simv_seg7_uvm

echo ""
echo "=================================================================="
echo "   [2/2] Running SEG7 UVM Simulation: $TEST_NAME                 "
echo "=================================================================="
./simv_seg7_uvm +UVM_TESTNAME="$TEST_NAME" -no_save "${EXTRA_ARGS[@]}"

echo ""
echo "=================================================================="
echo "   SEG7 UVM Simulation Complete! Target test: $TEST_NAME          "
echo "=================================================================="

