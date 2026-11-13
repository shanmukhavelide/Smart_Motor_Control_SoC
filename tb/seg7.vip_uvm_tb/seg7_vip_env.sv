class seg7_vip_env extends uvm_env;
  seg7_vip_agent      agent;
  seg7_vip_scoreboard sb;
  `uvm_component_utils(seg7_vip_env)

  function new(string n, uvm_component p);
    super.new(n, p);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = seg7_vip_agent::type_id::create("agent", this);
    sb    = seg7_vip_scoreboard::type_id::create("sb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.mon.ap.connect(sb.mon_imp);
  endfunction
endclass
