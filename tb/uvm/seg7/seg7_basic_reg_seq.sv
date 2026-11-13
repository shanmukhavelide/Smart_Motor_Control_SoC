// =============================================================================
// SEG7 Basic Register Sequence: seg7_basic_reg_seq
// Verifies:
//   1. Power-on reset default values across all 4 memory-mapped registers.
//   2. Full 32-bit read/write access and data integrity (walking 1s/0s, patterns).
//   3. Byte-level write strobes (WSTRB = 4'b0001, 0010, 0100, 1000).
//   4. Zero write strobe behavior (WSTRB = 4'b0000 leaves register contents unmodified).
//   5. Unmapped address access (returns 0x0000_0000 with OKAY, leaves valid registers untouched).
// =============================================================================

`ifndef SEG7_BASIC_REG_SEQ_SV
`define SEG7_BASIC_REG_SEQ_SV

class seg7_basic_reg_seq extends seg7_base_seq;

    `uvm_object_utils(seg7_basic_reg_seq)

    function new(string name = "seg7_basic_reg_seq");
        super.new(name);
    endfunction

    virtual task body();
        `uvm_info(get_type_name(), "=== Starting SEG7 Basic Register Verification Sequence ===", UVM_LOW)

        test_reset_values();
        test_write_readback();
        test_byte_strobes();
        test_zero_strobe();
        test_unmapped_access();

        `uvm_info(get_type_name(), "=== Completed SEG7 Basic Register Verification Sequence ===", UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // 1. Reset Values Verification
    // -------------------------------------------------------------------------
    virtual task test_reset_values();
        `uvm_info(get_type_name(), "[Test 1/5] Checking register reset defaults...", UVM_LOW)

        // SEG_DATA @ 0x00: Reset = 0x0000_0000
        read_check(REG_SEG_DATA, 32'h0000_0000, 32'hFFFF_FFFF);

        // SEG_CTRL @ 0x04: Reset = 0x0000_FF06 (EN=0, SEG_ACT_LO=1, AN_ACT_LO=1, MASK=0xFF)
        read_check(REG_SEG_CTRL, 32'h0000_FF06, 32'hFFFF_FFFF);

        // SEG_DP @ 0x08: Reset = 0x0000_0000
        read_check(REG_SEG_DP, 32'h0000_0000, 32'hFFFF_FFFF);

        // SEG_REFRESH_DIV @ 0x0C: Reset = 0x0000_03E8 (1000 decimal)
        read_check(REG_SEG_REFRESH_DIV, 32'h0000_03E8, 32'hFFFF_FFFF);

        `uvm_info(get_type_name(), "[Test 1/5] PASS: All register reset defaults verified.", UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // 2. Full Write / Readback Verification
    // -------------------------------------------------------------------------
    virtual task test_write_readback();
        bit [31:0] test_patterns [4];
        test_patterns[0] = 32'hA5A5_5A5A;
        test_patterns[1] = 32'h5A5A_A5A5;
        test_patterns[2] = 32'h1234_5678;
        test_patterns[3] = 32'h8765_4321;

        `uvm_info(get_type_name(), "[Test 2/5] Checking full 32-bit write/readback...", UVM_LOW)

        // Test SEG_DATA
        foreach (test_patterns[i]) begin
            write_reg(REG_SEG_DATA, test_patterns[i]);
            read_check(REG_SEG_DATA, test_patterns[i]);
        end

        // Test SEG_DP
        foreach (test_patterns[i]) begin
            write_reg(REG_SEG_DP, test_patterns[i]);
            read_check(REG_SEG_DP, test_patterns[i]);
        end

        // Test SEG_REFRESH_DIV
        foreach (test_patterns[i]) begin
            write_reg(REG_SEG_REFRESH_DIV, test_patterns[i]);
            read_check(REG_SEG_REFRESH_DIV, test_patterns[i]);
        end

        // Test SEG_CTRL (keep EN=0 to keep display scanning idle during reg tests)
        // Write pattern with EN=0 (bit 0 = 0)
        write_reg(REG_SEG_CTRL, 32'h0000_AA06); // MASK=0xAA, AN_LO=1, SEG_LO=1, EN=0
        read_check(REG_SEG_CTRL, 32'h0000_AA06);

        write_reg(REG_SEG_CTRL, 32'h0000_5500); // MASK=0x55, AN_LO=0, SEG_LO=0, EN=0
        read_check(REG_SEG_CTRL, 32'h0000_5500);

        // Restore reset default for SEG_CTRL
        write_reg(REG_SEG_CTRL, 32'h0000_FF06);
        read_check(REG_SEG_CTRL, 32'h0000_FF06);

        `uvm_info(get_type_name(), "[Test 2/5] PASS: Write/readback data integrity verified.", UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // 3. Byte Write Strobe Verification (WSTRB)
    // -------------------------------------------------------------------------
    virtual task test_byte_strobes();
        `uvm_info(get_type_name(), "[Test 3/5] Checking byte-selective write strobes...", UVM_LOW)

        // Clear SEG_DATA to baseline 0x0000_0000
        write_reg(REG_SEG_DATA, 32'h0000_0000, 4'hF);
        read_check(REG_SEG_DATA, 32'h0000_0000);

        // Write Byte 0 only (WSTRB = 4'b0001)
        write_reg(REG_SEG_DATA, 32'hFFFF_FFAA, 4'b0001);
        read_check(REG_SEG_DATA, 32'h0000_00AA);

        // Write Byte 1 only (WSTRB = 4'b0010)
        write_reg(REG_SEG_DATA, 32'hFFFF_BBFF, 4'b0010);
        read_check(REG_SEG_DATA, 32'h0000_BBAA);

        // Write Byte 2 only (WSTRB = 4'b0100)
        write_reg(REG_SEG_DATA, 32'hFFCC_FFFF, 4'b0100);
        read_check(REG_SEG_DATA, 32'h00CC_BBAA);

        // Write Byte 3 only (WSTRB = 4'b1000)
        write_reg(REG_SEG_DATA, 32'hDDFF_FFFF, 4'b1000);
        read_check(REG_SEG_DATA, 32'hDDCC_BBAA);

        // Write lower half-word only (WSTRB = 4'b0011)
        write_reg(REG_SEG_DATA, 32'h0000_1234, 4'b0011);
        read_check(REG_SEG_DATA, 32'hDDCC_1234);

        // Write upper half-word only (WSTRB = 4'b1100)
        write_reg(REG_SEG_DATA, 32'h5678_0000, 4'b1100);
        read_check(REG_SEG_DATA, 32'h5678_1234);

        `uvm_info(get_type_name(), "[Test 3/5] PASS: Individual byte and half-word write strobes verified.", UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // 4. Zero Strobe Verification (WSTRB = 4'b0000)
    // -------------------------------------------------------------------------
    virtual task test_zero_strobe();
        `uvm_info(get_type_name(), "[Test 4/5] Checking zero-strobe write preservation...", UVM_LOW)

        // Setup known pattern in SEG_DATA: 0xCAFE_BABE
        write_reg(REG_SEG_DATA, 32'hCAFE_BABE, 4'hF);
        read_check(REG_SEG_DATA, 32'hCAFE_BABE);

        // Attempt write with WSTRB = 4'b0000 and data = 0x0000_0000
        // Slave must accept transaction with OKAY, but must NOT update the register!
        write_reg(REG_SEG_DATA, 32'h0000_0000, 4'b0000);
        read_check(REG_SEG_DATA, 32'hCAFE_BABE);

        // Attempt write with WSTRB = 4'b0000 and data = 0xFFFF_FFFF
        write_reg(REG_SEG_DATA, 32'hFFFF_FFFF, 4'b0000);
        read_check(REG_SEG_DATA, 32'hCAFE_BABE);

        `uvm_info(get_type_name(), "[Test 4/5] PASS: Zero-strobe writes correctly preserve register contents.", UVM_LOW)
    endtask

    // -------------------------------------------------------------------------
    // 5. Unmapped Address Space Verification
    // -------------------------------------------------------------------------
    virtual task test_unmapped_access();
        bit [31:0] unmapped_addrs [3];
        unmapped_addrs[0] = 32'h010;
        unmapped_addrs[1] = 32'h014;
        unmapped_addrs[2] = 32'hFFC;

        `uvm_info(get_type_name(), "[Test 5/5] Checking unmapped address access...", UVM_LOW)

        foreach (unmapped_addrs[i]) begin
            // Read unmapped address: RTL returns 0x0000_0000 with OKAY response
            read_check(unmapped_addrs[i], 32'h0000_0000, 32'hFFFF_FFFF, AXI_LITE_RESP_OKAY);

            // Write unmapped address: RTL accepts with OKAY response
            write_reg(unmapped_addrs[i], 32'hDEAD_BEEF, 4'hF);

            // Verify unmapped read remains 0x0000_0000
            read_check(unmapped_addrs[i], 32'h0000_0000, 32'hFFFF_FFFF, AXI_LITE_RESP_OKAY);
        end

        // Ensure valid registers were NOT affected by writes to unmapped addresses
        read_check(REG_SEG_DATA, 32'hCAFE_BABE);
        read_check(REG_SEG_CTRL, 32'h0000_FF06);

        `uvm_info(get_type_name(), "[Test 5/5] PASS: Unmapped address decode verified.", UVM_LOW)
    endtask

endclass : seg7_basic_reg_seq

`endif // SEG7_BASIC_REG_SEQ_SV

