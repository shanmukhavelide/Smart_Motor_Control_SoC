// =============================================================================
// Reusable AXI4-Lite Master Driver: axi_lite_driver
// Executes compliant AXI4-Lite write and read channel handshakes
// Parameterized address and data widths (default ADDR=32, DATA=32)
// Handles AW/W concurrent/independent handshakes, delayed responses, backpressure,
// reset aborts, and configurable timeouts.
// =============================================================================

`ifndef AXI_LITE_DRIVER_SV
`define AXI_LITE_DRIVER_SV

class axi_lite_driver #(
    int ADDR_WIDTH = 32,
    int DATA_WIDTH = 32
) extends uvm_driver #(axi_lite_item);

    typedef virtual axi_lite_if #(ADDR_WIDTH, DATA_WIDTH) vif_t;
    vif_t vif;

    // Analysis port for reporting driven transactions
    uvm_analysis_port #(axi_lite_item) drv_ap;

    // Default transaction timeout in clock cycles
    int default_timeout_cycles = 1000;

    `uvm_component_param_utils(axi_lite_driver#(ADDR_WIDTH, DATA_WIDTH))

    function new(string name = "axi_lite_driver", uvm_component parent = null);
        super.new(name, parent);
        drv_ap = new("drv_ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(vif_t)::get(this, "", "vif", vif));
        void'(uvm_config_db#(int)::get(this, "", "default_timeout_cycles", default_timeout_cycles));
    endfunction

    function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        if (vif == null) begin
            `uvm_fatal(get_type_name(),
                $sformatf("Virtual interface axi_lite_if#(%0d,%0d) is null at %s! Must be configured in uvm_config_db or passed by agent.",
                          ADDR_WIDTH, DATA_WIDTH, get_full_name()))
        end
    endfunction

    task run_phase(uvm_phase phase);
        reset_signals();

        forever begin
            // Wait for reset to be deasserted
            wait(vif.rst_n === 1'b1);
            @(vif.cb_drv);

            seq_item_port.get_next_item(req);

            // Re-check reset in case it asserted right when item was fetched
            if (vif.rst_n !== 1'b1) begin
                reset_signals();
                wait(vif.rst_n === 1'b1);
                @(vif.cb_drv);
            end

            if (req.trans_type == AXI_LITE_WRITE) begin
                drive_write(req);
            end else begin
                drive_read(req);
            end

            drv_ap.write(req);
            seq_item_port.item_done();
        end
    endtask

    // -------------------------------------------------------------------------
    // Reset signals to protocol idle state
    // -------------------------------------------------------------------------
    virtual task reset_signals();
        vif.cb_drv.awaddr  <= '0;
        vif.cb_drv.awprot  <= '0;
        vif.cb_drv.awvalid <= 1'b0;

        vif.cb_drv.wdata   <= '0;
        vif.cb_drv.wstrb   <= '0;
        vif.cb_drv.wvalid  <= 1'b0;

        vif.cb_drv.bready  <= 1'b0;

        vif.cb_drv.araddr  <= '0;
        vif.cb_drv.arprot  <= '0;
        vif.cb_drv.arvalid <= 1'b0;

        vif.cb_drv.rready  <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Write Transaction Execution
    // Handles AW and W channels concurrently/independently in any arrival order
    // -------------------------------------------------------------------------
    virtual task drive_write(axi_lite_item req);
        bit aw_done = 1'b0;
        bit w_done  = 1'b0;
        bit b_done  = 1'b0;
        int cycles  = 0;
        int timeout = (req.timeout_cycles > 0) ? req.timeout_cycles : default_timeout_cycles;
        bit [(DATA_WIDTH/8)-1:0] active_strb;

        active_strb = req.strb[(DATA_WIDTH/8)-1:0];

        `uvm_info(get_type_name(),
            $sformatf("Starting AXI WRITE: addr=0x%0h data=0x%0h strb=0x%0h",
                      req.addr[ADDR_WIDTH-1:0], req.data[DATA_WIDTH-1:0], active_strb),
            UVM_HIGH)

        // Drive AW and W simultaneously on clocking block
        vif.cb_drv.awaddr  <= req.addr[ADDR_WIDTH-1:0];
        vif.cb_drv.awprot  <= req.prot;
        vif.cb_drv.awvalid <= 1'b1;

        vif.cb_drv.wdata   <= req.data[DATA_WIDTH-1:0];
        vif.cb_drv.wstrb   <= active_strb;
        vif.cb_drv.wvalid  <= 1'b1;

        // Loop until both AW and W handshakes complete
        while (!(aw_done && w_done)) begin
            @(vif.cb_drv);
            cycles++;

            if (vif.rst_n !== 1'b1) begin
                `uvm_warning(get_type_name(), "Reset asserted during AXI WRITE AW/W phase; aborting transaction.")
                reset_signals();
                req.is_error = 1'b1;
                return;
            end

            // AW handshake check: AWVALID is asserted while !aw_done; deassert upon AWREADY
            if (!aw_done && vif.cb_drv.awready) begin
                vif.cb_drv.awvalid <= 1'b0;
                aw_done = 1'b1;
            end

            // W handshake check: WVALID is asserted while !w_done; deassert upon WREADY
            if (!w_done && vif.cb_drv.wready) begin
                vif.cb_drv.wvalid <= 1'b0;
                w_done = 1'b1;
            end

            // Timeout check: only trigger if AW/W phase is still incomplete
            if (!(aw_done && w_done) && cycles >= timeout) begin
                `uvm_error(get_type_name(),
                    $sformatf("AXI WRITE timeout waiting for AW/W handshakes (addr=0x%0h, aw_done=%0d, w_done=%0d after %0d cycles)",
                              req.addr[ADDR_WIDTH-1:0], aw_done, w_done, cycles))
                reset_signals();
                req.is_error = 1'b1;
                return;
            end
        end

        // AW and W handshakes completed; now wait for write response on B channel
        vif.cb_drv.bready <= 1'b1;

        while (!b_done) begin
            @(vif.cb_drv);
            cycles++;

            if (vif.rst_n !== 1'b1) begin
                `uvm_warning(get_type_name(), "Reset asserted during AXI WRITE B phase; aborting transaction.")
                reset_signals();
                req.is_error = 1'b1;
                return;
            end

            // B handshake check: BREADY is asserted while !b_done; deassert upon BVALID
            if (!b_done && vif.cb_drv.bvalid) begin
                req.resp     = axi_lite_resp_e'(vif.cb_drv.bresp);
                req.is_error = (vif.cb_drv.bresp != 2'b00);
                vif.cb_drv.bready <= 1'b0;
                b_done = 1'b1;
            end

            // Timeout check for B response
            if (!b_done && cycles >= timeout) begin
                `uvm_error(get_type_name(),
                    $sformatf("AXI WRITE timeout waiting for BVALID (addr=0x%0h after %0d cycles)",
                              req.addr[ADDR_WIDTH-1:0], cycles))
                reset_signals();
                req.is_error = 1'b1;
                return;
            end
        end

        `uvm_info(get_type_name(),
            $sformatf("Completed AXI WRITE: addr=0x%0h resp=%s err=%0d in %0d cycles",
                      req.addr[ADDR_WIDTH-1:0], req.resp.name(), req.is_error, cycles),
            UVM_HIGH)
    endtask

    // -------------------------------------------------------------------------
    // Read Transaction Execution
    // Handles AR address handshake followed by R data/response handshake
    // -------------------------------------------------------------------------
    virtual task drive_read(axi_lite_item req);
        bit ar_done = 1'b0;
        bit r_done  = 1'b0;
        int cycles  = 0;
        int timeout = (req.timeout_cycles > 0) ? req.timeout_cycles : default_timeout_cycles;

        `uvm_info(get_type_name(),
            $sformatf("Starting AXI READ: addr=0x%0h", req.addr[ADDR_WIDTH-1:0]),
            UVM_HIGH)

        // Drive AR channel
        vif.cb_drv.araddr  <= req.addr[ADDR_WIDTH-1:0];
        vif.cb_drv.arprot  <= req.prot;
        vif.cb_drv.arvalid <= 1'b1;

        // Loop until AR handshake completes
        while (!ar_done) begin
            @(vif.cb_drv);
            cycles++;

            if (vif.rst_n !== 1'b1) begin
                `uvm_warning(get_type_name(), "Reset asserted during AXI READ AR phase; aborting transaction.")
                reset_signals();
                req.is_error = 1'b1;
                return;
            end

            // AR handshake check: ARVALID is asserted while !ar_done; deassert upon ARREADY
            if (!ar_done && vif.cb_drv.arready) begin
                vif.cb_drv.arvalid <= 1'b0;
                ar_done = 1'b1;
            end

            // Timeout check for AR address phase
            if (!ar_done && cycles >= timeout) begin
                `uvm_error(get_type_name(),
                    $sformatf("AXI READ timeout waiting for AR handshake (addr=0x%0h after %0d cycles)",
                              req.addr[ADDR_WIDTH-1:0], cycles))
                reset_signals();
                req.is_error = 1'b1;
                return;
            end
        end

        // AR handshake completed; assert RREADY and wait for RVALID
        vif.cb_drv.rready <= 1'b1;

        while (!r_done) begin
            @(vif.cb_drv);
            cycles++;

            if (vif.rst_n !== 1'b1) begin
                `uvm_warning(get_type_name(), "Reset asserted during AXI READ R phase; aborting transaction.")
                reset_signals();
                req.is_error = 1'b1;
                return;
            end

            // R handshake check: RREADY is asserted while !r_done; deassert upon RVALID
            if (!r_done && vif.cb_drv.rvalid) begin
                req.data     = 32'(vif.cb_drv.rdata);
                req.rdata    = 32'(vif.cb_drv.rdata);
                req.resp     = axi_lite_resp_e'(vif.cb_drv.rresp);
                req.is_error = (vif.cb_drv.rresp != 2'b00);
                vif.cb_drv.rready <= 1'b0;
                r_done = 1'b1;
            end

            // Timeout check for R data phase
            if (!r_done && cycles >= timeout) begin
                `uvm_error(get_type_name(),
                    $sformatf("AXI READ timeout waiting for RVALID (addr=0x%0h after %0d cycles)",
                              req.addr[ADDR_WIDTH-1:0], cycles))
                reset_signals();
                req.is_error = 1'b1;
                return;
            end
        end

        `uvm_info(get_type_name(),
            $sformatf("Completed AXI READ: addr=0x%0h data=0x%0h resp=%s err=%0d in %0d cycles",
                      req.addr[ADDR_WIDTH-1:0], req.data, req.resp.name(), req.is_error, cycles),
            UVM_HIGH)
    endtask

endclass : axi_lite_driver

`endif // AXI_LITE_DRIVER_SV
