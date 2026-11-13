// =============================================================================
// Seven-Segment VIP Item: one completed scan state (digit lit + how long)
// digit = 0..7 when exactly one anode is active, -1 when blank/invalid
// =============================================================================
`ifndef SEG7_VIP_ITEM_SV
`define SEG7_VIP_ITEM_SV

class seg7_vip_item extends uvm_sequence_item;
  int       digit;
  bit [7:0] seg_raw;       // seg_o as seen on the pins (polarity not removed)
  bit [7:0] an_raw;        // an_o as seen on the pins
  int       dwell_cycles;  // clocks this state was held
  bit       an_active_low; // 1 when one-cold active-low, 0 when one-hot active-high
  bit       is_reset;      // 1 when broadcast marks an interface reset event
  bit       is_partial;    // 1 when interval may be partial (e.g. first after startup/reset)

  `uvm_object_utils_begin(seg7_vip_item)
    `uvm_field_int(digit,         UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(seg_raw,       UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(an_raw,        UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(dwell_cycles,  UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(an_active_low, UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(is_reset,      UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(is_partial,    UVM_ALL_ON | UVM_BIN)
  `uvm_object_utils_end

  function new(string name = "seg7_vip_item");
    super.new(name);
  endfunction
endclass : seg7_vip_item

`endif // SEG7_VIP_ITEM_SV
