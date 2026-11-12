// Passive agent: seg7 is output-only, stimulus comes from the AXI side of the test.
class seg7_vip_agent extends uvm_agent;
  seg7_vip_monitor mon;
  `uvm_component_utils(seg7_vip_agent)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mon = seg7_vip_monitor::type_id::create("mon", this);
  endfunction
endclass
