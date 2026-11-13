// =============================================================================
// Seven-Segment VIP Monitor: passively observes seg_o / an_o
//  - publishes each completed scan state with its dwell time on anode transitions
//  - publishes blank anode states so disabled-display checks observe blank output
//  - auto-detects anode polarity (one-hot = active-high, one-cold = active-low)
//  - broadcasts reset events and marks first dwell intervals after reset/startup
// =============================================================================
`ifndef SEG7_VIP_MONITOR_SV
`define SEG7_VIP_MONITOR_SV

class seg7_vip_monitor extends uvm_monitor;
  virtual seg7_vip_if vif;
  uvm_analysis_port #(seg7_vip_item) ap;

  `uvm_component_utils(seg7_vip_monitor)

  function new(string n, uvm_component p);
    super.new(n, p);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual seg7_vip_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal(get_type_name(), "Virtual interface seg7_vip_if not found in uvm_config_db!")
    end
  endfunction

  // Returns lit digit 0..7, or -1 if blank/invalid. an_al = 1 when one-cold.
  function int decode_digit(logic [7:0] an, output bit an_al);
    an_al = 1'b0;
    if ($isunknown(an)) return -1;
    if ($onehot(an))    return $clog2(an);
    if ($onehot(~an)) begin
      an_al = 1'b1;
      return $clog2(~an);
    end
    return -1;
  endfunction

  function void publish(logic [7:0] an, logic [7:0] seg, int dwell, bit is_partial);
    seg7_vip_item item;
    bit al;
    item = seg7_vip_item::type_id::create("item");
    item.digit         = decode_digit(an, al);
    item.an_raw        = an;
    item.seg_raw       = seg;
    item.dwell_cycles  = dwell;
    item.an_active_low = al;
    item.is_reset      = 1'b0;
    item.is_partial    = is_partial;
    ap.write(item);
  endfunction

  function void publish_reset();
    seg7_vip_item item;
    item = seg7_vip_item::type_id::create("item_reset");
    item.digit         = -1;
    item.an_raw        = 8'h00;
    item.seg_raw       = 8'h00;
    item.dwell_cycles  = 0;
    item.an_active_low = 1'b0;
    item.is_reset      = 1'b1;
    item.is_partial    = 1'b0;
    ap.write(item);
  endfunction

  task run_phase(uvm_phase phase);
    logic [7:0] cur_an, cur_seg;
    bit         started;
    int         dwell;
    bit         first_after_reset;

    // If interface starts in reset at time 0, publish reset and wait for deassertion
    if (vif.rst_n !== 1'b1) begin
      publish_reset();
      wait (vif.rst_n === 1'b1);
    end

    forever begin
      `uvm_info(get_type_name(), "7-Seg VIP Monitor active and observing seg_o / an_o...", UVM_LOW)
      started           = 0;
      dwell             = 0;
      first_after_reset = 1;

      while (vif.rst_n === 1'b1) begin
        @(posedge vif.clk or negedge vif.rst_n);
        if (vif.rst_n !== 1'b1) break;
        #1ps; // sample cleanly after clock-edge update
        if (vif.rst_n !== 1'b1) break;

        // Measure dwell strictly based on an_o transitions, not seg_o transitions
        if (!started) begin
          started = 1;
          cur_an  = vif.an_o;
          cur_seg = vif.seg_o;
          dwell   = 1;
          // Publish observation if starting in blank state
          if (cur_an === 8'h00 || cur_an === 8'hFF) begin
            publish(cur_an, cur_seg, 1, 1'b0);
          end
        end else if (vif.an_o === cur_an) begin
          dwell++;
          // If seg_o changes while same digit remains enabled, update observed pattern without resetting dwell
          if (vif.seg_o !== cur_seg) begin
            cur_seg = vif.seg_o;
          end
          // While blank, publish periodically rather than every clock to keep overhead minimal
          // while ensuring fresh observation windows reliably capture blank evidence
          if ((cur_an === 8'h00 || cur_an === 8'hFF) && (dwell % 8 == 0)) begin
            publish(cur_an, cur_seg, dwell, 1'b0);
          end
        end else begin
          // Anode state changed: publish completed dwell record
          publish(cur_an, cur_seg, dwell, first_after_reset);
          first_after_reset = 0;
          cur_an  = vif.an_o;
          cur_seg = vif.seg_o;
          dwell   = 1;
          // Publish observation if entering blank state
          if (cur_an === 8'h00 || cur_an === 8'hFF) begin
            publish(cur_an, cur_seg, 1, 1'b0);
          end
        end
      end

      // Reset cleanly interrupts current dwell measurement
      started = 0;
      dwell   = 0;
      publish_reset();
      wait (vif.rst_n === 1'b1);
    end
  endtask
endclass : seg7_vip_monitor

`endif // SEG7_VIP_MONITOR_SV
