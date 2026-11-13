#!/bin/bash
# =============================================================================
# Smart ControlSoC - Per-IP UVM Testbench Runner (VCS)
#
# Compiles only the target IP's RTL plus tb/uvm/common and tb/uvm/<ip>
# using Synopsys VCS with -ntb_opts uvm-1.2, runs the specified test,
# logs all output to log/uvm_<ip>_<test>.log, and greps UVM_ERROR/UVM_FATAL counts.
#
# Usage:
#   ./script/run_uvm_vcs.sh <ip_name> <test_name> [extra_sim_args...]
#
# Examples:
#   ./script/run_uvm_vcs.sh pwm pwm_test
#   ./script/run_uvm_vcs.sh seg7 seg7_basic_test
#   ./script/run_uvm_vcs.sh spi spi_loopback_test +UVM_VERBOSITY=UVM_HIGH
# =============================================================================

set -e
set -o pipefail

# -----------------------------------------------------------------------------
# EDA Tool Environment Setup
# -----------------------------------------------------------------------------
export VCS_HOME="${VCS_HOME:-/home/student/snps_tools_target/vcs/U-2023.03}"
export VERDI_HOME="${VERDI_HOME:-/home/student/snps_tools_target/verdi/U-2023.03-SP1}"
export SNPSLMD_LICENSE_FILE="${SNPSLMD_LICENSE_FILE:-27021@14.139.1.126}"
export PATH="$VCS_HOME/bin:$VERDI_HOME/bin:$PATH"

