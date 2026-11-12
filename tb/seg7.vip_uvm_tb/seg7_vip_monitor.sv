// =============================================================================
// Seven-Segment VIP Monitor: passively observes seg_o / an_o
//  - keeps a live "display image" (last seg pattern seen per digit)
//  - publishes each completed scan state with its dwell time
//  - auto-detects anode polarity (one-hot = active-high, one-cold = active-low)
// =============================================================================
`ifndef SEG7_VIP_MONITOR_SV
`define SEG7_VIP_MONITOR_SV

class seg7_vip_monitor extends uvm_monitor;
  virtual seg7_vip_if vif;
  uvm_analysis_port #(seg7_vip_item) ap;

  // Live image since last clear_image()
  bit [7:0] img_seg  [8];
  bit       img_seen [8];
  bit       img_an_active_low;

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

  function void clear_image();
    for (int i = 0; i < 8; i++) begin
      img_seg[i]  = 8'h00;
      img_seen[i] = 1'b0;
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

  function void publish(logic [7:0] an, logic [7:0] seg, int dwell);
    seg7_vip_item item;
    bit al;
    item = seg7_vip_item::type_id::create("item");
    item.digit        = decode_digit(an, al);
    item.an_raw       = an;
    item.seg_raw      = seg;
    item.dwell_cycles = dwell;
    ap.write(item);
  endfunction

  task run_phase(uvm_phase phase);
    logic [7:0] cur_an, cur_seg;
    bit         started = 0;
    int         dwell   = 0;
    int         d;
    bit         al;

    clear_image();
    wait (vif.rst_n === 1'b1);
    `uvm_info(get_type_name(), "7-Seg VIP Monitor active and observing seg_o / an_o...", UVM_LOW)

    forever begin
      @(posedge vif.clk);
      #1ps; // sample cleanly after clock-edge update

      if (!started) begin
        started = 1;
        cur_an = vif.an_o; cur_seg = vif.seg_o; dwell = 1;
      end else if ({vif.an_o, vif.seg_o} === {cur_an, cur_seg}) begin
        dwell++;
      end else begin
        publish(cur_an, cur_seg, dwell);
        cur_an = vif.an_o; cur_seg = vif.seg_o; dwell = 1;
      end

      d = decode_digit(vif.an_o, al);
      if (d >= 0) begin
        img_seg[d]        = vif.seg_o;
        img_seen[d]       = 1'b1;
        img_an_active_low = al;
      end
    end
  endtask
endclass : seg7_vip_monitor

`endif // SEG7_VIP_MONITOR_SV
