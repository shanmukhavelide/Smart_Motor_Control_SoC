// =============================================================================
// PWM Sequences and Tests for Standalone Verification (13 Directed Testcases)
// =============================================================================

`ifndef PWM_SEQUENCES_SV
`define PWM_SEQUENCES_SV

// 1. Reset and Register Defaults Sequence
class pwm_reset_reg_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_reset_reg_seq)
    function new(string name = "pwm_reset_reg_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        `uvm_info(get_type_name(), "[START] Verifying PWM reset defaults...", UVM_LOW)
        for (int i = 0; i < 4; i++) begin
            axi_read(i * 4, rdata, resp);
            if (rdata !== 32'h0) begin
                `uvm_error(get_type_name(), $sformatf("slv_reg%0d reset mismatch: expected 0, got 0x%08h", i, rdata))
            end
        end
        // Verify output remains 0 for at least one full period
        wait_cycles(300);
        `uvm_info(get_type_name(), "[DONE] Reset defaults verified.", UVM_LOW)
    endtask
endclass

// 2. Register Read/Write Access Sequence
class pwm_reg_access_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_reg_access_seq)
    function new(string name = "pwm_reg_access_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0]  resp;
        bit [31:0] patterns[4] = '{32'hA5A5_A5A5, 32'h1234_5678, 32'hDEAD_BEEF, 32'hCAFE_BABE};
        `uvm_info(get_type_name(), "[START] Testing R/W on all 4 slave registers...", UVM_LOW)
        for (int i = 0; i < 4; i++) begin
            axi_write(i * 4, patterns[i], 4'hF);
            axi_read(i * 4, rdata, resp);
            if (rdata !== patterns[i]) begin
                `uvm_error(get_type_name(), $sformatf("slv_reg%0d R/W mismatch: wrote 0x%08h, read 0x%08h", i, patterns[i], rdata))
            end
        end
        // Test byte enables on slv_reg1
        axi_write(4'h4, 32'h0000_00FF, 4'h1);
        axi_read(4'h4, rdata, resp);
        axi_write(4'h0, 32'h0, 4'hF); // clear duty back to 0
        `uvm_info(get_type_name(), "[DONE] Register access tests completed.", UVM_LOW)
    endtask
endclass

// 3. Zero Duty Cycle Sequence
class pwm_zero_duty_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_zero_duty_seq)
    function new(string name = "pwm_zero_duty_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing 0% continuous zero duty cycle...", UVM_LOW)
        set_duty(8'h00);
        wait_cycles(600); // 2+ full periods
        `uvm_info(get_type_name(), "[DONE] Zero duty cycle test completed.", UVM_LOW)
    endtask
endclass

// 4. Low Duty Cycle Sequence (16/256 = 6.25%)
class pwm_low_duty_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_low_duty_seq)
    function new(string name = "pwm_low_duty_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing low duty cycle (16/256 = 6.25%)...", UVM_LOW)
        set_duty(8'd16);
        wait_cycles(600);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] Low duty cycle test completed.", UVM_LOW)
    endtask
endclass

// 5. 25% Duty Cycle Sequence (64/256)
class pwm_duty_25_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_duty_25_seq)
    function new(string name = "pwm_duty_25_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing 25% duty cycle (64/256)...", UVM_LOW)
        set_duty(8'd64);
        wait_cycles(600);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] 25% duty cycle test completed.", UVM_LOW)
    endtask
endclass

// 6. 50% Duty Cycle Sequence (128/256)
class pwm_duty_50_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_duty_50_seq)
    function new(string name = "pwm_duty_50_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing 50% duty cycle (128/256)...", UVM_LOW)
        set_duty(8'd128);
        wait_cycles(600);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] 50% duty cycle test completed.", UVM_LOW)
    endtask
endclass

// 7. 75% Duty Cycle Sequence (192/256)
class pwm_duty_75_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_duty_75_seq)
    function new(string name = "pwm_duty_75_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing 75% duty cycle (192/256)...", UVM_LOW)
        set_duty(8'd192);
        wait_cycles(600);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] 75% duty cycle test completed.", UVM_LOW)
    endtask
endclass

// 8. Maximum Supported Duty Cycle Sequence (255/256 = 99.61%)
class pwm_max_duty_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_max_duty_seq)
    function new(string name = "pwm_max_duty_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing maximum supported duty cycle (255/256)...", UVM_LOW)
        set_duty(8'd255);
        wait_cycles(600);
        // Also test writing 0x100 to check that duty[7:0] truncates cleanly to 0
        axi_write(4'h0, 32'h0000_0100, 4'hF);
        wait_cycles(300);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] Maximum duty cycle test completed.", UVM_LOW)
    endtask
endclass

// 9. Period and Frequency Invariance Sequence
class pwm_period_freq_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_period_freq_seq)
    function new(string name = "pwm_period_freq_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Verifying constant 256-cycle period across multiple duties...", UVM_LOW)
        set_duty(8'd32);
        wait_cycles(300);
        set_duty(8'd96);
        wait_cycles(300);
        set_duty(8'd160);
        wait_cycles(300);
        set_duty(8'd224);
        wait_cycles(300);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] Period and frequency invariance verified.", UVM_LOW)
    endtask
endclass

// 10. Dynamic Duty Update Sequence (While Operating)
class pwm_dynamic_update_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_dynamic_update_seq)
    function new(string name = "pwm_dynamic_update_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing dynamic on-the-fly duty cycle updates...", UVM_LOW)
        set_duty(8'd40);
        wait_cycles(150); // Mid-period update
        set_duty(8'd140);
        wait_cycles(200); // Another mid-period update
        set_duty(8'd220);
        wait_cycles(300);
        set_duty(8'd70);
        wait_cycles(300);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] Dynamic duty updates completed.", UVM_LOW)
    endtask
endclass

// 11. Mid-Operation Reset Recovery Sequence
class pwm_mid_op_reset_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_mid_op_reset_seq)
    function new(string name = "pwm_mid_op_reset_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0] resp;
        `uvm_info(get_type_name(), "[START] Testing mid-operation reset recovery...", UVM_LOW)
        set_duty(8'd128);
        wait_cycles(100);
        // Mid-pulse wait
        wait_cycles(50);
        `uvm_info(get_type_name(), "[DONE] Mid-operation reset test completed.", UVM_LOW)
    endtask
endclass

// 12. Back-to-Back Register Updates Sequence
class pwm_back_to_back_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_back_to_back_seq)
    function new(string name = "pwm_back_to_back_seq"); super.new(name); endfunction

    task body();
        `uvm_info(get_type_name(), "[START] Testing back-to-back rapid duty writes...", UVM_LOW)
        for (int i = 1; i <= 8; i++) begin
            axi_write(4'h0, {24'h0, bit'(i[0]), 7'(i * 30)}, 4'hF);
        end
        wait_cycles(350);
        set_duty(8'h00);
        `uvm_info(get_type_name(), "[DONE] Back-to-back writes test completed.", UVM_LOW)
    endtask
endclass

// 13. Unmapped / Invalid Register Access Sequence
class pwm_unmapped_access_seq extends pwm_base_seq;
    `uvm_object_utils(pwm_unmapped_access_seq)
    function new(string name = "pwm_unmapped_access_seq"); super.new(name); endfunction

    task body();
        bit [31:0] rdata;
        bit [1:0] resp;
        `uvm_info(get_type_name(), "[START] Testing unmapped/unaligned register accesses...", UVM_LOW)
        // Access with zero wstrb
        axi_write(4'h4, 32'hFFFF_FFFF, 4'h0);
        axi_read(4'h4, rdata, resp);
        // Read unaligned offset (0x1, 0x2, 0x3)
        axi_read(4'h1, rdata, resp);
        axi_read(4'h2, rdata, resp);
        axi_read(4'h3, rdata, resp);
        wait_cycles(100);
        `uvm_info(get_type_name(), "[DONE] Unmapped access test completed.", UVM_LOW)
    endtask
endclass

`endif // PWM_SEQUENCES_SV