# Resolve directories relative to repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# -----------------------------------------------------------------------------
# Argument Validation & Parsing
# -----------------------------------------------------------------------------
if [ $# -lt 2 ]; then
    echo "=================================================================="
    echo " Usage: $0 <ip_name> <test_name> [extra_args...]"
    echo "=================================================================="
    echo " Arguments:"
    echo "   ip_name    : Name of the IP block (e.g. pwm, seg7, spi, uart, gpio, timer, soc)"
    echo "   test_name  : UVM test name (e.g. pwm_test, seg7_basic_test)"
    echo "   extra_args : Optional extra simulation arguments (e.g. +UVM_VERBOSITY=UVM_HIGH)"
    echo "=================================================================="
    exit 1
fi

IP="$1"
TEST="$2"
shift 2
EXTRA_ARGS=("$@")

# Strip +UVM_TESTNAME= prefix if user passed it
if [[ "$TEST" == +UVM_TESTNAME=* ]]; then
    TEST="${TEST#+UVM_TESTNAME=}"
fi

# Normalize IP name
IP_LOWER="$(echo "$IP" | tr '[:upper:]' '[:lower:]')"
IP_NAME="${IP_LOWER%_directory}"

# Setup log directory and file
LOG_DIR="log"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/uvm_${IP}_${TEST}.log"
> "$LOG_FILE"

echo "=================================================================="
echo " Smart ControlSoC UVM Runner"
echo " Target IP  : $IP (normalized: $IP_NAME)"
echo " Test Name  : $TEST"
echo " Log File   : $LOG_FILE"
echo "=================================================================="

# -----------------------------------------------------------------------------
# [1/4] Determine Target IP RTL Files
# -----------------------------------------------------------------------------
IP_RTL_FILES=()
IP_INCDIRS=()

case "$IP_NAME" in
    pwm)
        IP_RTL_FILES=(
            "rtl/pwm_directory/rtl/myip_v1_0_S00_AXI.v"
            "rtl/pwm_directory/rtl/myip_v1_0.v"
        )
        ;;
    seg7)
        IP_RTL_FILES=(
            "rtl/seg7_directory/rtl/axi_seg7_slave.v"
            "rtl/seg7_directory/rtl/seg7_core.sv"
            "rtl/seg7_directory/rtl/axi_seg7_top.sv"
        )
        ;;
    spi)
        IP_INCDIRS+=("+incdir+rtl/spi_directory/include")
        IP_RTL_FILES=(
            "rtl/spi_directory/rtl/ratio_clk.v"
            "rtl/spi_directory/rtl/spi_clk_gen.v"
            "rtl/spi_directory/rtl/spi_ctrl.v"
            "rtl/spi_directory/rtl/spi_exch_byte.v"
            "rtl/spi_directory/rtl/spi_fifo.v"
            "rtl/spi_directory/rtl/spi_valid_logic.v"
            "rtl/spi_directory/rtl/axi_spi_ctrl.v"
            "rtl/spi_directory/rtl/axi_spi_top.v"
        )
        ;;
    uart)
        IP_INCDIRS+=("+incdir+rtl/uart_directory/include")
        IP_RTL_FILES=(
            "rtl/uart_directory/rtl/axi_internal_fifo.v"
            "rtl/uart_directory/rtl/uart_parity_bit_compute.v"
            "rtl/uart_directory/rtl/uart_receiver.v"
            "rtl/uart_directory/rtl/uart_transmitter.v"
            "rtl/uart_directory/rtl/uart_controller.v"
            "rtl/uart_directory/rtl/axi_uart_top.v"
        )
        ;;
    gpio)
        IP_INCDIRS+=("+incdir+rtl/gpio_directory/include")
        IP_RTL_FILES=(
            "rtl/gpio_directory/include/reg_bus.sv"
            "rtl/gpio_directory/include/common_cells/prim_subreg.sv"
            "rtl/gpio_directory/include/common_cells/prim_subreg_ext.sv"
            "rtl/gpio_directory/rtl/gpio_reg_pkg.sv"
            "rtl/gpio_directory/rtl/gpio_reg_top.sv"
            "rtl/gpio_directory/rtl/gpio_input_stage.sv"
            "rtl/gpio_directory/rtl/gpio.sv"
            "rtl/gpio_directory/rtl/axi_gpio_top.sv"
        )
        ;;
    timer)
        IP_RTL_FILES=(
            "rtl/timer_directory/rtl/timer_core.sv"
            "rtl/timer_directory/rtl/axi_timer_top.sv"
        )
        ;;
    aes)
        IP_RTL_FILES=(
            "rtl/aes_dire/axi_aes_cipher_slave.v"
        )
        ;;
    soc)
        IP_INCDIRS+=(
            "+incdir+rtl/interconnect"
            "+incdir+rtl/uart_directory/include"
            "+incdir+rtl/spi_directory/include"
            "+incdir+rtl/gpio_directory/include"
        )
        IP_RTL_FILES=(
            "rtl/gpio_directory/include/reg_bus.sv"
            "rtl/gpio_directory/include/common_cells/prim_subreg.sv"
            "rtl/gpio_directory/include/common_cells/prim_subreg_ext.sv"
            "rtl/Cores-VeeR-EL2/el2_veer_wrapper.v"
            "rtl/interconnect/arbiter.v"
            "rtl/interconnect/priority_encoder.v"
            "rtl/interconnect/axi_interconnect.v"
            "rtl/interconnect/axi_interconnect_wrap_2x6.v"
            "rtl/uart_directory/rtl/axi_internal_fifo.v"
            "rtl/uart_directory/rtl/uart_parity_bit_compute.v"
            "rtl/uart_directory/rtl/uart_receiver.v"
            "rtl/uart_directory/rtl/uart_transmitter.v"
            "rtl/uart_directory/rtl/uart_controller.v"
            "rtl/uart_directory/rtl/axi_uart_top.v"
            "rtl/timer_directory/rtl/timer_core.sv"
            "rtl/timer_directory/rtl/axi_timer_top.sv"
            "rtl/spi_directory/rtl/ratio_clk.v"
            "rtl/spi_directory/rtl/spi_clk_gen.v"
            "rtl/spi_directory/rtl/spi_ctrl.v"
            "rtl/spi_directory/rtl/spi_exch_byte.v"
            "rtl/spi_directory/rtl/spi_fifo.v"
            "rtl/spi_directory/rtl/spi_valid_logic.v"
            "rtl/spi_directory/rtl/axi_spi_ctrl.v"
            "rtl/spi_directory/rtl/axi_spi_top.v"
            "rtl/seg7_directory/rtl/axi_seg7_slave.v"
            "rtl/seg7_directory/rtl/seg7_core.sv"
            "rtl/seg7_directory/rtl/axi_seg7_top.sv"
            "rtl/pwm_directory/rtl/myip_v1_0_S00_AXI.v"
            "rtl/pwm_directory/rtl/myip_v1_0.v"
            "rtl/gpio_directory/rtl/gpio_reg_pkg.sv"
            "rtl/gpio_directory/rtl/gpio_reg_top.sv"
            "rtl/gpio_directory/rtl/gpio_input_stage.sv"
            "rtl/gpio_directory/rtl/gpio.sv"
            "rtl/gpio_directory/rtl/axi_gpio_top.sv"
            "rtl/smart_controlsoc_top.v"
        )
        ;;
    *)
        # Dynamic fallback for arbitrary / user-defined IP directories
        CANDIDATE_DIRS=("rtl/${IP_NAME}_directory" "rtl/${IP_NAME}" "rtl/${IP}")
        FOUND_DIR=""
        for d in "${CANDIDATE_DIRS[@]}"; do
            if [ -d "$d" ]; then
                FOUND_DIR="$d"
                break
            fi
        done

        if [ -n "$FOUND_DIR" ]; then
            if [ -d "$FOUND_DIR/include" ]; then
                IP_INCDIRS+=("+incdir+$FOUND_DIR/include")
            fi
            if [ -f "$FOUND_DIR/filelist.f" ]; then
                IP_RTL_FILES+=("-f" "$FOUND_DIR/filelist.f")
            elif [ -d "$FOUND_DIR/rtl" ]; then
                while IFS= read -r f; do
                    [ -n "$f" ] && IP_RTL_FILES+=("$f")
                done < <(find "$FOUND_DIR/rtl" -maxdepth 2 -type f \( -name "*.sv" -o -name "*.v" \) | sort)
            fi
        else
            echo "ERROR: Unknown IP '$IP'. RTL directory not found under rtl/."
            exit 1
        fi
        ;;
