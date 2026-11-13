#!/bin/bash
# =============================================================================
# Smart ControlSoC - PWM Standalone UVM Simulation Runner
# Compiles & executes tb_pwm_top integrating AXI4-Lite VIP, PWM Monitor, and DUT
# =============================================================================

set -e

# Setup Synopsys EDA environment
export VCS_HOME="${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}"
export VERDI_HOME="${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27021@14.139.1.126}"
export PATH=$VCS_HOME/bin:$VERDI_HOME/bin:$PATH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Available directed tests (13 tests)
VALID_TESTS=(
    "pwm_reset_reg_test"
    "pwm_reg_access_test"
    "pwm_zero_duty_test"
    "pwm_low_duty_test"
    "pwm_duty_25_test"
    "pwm_duty_50_test"
    "pwm_duty_75_test"
    "pwm_max_duty_test"
    "pwm_period_freq_test"
    "pwm_dynamic_update_test"
    "pwm_mid_op_reset_test"
    "pwm_back_to_back_test"
    "pwm_unmapped_access_test"
)

# Default test
TEST_NAME="pwm_duty_50_test"
EXTRA_ARGS=()

show_help() {
    echo "=================================================================="
    echo "   Smart ControlSoC: Standalone PWM UVM Simulation Runner         "
    echo "=================================================================="
    echo "Usage: ./run_pwm_uvm.sh [TEST_NAME | +UVM_TESTNAME=<name>] [EXTRA_ARGS...]"
    echo ""
    echo "Available Directed Tests (13 Tests):"
    for t in "${VALID_TESTS[@]}"; do
        echo "  - $t"
    done
    echo ""
    echo "Examples:"
    echo "  ./run_pwm_uvm.sh                                # Runs default: pwm_duty_50_test"
    echo "  ./run_pwm_uvm.sh pwm_zero_duty_test             # Runs zero duty cycle test"
    echo "  ./run_pwm_uvm.sh pwm_max_duty_test              # Runs maximum supported duty test"
    echo "  ./run_pwm_uvm.sh pwm_dynamic_update_test        # Runs on-the-fly dynamic update test"
    echo "  ./run_pwm_uvm.sh +UVM_VERBOSITY=UVM_HIGH        # Runs with high verbosity"
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
echo "   [1/2] Compiling Standalone PWM UVM Testbench (tb_pwm_top)     "
echo "=================================================================="

PLI_ARGS=()
if [ -d "$VERDI_HOME" ]; then
    PLI_ARGS+=(-P "$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab" "$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a" +define+FSDB)
fi

vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm \
    -top tb_pwm_top \
    "${PLI_ARGS[@]}" \
    -debug_access+all \
    -f tb/uvm/pwm/filelist_pwm_uvm.f \
    -o simv_pwm_uvm

echo ""
echo "=================================================================="
echo "   [2/2] Running PWM UVM Simulation: $TEST_NAME                  "
echo "=================================================================="
./simv_pwm_uvm +UVM_TESTNAME="$TEST_NAME" -no_save "${EXTRA_ARGS[@]}"

echo ""
echo "=================================================================="
echo "   PWM UVM Simulation Complete! Target test: $TEST_NAME          "
echo "=================================================================="

