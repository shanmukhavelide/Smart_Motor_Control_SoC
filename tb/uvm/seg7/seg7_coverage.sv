// =============================================================================
// SEG7 Functional Coverage Subscriber: seg7_coverage
// Collects:
//   1. AXI-Lite register access and protocol coverage (cg_axi_reg) from axi_agent.ap.
//   2. Physical 7-segment display and dwell pin coverage (cg_display_pin) from seg7_agent.mon.ap.
//   3. Cross coverage:
//      - Hexadecimal value x Digit position (16 x 8 = 128 bins).
//      - Decimal point state x Digit position (2 x 8 = 16 bins).
//      - Segment polarity x Anode polarity (2 x 2 = 4 bins).
//      - Register address x Transaction type (6 x 2 = 12 bins).
//
// Uses distinct analysis implementations:
//   - uvm_analysis_imp_axi for AXI transactions (write_axi).
//   - uvm_analysis_imp_display for SEG7 display pin observations (write_display).
// =============================================================================

`ifndef SEG7_COVERAGE_SV
`define SEG7_COVERAGE_SV

// Declare distinct analysis imp suffixes to prevent write() signature collision
`uvm_analysis_imp_decl(_axi)
`uvm_analysis_imp_decl(_display)

class seg7_coverage extends uvm_component;

    // Analysis implementation exports for dual-stream subscription
    uvm_analysis_imp_axi     #(axi_lite_item, seg7_coverage) axi_export;
    uvm_analysis_imp_display #(seg7_vip_item, seg7_coverage) display_export;

    // Internal tracked hardware register state (with byte-strobe awareness)
    bit [31:0] cfg_seg_ctrl;
    bit [7:0]  cfg_seg_dp;
    bit        tracked_en;
    bit        tracked_seg_al;
    bit        tracked_an_al;
    bit [7:0]  tracked_mask;

    // Sampling state for cg_axi_reg
    axi_lite_item curr_axi_item;
    bit [7:0]     curr_mask_val;

    // Sampling state for cg_display_pin
    seg7_vip_item curr_seg7_item;
    int           decoded_hex;
    bit           norm_dp;

    `uvm_component_utils(seg7_coverage)

    // -------------------------------------------------------------------------
    // Helper Function: Decode physical 7-segment active-high pattern to hex 0..15
    // Pattern: {g,f,e,d,c,b,a}
    // -------------------------------------------------------------------------
    function automatic int decode_seg7_to_hex(bit [6:0] s);
        case (s)
            7'h3F: return 0;
            7'h06: return 1;
            7'h5B: return 2;
            7'h4F: return 3;
            7'h66: return 4;
            7'h6D: return 5;
            7'h7D: return 6;
            7'h07: return 7;
            7'h7F: return 8;
            7'h6F: return 9;
            7'h77: return 10;
            7'h7C: return 11;
            7'h39: return 12;
            7'h5E: return 13;
            7'h79: return 14;
            7'h71: return 15;
            default: return -1;
        endcase
    endfunction

    // -------------------------------------------------------------------------
    // Covergroup 1: AXI-Lite Register Access & Protocol Coverage
    // -------------------------------------------------------------------------
    covergroup cg_axi_reg;
        option.name         = "cg_axi_reg";
        option.per_instance = 1;

        // Transaction type: READ / WRITE
        cp_trans_type: coverpoint curr_axi_item.trans_type {
            bins write_trans = {AXI_LITE_WRITE};
            bins read_trans  = {AXI_LITE_READ};
        }

        // Register address: SEG_DATA, SEG_CTRL, SEG_DP, SEG_REFRESH_DIV & unmapped
        cp_reg_addr: coverpoint curr_axi_item.addr[11:0] {
            bins seg_data        = {12'h000};
            bins seg_ctrl        = {12'h004};
            bins seg_dp          = {12'h008};
            bins seg_refresh_div = {12'h00C};
            bins unmapped_low    = {[12'h010:12'h0FF]};
            bins unmapped_high   = {[12'h100:12'hFFF]};
        }

        // WSTRB: zero, individual bytes, half words, full word, others
        cp_wstrb: coverpoint curr_axi_item.strb iff (curr_axi_item.trans_type == AXI_LITE_WRITE) {
            bins zero_strobe    = {4'b0000};
            bins byte_0         = {4'b0001};
            bins byte_1         = {4'b0010};
            bins byte_2         = {4'b0100};
            bins byte_3         = {4'b1000};
            bins half_word_low  = {4'b0011};
            bins half_word_high = {4'b1100};
            bins full_word      = {4'b1111};
            bins other_strobes  = default;
        }

        // AXI response status
        cp_resp: coverpoint curr_axi_item.resp {
            bins resp_okay   = {AXI_LITE_RESP_OKAY};
            bins resp_exokay = {AXI_LITE_RESP_EXOKAY};
            bins resp_slverr = {AXI_LITE_RESP_SLVERR};
            bins resp_decerr = {AXI_LITE_RESP_DECERR};
        }

        // Programmed digit mask in SEG_CTRL[15:8]
        cp_ctrl_mask: coverpoint curr_mask_val iff (curr_axi_item.trans_type == AXI_LITE_WRITE && curr_axi_item.addr[11:0] == 12'h004) {
            bins mask_ff   = {8'hFF};
            bins mask_55   = {8'h55};
            bins mask_aa   = {8'hAA};
            bins mask_0f   = {8'h0F};
            bins mask_f0   = {8'hF0};
            bins mask_01   = {8'h01};
            bins mask_80   = {8'h80};
            bins mask_00   = {8'h00};
            bins others    = default;
        }

        // Programmed display enable in SEG_CTRL[0]
        cp_ctrl_en: coverpoint curr_axi_item.data[0] iff (curr_axi_item.trans_type == AXI_LITE_WRITE && curr_axi_item.addr[11:0] == 12'h004 && curr_axi_item.strb[0]) {
            bins enabled  = {1'b1};
            bins disabled = {1'b0};
        }

        // Cross: Register address x Transaction type
        cross_addr_x_type: cross cp_reg_addr, cp_trans_type;
    endgroup

    // -------------------------------------------------------------------------
    // Covergroup 2: Physical Display & Dwell Pin Coverage
    // -------------------------------------------------------------------------
    covergroup cg_display_pin;
        option.name         = "cg_display_pin";
        option.per_instance = 1;

        // Active digit positions 0-7
        cp_digit: coverpoint curr_seg7_item.digit iff (!curr_seg7_item.is_reset && curr_seg7_item.digit >= 0) {
            bins digit[] = {[0:7]};
        }

        // Blank anode observation
        cp_blank: coverpoint curr_seg7_item.digit iff (!curr_seg7_item.is_reset) {
            bins blank = {-1};
        }

        // Hexadecimal values 0-F decoded from physical segment pins
        cp_hex_val: coverpoint decoded_hex iff (!curr_seg7_item.is_reset && curr_seg7_item.digit >= 0 && decoded_hex >= 0) {
            bins hex_digits[] = {[0:15]};
        }

        // Decimal point state (1 = ON, 0 = OFF) normalized from physical pin
        cp_dp: coverpoint norm_dp iff (!curr_seg7_item.is_reset && curr_seg7_item.digit >= 0) {
            bins dp_off = {1'b0};
            bins dp_on  = {1'b1};
        }

        // Observed physical anode polarity from pin monitor (0 = one-hot active-high, 1 = one-cold active-low)
        cp_an_polarity: coverpoint curr_seg7_item.an_active_low iff (!curr_seg7_item.is_reset && curr_seg7_item.digit >= 0) {
            bins one_hot_active_high = {1'b0};
            bins one_cold_active_low = {1'b1};
        }

        // Tracked segment cathode polarity (0 = active-high, 1 = active-low)
        cp_seg_polarity: coverpoint tracked_seg_al iff (!curr_seg7_item.is_reset && curr_seg7_item.digit >= 0) {
            bins active_high = {1'b0};
            bins active_low  = {1'b1};
        }

        // Observed dwell cycle ranges for valid, complete digit dwells
        cp_dwell_range: coverpoint curr_seg7_item.dwell_cycles iff (!curr_seg7_item.is_reset && !curr_seg7_item.is_partial && curr_seg7_item.digit >= 0) {
            bins edge_1clk  = {1};
            bins fast_dwell = {[2:30]};
            bins norm_dwell = {[31:1000]};
            bins slow_dwell = {[1001:65535]};
        }

        // Reset observation
        cp_reset: coverpoint curr_seg7_item.is_reset {
            bins reset_asserted = {1'b1};
        }

        // Cross: Hexadecimal value x Digit position (16 x 8 = 128 bins)
        cross_hex_x_digit: cross cp_hex_val, cp_digit;

        // Cross: DP state x Digit position (2 x 8 = 16 bins)
        cross_dp_x_digit: cross cp_dp, cp_digit;

        // Cross: Segment polarity x Anode polarity (2 x 2 = 4 bins)
        cross_polarity: cross cp_seg_polarity, cp_an_polarity;
    endgroup

    function new(string name = "seg7_coverage", uvm_component parent = null);
        super.new(name, parent);
        axi_export     = new("axi_export", this);
        display_export = new("display_export", this);

        // Initialize tracked register state to power-on reset defaults
        cfg_seg_ctrl   = 32'h0000_FF06; // EN=0, SEG_ACT_LO=1, AN_ACT_LO=1, MASK=0xFF
        cfg_seg_dp     = 8'h00;
        tracked_en     = 1'b0;
        tracked_seg_al = 1'b1;
        tracked_an_al  = 1'b1;
        tracked_mask   = 8'hFF;
        decoded_hex    = -1;
        norm_dp        = 1'b0;
        curr_mask_val  = 8'hFF;

        cg_axi_reg     = new();
        cg_display_pin = new();
    endfunction

    // -------------------------------------------------------------------------
    // AXI-Lite Transaction Receiver
    // -------------------------------------------------------------------------
    virtual function void write_axi(axi_lite_item item);
        if (item == null) return;
        curr_axi_item = item;

        // Track SEG_CTRL state with byte-strobe awareness
        if (item.trans_type == AXI_LITE_WRITE &&
            item.resp == AXI_LITE_RESP_OKAY &&
            item.addr[11:0] == 12'h004) begin
            for (int b = 0; b < 4; b++) begin
                if (item.strb[b]) begin
                    cfg_seg_ctrl[(b*8) +: 8] = item.data[(b*8) +: 8];
                end
            end
            tracked_en     = cfg_seg_ctrl[0];
            tracked_seg_al = cfg_seg_ctrl[1];
            tracked_an_al  = cfg_seg_ctrl[2];
            tracked_mask   = cfg_seg_ctrl[15:8];
            curr_mask_val  = tracked_mask;
        end

        // Track SEG_DP state with byte-strobe awareness
        if (item.trans_type == AXI_LITE_WRITE &&
            item.resp == AXI_LITE_RESP_OKAY &&
            item.addr[11:0] == 12'h008) begin
            if (item.strb[0]) begin
                cfg_seg_dp = item.data[7:0];
            end
        end

        cg_axi_reg.sample();
    endfunction

    // -------------------------------------------------------------------------
    // SEG7 Physical Pin Observation Receiver
    // -------------------------------------------------------------------------
    virtual function void write_display(seg7_vip_item item);
        bit [7:0] norm_seg;
        if (item == null) return;
        curr_seg7_item = item;

        // Reset notification from monitor: restore default tracking state
        if (item.is_reset) begin
            cfg_seg_ctrl   = 32'h0000_FF06;
            cfg_seg_dp     = 8'h00;
            tracked_en     = 1'b0;
            tracked_seg_al = 1'b1;
            tracked_an_al  = 1'b1;
            tracked_mask   = 8'hFF;
            decoded_hex    = -1;
            norm_dp        = 1'b0;
            cg_display_pin.sample();
            return;
        end

        // Valid active digit illumination
        if (item.digit >= 0 && item.digit < 8) begin
            // Normalize physical segment pattern using tracked segment polarity
            norm_seg    = tracked_seg_al ? ~item.seg_raw : item.seg_raw;
            norm_dp     = norm_seg[7];
            decoded_hex = decode_seg7_to_hex(norm_seg[6:0]);
        end else begin
            decoded_hex = -1;
            norm_dp     = 1'b0;
        end

        cg_display_pin.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), "                SEG7 FUNCTIONAL COVERAGE REPORT                   ", UVM_LOW)
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  AXI Register Coverage   : %0.2f %%", cg_axi_reg.get_inst_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("  Display Pin Coverage    : %0.2f %%", cg_display_pin.get_inst_coverage()), UVM_LOW)
        `uvm_info(get_type_name(), "==================================================================", UVM_LOW)
    endfunction

endclass : seg7_coverage

`endif // SEG7_COVERAGE_SV