esac

# -----------------------------------------------------------------------------
# [2/4] Collect UVM Testbench Files (tb/uvm/common and tb/uvm/<ip>)
# -----------------------------------------------------------------------------
UVM_COMMON_DIR="tb/uvm/common"
UVM_IP_DIR=""
if [ -d "tb/uvm/${IP_NAME}" ]; then
    UVM_IP_DIR="tb/uvm/${IP_NAME}"
elif [ -d "tb/uvm/${IP}" ]; then
    UVM_IP_DIR="tb/uvm/${IP}"
fi

if [ -z "$UVM_IP_DIR" ]; then
    echo "ERROR: UVM testbench directory 'tb/uvm/${IP_NAME}' not found."
    exit 1
fi

TB_INCDIRS=()
TB_FILES=()

# Helper function to collect compilation units from a UVM TB directory
collect_tb_sources() {
    local dir="$1"
    [ ! -d "$dir" ] && return

    TB_INCDIRS+=("+incdir+$dir")

    # If an explicit filelist exists, prefer it
    if [ -f "$dir/filelist.f" ]; then
        TB_FILES+=("-f" "$dir/filelist.f")
        return
    elif [ -f "$dir/filelist.txt" ]; then
        TB_FILES+=("-f" "$dir/filelist.txt")
        return
    fi

    # Detect files included via `include so we do not compile them directly
    local inc_files
    inc_files=$(grep -rhoE '`include\s+"[^"]+"' "$dir" 2>/dev/null | sed -E 's/`include\s+"//;s/"//' | sort -u || true)

    # 1. Packages (*pkg*.sv)
    while IFS= read -r f; do
        if [ -n "$f" ]; then
            local bname
            bname="$(basename "$f")"
            if ! echo "$inc_files" | grep -qx "$bname"; then
                TB_FILES+=("$f")
            fi
        fi
    done < <(find "$dir" -maxdepth 2 -type f \( -name "*_pkg.sv" -o -name "*pkg*.sv" \) | sort)

    # 2. Interfaces (*if*.sv)
    while IFS= read -r f; do
        if [ -n "$f" ]; then
            local bname
            bname="$(basename "$f")"
            if ! echo "$inc_files" | grep -qx "$bname"; then
                TB_FILES+=("$f")
            fi
        fi
    done < <(find "$dir" -maxdepth 2 -type f \( -name "*_if.sv" -o -name "*if*.sv" \) | sort)

    # 3. Testbench top / standalone modules
    while IFS= read -r f; do
        if [ -n "$f" ]; then
            local bname
            bname="$(basename "$f")"
            if [[ "$bname" != *pkg* && "$bname" != *if* && "$bname" != *.svh ]]; then
                if ! echo "$inc_files" | grep -qx "$bname"; then
                    TB_FILES+=("$f")
                fi
            fi
        fi
    done < <(find "$dir" -maxdepth 2 -type f \( -name "*.sv" -o -name "*.v" \) | sort)
}

# Collect common UVM sources
if [ -d "$UVM_COMMON_DIR" ]; then
    collect_tb_sources "$UVM_COMMON_DIR"
fi

