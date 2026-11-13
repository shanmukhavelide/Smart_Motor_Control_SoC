#!/bin/bash
# =============================================================================
# Smart ControlSoC - SPI Standalone UVM Simulation Runner
# Compiles & executes tb_spi_top integrating AXI4-Lite VIP, SPI Slave Model, Monitor, and DUT
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
    "spi_reset_reg_test"
    "spi_reg_access_test"
    "spi_clk_div_test"
    "spi_tx_byte_test"
    "spi_rx_byte_test"
    "spi_full_duplex_test"
    "spi_multi_byte_test"
    "spi_slave_select_test"
    "spi_back_to_back_test"
    "spi_data_patterns_test"
    "spi_mid_transfer_reset_test"
    "spi_status_flags_test"
    "spi_invalid_access_test"
)

# Default test
TEST_NAME="spi_full_duplex_test"
EXTRA_ARGS=()

show_help() {
    echo "=================================================================="
    echo "   Smart ControlSoC: Standalone SPI UVM Simulation Runner         "
    echo "=================================================================="
    echo "Usage: ./run_spi_uvm.sh [TEST_NAME | +UVM_TESTNAME=<name>] [EXTRA_ARGS...]"
    echo ""
    echo "Available Directed Tests (13 Tests):"
    for t in "${VALID_TESTS[@]}"; do
        echo "  - $t"
    done
    echo ""
    echo "Examples:"
    echo "  ./run_spi_uvm.sh                                # Runs default: spi_full_duplex_test"
    echo "  ./run_spi_uvm.sh spi_tx_byte_test               # Runs single byte transmit test"
    echo "  ./run_spi_uvm.sh spi_multi_byte_test            # Runs 4-byte burst transfer test"
    echo "  ./run_spi_uvm.sh spi_clk_div_test               # Runs clock divider sweep test"
    echo "  ./run_spi_uvm.sh +UVM_VERBOSITY=UVM_HIGH        # Runs with high verbosity"
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
echo "   [1/2] Compiling Standalone SPI UVM Testbench (tb_spi_top)     "
echo "=================================================================="

PLI_ARGS=()
if [ -d "$VERDI_HOME" ]; then
    PLI_ARGS+=(-P "$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab" "$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a" +define+FSDB)
fi

vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm \
    -top tb_spi_top \
    "${PLI_ARGS[@]}" \
    -debug_access+all \
    -f tb/uvm/spi/filelist_spi_uvm.f \
    -o simv_spi_uvm

echo ""
echo "=================================================================="
echo "   [2/2] Running SPI UVM Simulation: $TEST_NAME                  "
echo "=================================================================="
./simv_spi_uvm +UVM_TESTNAME="$TEST_NAME" -no_save "${EXTRA_ARGS[@]}"

echo ""
echo "=================================================================="
echo "   SPI UVM Simulation Complete! Target test: $TEST_NAME          "
echo "=================================================================="