# Collect IP-specific UVM sources
collect_tb_sources "$UVM_IP_DIR"

# -----------------------------------------------------------------------------
# [3/4] VCS Compilation
# -----------------------------------------------------------------------------
SIMV_BIN="simv_uvm_${IP_NAME}"

# Setup Verdi PLI options if available
VERDI_OPTS=()
if [ -n "$VERDI_HOME" ] && [ -f "$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab" ]; then
    VERDI_OPTS+=(
        "-P" "$VERDI_HOME/share/PLI/VCS/LINUX64/novas.tab" "$VERDI_HOME/share/PLI/VCS/LINUX64/pli.a"
        "+define+FSDB"
    )
fi

echo "" | tee -a "$LOG_FILE"
echo "==================================================================" | tee -a "$LOG_FILE"
echo " [Step 1/2] Compiling $IP RTL + UVM Testbench with VCS" | tee -a "$LOG_FILE"
echo "==================================================================" | tee -a "$LOG_FILE"

VCS_CMD=(
    vcs -full64 -sverilog -timescale=1ns/1ps
    -ntb_opts uvm-1.2
    -debug_access+all
    "${VERDI_OPTS[@]}"
    "${IP_INCDIRS[@]}"
    "${TB_INCDIRS[@]}"
    "${IP_RTL_FILES[@]}"
    "${TB_FILES[@]}"
    -o "$SIMV_BIN"
)

echo "Compilation Command:" | tee -a "$LOG_FILE"
echo "${VCS_CMD[*]}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

"${VCS_CMD[@]}" 2>&1 | tee -a "$LOG_FILE"
COMPILE_STATUS=${PIPESTATUS[0]}

if [ $COMPILE_STATUS -ne 0 ]; then
    echo "ERROR: VCS compilation failed with status $COMPILE_STATUS. See $LOG_FILE for details." | tee -a "$LOG_FILE"
    exit $COMPILE_STATUS
fi

# -----------------------------------------------------------------------------
# [4/4] Simulation Execution & Result Verification
# -----------------------------------------------------------------------------
echo "" | tee -a "$LOG_FILE"
echo "==================================================================" | tee -a "$LOG_FILE"
echo " [Step 2/2] Running UVM Test: $TEST" | tee -a "$LOG_FILE"
echo "==================================================================" | tee -a "$LOG_FILE"

"./$SIMV_BIN" +UVM_TESTNAME="$TEST" "${EXTRA_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"
SIM_STATUS=${PIPESTATUS[0]}

echo "" | tee -a "$LOG_FILE"
echo "==================================================================" | tee -a "$LOG_FILE"
echo " UVM Verification Results Summary ($LOG_FILE)" | tee -a "$LOG_FILE"
echo "==================================================================" | tee -a "$LOG_FILE"

# Grep UVM_ERROR and UVM_FATAL messages and counts
if grep -q -E "UVM_(ERROR|FATAL)" "$LOG_FILE"; then
    grep -E "UVM_(ERROR|FATAL)" "$LOG_FILE" | tee -a "$LOG_FILE"
else
    echo "No UVM_ERROR or UVM_FATAL reported in simulation." | tee -a "$LOG_FILE"
fi

# Highlight final report count lines if present
if grep -q -E "UVM_(ERROR|FATAL)\s*:" "$LOG_FILE"; then
    echo "" | tee -a "$LOG_FILE"
    echo "Report Severity Counts:" | tee -a "$LOG_FILE"
    grep -E "UVM_(ERROR|FATAL)\s*:" "$LOG_FILE" | tee -a "$LOG_FILE"
fi

echo "==================================================================" | tee -a "$LOG_FILE"

# Determine pass/fail based on sim status and error counts
if [ $SIM_STATUS -ne 0 ]; then
    echo "TEST FAILED: Simulation process exited with error status $SIM_STATUS." | tee -a "$LOG_FILE"
    exit $SIM_STATUS
fi

if grep -E "UVM_FATAL\s*:\s*[1-9]" "$LOG_FILE" >/dev/null 2>&1 || \
   grep -E "UVM_ERROR\s*:\s*[1-9]" "$LOG_FILE" >/dev/null 2>&1; then
    echo "TEST FAILED: Non-zero UVM_ERROR or UVM_FATAL detected." | tee -a "$LOG_FILE"
    exit 1
fi

echo "TEST PASSED: 0 UVM_ERROR and 0 UVM_FATAL detected." | tee -a "$LOG_FILE"
exit 0
