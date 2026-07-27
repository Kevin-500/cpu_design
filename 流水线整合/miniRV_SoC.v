`timescale 1ns / 1ps

module miniRV_SoC (
    input  wire         fpga_clk,
    input  wire         fpga_rst,
    input  wire [15:0]  sw,
    output wire [15:0]  led,
    output wire [7:0]   dig_en,
    output wire [7:0]   dig_seg,
    output wire [7:0]   dig_seg1,
    input  wire         rx,
    output wire         tx
);

`ifdef RUN_TRACE
    wire sys_clk = fpga_clk;
    wire sys_rst = fpga_rst;
`else
    wire pll_clk1, pll_lock;
    wire sys_clk = pll_lock & pll_clk1;
    reg  sys_rst;
    always @(posedge fpga_clk) sys_rst <= !fpga_rst | !pll_lock;
    clk_wiz_0 U_clkgen (.clk_in1(fpga_clk), .locked(pll_lock), .clk_out1(pll_clk1));
`endif

    // =====================================================
    // AXI bus signals (cpu_top <-> axi_bridge)
    // =====================================================
    wire [31:0] cpu_awaddr ;
    wire [ 7:0] cpu_awlen  ;
    wire [ 2:0] cpu_awsize ;
    wire [ 1:0] cpu_awburst;
    wire        cpu_awvalid;
    wire        cpu_awready;
    wire [31:0] cpu_wdata  ;
    wire [ 3:0] cpu_wstrb  ;
    wire        cpu_wlast  ;
    wire        cpu_wvalid ;
    wire        cpu_wready ;
    wire        cpu_bready ;
    wire [ 1:0] cpu_bresp  ;
    wire        cpu_bvalid ;
    wire [31:0] cpu_araddr ;
    wire [ 7:0] cpu_arlen  ;
    wire [ 2:0] cpu_arsize ;
    wire [ 1:0] cpu_arburst;
    wire        cpu_arvalid;
    wire        cpu_arready;
    wire        cpu_rready ;
    wire [31:0] cpu_rdata  ;
    wire [ 1:0] cpu_rresp  ;
    wire        cpu_rlast  ;
    wire        cpu_rvalid ;

    cpu_top U_cpu (
        .cpu_clk        (sys_clk),
        .cpu_rst        (sys_rst),
        .m_axi_awaddr   (cpu_awaddr ),
        .m_axi_awlen    (cpu_awlen  ),
        .m_axi_awsize   (cpu_awsize ),
        .m_axi_awburst  (cpu_awburst),
        .m_axi_awvalid  (cpu_awvalid),
        .m_axi_awready  (cpu_awready),
        .m_axi_wdata    (cpu_wdata  ),
        .m_axi_wstrb    (cpu_wstrb  ),
        .m_axi_wlast    (cpu_wlast  ),
        .m_axi_wvalid   (cpu_wvalid ),
        .m_axi_wready   (cpu_wready ),
        .m_axi_bready   (cpu_bready ),
        .m_axi_bresp    (cpu_bresp  ),
        .m_axi_bvalid   (cpu_bvalid ),
        .m_axi_araddr   (cpu_araddr ),
        .m_axi_arlen    (cpu_arlen  ),
        .m_axi_arsize   (cpu_arsize ),
        .m_axi_arburst  (cpu_arburst),
        .m_axi_arvalid  (cpu_arvalid),
        .m_axi_arready  (cpu_arready),
        .m_axi_rready   (cpu_rready ),
        .m_axi_rdata    (cpu_rdata  ),
        .m_axi_rresp    (cpu_rresp  ),
        .m_axi_rlast    (cpu_rlast  ),
        .m_axi_rvalid   (cpu_rvalid )
    );

    // =====================================================
    // axi_bridge (1 master -> N slaves)
    // =====================================================
    localparam N = 6;

    wire [N*32-1:0] m_awaddr  ;
    wire [N* 8-1:0] m_awlen   ;
    wire [N* 3-1:0] m_awsize  ;
    wire [N* 2-1:0] m_awburst ;
    wire [N*32-1:0] m_wdata   ;
    wire [N* 4-1:0] m_wstrb   ;
    wire [N*32-1:0] m_araddr  ;
    wire [N* 8-1:0] m_arlen   ;
    wire [N* 3-1:0] m_arsize  ;
    wire [N* 2-1:0] m_arburst ;
    wire [N*32-1:0] m_rdata   ;
    wire [N* 2-1:0] m_rresp   ;
    wire [N-1:0]    m_awvalid ;
    wire [N-1:0]    m_awready ;
    wire [N-1:0]    m_wlast   ;
    wire [N-1:0]    m_wvalid  ;
    wire [N-1:0]    m_wready  ;
    wire [N-1:0]    m_bready  ;
    wire [N* 2-1:0] m_bresp   ;
    wire [N-1:0]    m_bvalid  ;
    wire [N-1:0]    m_arvalid ;
    wire [N-1:0]    m_arready ;
    wire [N-1:0]    m_rready  ;
    wire [N-1:0]    m_rlast   ;
    wire [N-1:0]    m_rvalid  ;

    axi_bridge U_bridge (
        .aclk           (sys_clk),
        .aresetn        (!sys_rst),
        .s_axi_awaddr   (cpu_awaddr ),
        .s_axi_awlen    (cpu_awlen  ),
        .s_axi_awsize   (cpu_awsize ),
        .s_axi_awburst  (cpu_awburst),
        .s_axi_awvalid  (cpu_awvalid),
        .s_axi_awready  (cpu_awready),
        .s_axi_wdata    (cpu_wdata  ),
        .s_axi_wstrb    (cpu_wstrb  ),
        .s_axi_wlast    (cpu_wlast  ),
        .s_axi_wvalid   (cpu_wvalid ),
        .s_axi_wready   (cpu_wready ),
        .s_axi_bresp    (cpu_bresp  ),
        .s_axi_bvalid   (cpu_bvalid ),
        .s_axi_bready   (cpu_bready ),
        .s_axi_araddr   (cpu_araddr ),
        .s_axi_arlen    (cpu_arlen  ),
        .s_axi_arsize   (cpu_arsize ),
        .s_axi_arburst  (cpu_arburst),
        .s_axi_arvalid  (cpu_arvalid),
        .s_axi_arready  (cpu_arready),
        .s_axi_rdata    (cpu_rdata  ),
        .s_axi_rresp    (cpu_rresp  ),
        .s_axi_rlast    (cpu_rlast  ),
        .s_axi_rvalid   (cpu_rvalid ),
        .s_axi_rready   (cpu_rready ),
        .m_axi_awaddr   (m_awaddr  ),
        .m_axi_awlen    (m_awlen   ),
        .m_axi_awsize   (m_awsize  ),
        .m_axi_awburst  (m_awburst ),
        .m_axi_awvalid  (m_awvalid ),
        .m_axi_awready  (m_awready ),
        .m_axi_wdata    (m_wdata   ),
        .m_axi_wstrb    (m_wstrb   ),
        .m_axi_wlast    (m_wlast   ),
        .m_axi_wvalid   (m_wvalid  ),
        .m_axi_wready   (m_wready  ),
        .m_axi_bresp    (m_bresp   ),
        .m_axi_bvalid   (m_bvalid  ),
        .m_axi_bready   (m_bready  ),
        .m_axi_araddr   (m_araddr  ),
        .m_axi_arlen    (m_arlen   ),
        .m_axi_arsize   (m_arsize  ),
        .m_axi_arburst  (m_arburst ),
        .m_axi_arvalid  (m_arvalid ),
        .m_axi_arready  (m_arready ),
        .m_axi_rdata    (m_rdata   ),
        .m_axi_rresp    (m_rresp   ),
        .m_axi_rlast    (m_rlast   ),
        .m_axi_rvalid   (m_rvalid  ),
        .m_axi_rready   (m_rready  )
    );

    // =====================================================
    // Slave 0: Main Memory (bram_axi)
    // =====================================================
    wire [31:0] bram_awaddr  = m_awaddr [0*32 +:32];
    wire [ 7:0] bram_awlen   = m_awlen  [0* 8 +: 8];
    wire [ 2:0] bram_awsize  = m_awsize [0* 3 +: 3];
    wire [ 1:0] bram_awburst = m_awburst[0* 2 +: 2];
    wire        bram_awvalid = m_awvalid[0];
    wire        bram_awready;
    wire [31:0] bram_wdata   = m_wdata  [0*32 +:32];
    wire [ 3:0] bram_wstrb   = m_wstrb  [0* 4 +: 4];
    wire        bram_wlast   = m_wlast  [0];
    wire        bram_wvalid  = m_wvalid [0];
    wire        bram_wready ;
    wire        bram_bready  = m_bready [0];
    wire [ 1:0] bram_bresp  ;
    wire        bram_bvalid ;
    wire [31:0] bram_araddr  = m_araddr [0*32 +:32];
    wire [ 7:0] bram_arlen   = m_arlen  [0* 8 +: 8];
    wire [ 2:0] bram_arsize  = m_arsize [0* 3 +: 3];
    wire [ 1:0] bram_arburst = m_arburst[0* 2 +: 2];
    wire        bram_arvalid = m_arvalid[0];
    wire        bram_arready;
    wire        bram_rready  = m_rready [0];
    wire [31:0] bram_rdata  ;
    wire [ 1:0] bram_rresp  ;
    wire        bram_rlast  ;
    wire        bram_rvalid ;

    assign m_awready[0]      = bram_awready;
    assign m_wready [0]      = bram_wready ;
    assign m_bresp  [0*2 +:2] = bram_bresp  ;
    assign m_bvalid [0]      = bram_bvalid ;
    assign m_arready[0]      = bram_arready;
    assign m_rdata  [0*32 +:32] = bram_rdata  ;
    assign m_rresp  [0*2 +:2]   = bram_rresp  ;
    assign m_rlast  [0]      = bram_rlast  ;
    assign m_rvalid [0]      = bram_rvalid ;

    bram_axi U_bram (
        .s_aclk         (sys_clk),
        .s_aresetn      (!sys_rst),
        .s_axi_awid     (4'h0),
        .s_axi_awaddr   (bram_awaddr ),
        .s_axi_awlen    (bram_awlen  ),
        .s_axi_awsize   (bram_awsize ),
        .s_axi_awburst  (bram_awburst),
        .s_axi_awvalid  (bram_awvalid),
        .s_axi_awready  (bram_awready),
        .s_axi_wdata    (bram_wdata  ),
        .s_axi_wstrb    (bram_wstrb  ),
        .s_axi_wlast    (bram_wlast  ),
        .s_axi_wvalid   (bram_wvalid ),
        .s_axi_wready   (bram_wready ),
        .s_axi_bresp    (bram_bresp  ),
        .s_axi_bvalid   (bram_bvalid ),
        .s_axi_bready   (bram_bready ),
        .s_axi_arid     (4'h0),
        .s_axi_araddr   (bram_araddr ),
        .s_axi_arlen    (bram_arlen  ),
        .s_axi_arsize   (bram_arsize ),
        .s_axi_arburst  (bram_arburst),
        .s_axi_arvalid  (bram_arvalid),
        .s_axi_arready  (bram_arready),
        .s_axi_rdata    (bram_rdata  ),
        .s_axi_rresp    (bram_rresp  ),
        .s_axi_rlast    (bram_rlast  ),
        .s_axi_rvalid   (bram_rvalid ),
        .s_axi_rready   (bram_rready ),
        .s_axi_bid      (),
        .s_axi_rid      ()
    );

    // =====================================================
    // Slave 1: Switch
    // =====================================================
    wire [31:0] sw_awaddr  = m_awaddr [1*32 +:32];
    wire [ 7:0] sw_awlen   = m_awlen  [1* 8 +: 8];
    wire [ 2:0] sw_awsize  = m_awsize [1* 3 +: 3];
    wire [ 1:0] sw_awburst = m_awburst[1* 2 +: 2];
    wire        sw_awvalid = m_awvalid[1];
    wire        sw_awready;
    wire [31:0] sw_wdata   = m_wdata  [1*32 +:32];
    wire [ 3:0] sw_wstrb   = m_wstrb  [1* 4 +: 4];
    wire        sw_wlast   = m_wlast  [1];
    wire        sw_wvalid  = m_wvalid [1];
    wire        sw_wready ;
    wire        sw_bready  = m_bready [1];
    wire [ 1:0] sw_bresp  ;
    wire        sw_bvalid ;
    wire [31:0] sw_araddr  = m_araddr [1*32 +:32];
    wire [ 7:0] sw_arlen   = m_arlen  [1* 8 +: 8];
    wire [ 2:0] sw_arsize  = m_arsize [1* 3 +: 3];
    wire [ 1:0] sw_arburst = m_arburst[1* 2 +: 2];
    wire        sw_arvalid = m_arvalid[1];
    wire        sw_arready;
    wire        sw_rready  = m_rready [1];
    wire [31:0] sw_rdata  ;
    wire [ 1:0] sw_rresp  ;
    wire        sw_rlast  ;
    wire        sw_rvalid ;

    assign m_awready[1]      = sw_awready;
    assign m_wready [1]      = sw_wready ;
    assign m_bresp  [1*2 +:2] = sw_bresp  ;
    assign m_bvalid [1]      = sw_bvalid ;
    assign m_arready[1]      = sw_arready;
    assign m_rdata  [1*32 +:32] = sw_rdata  ;
    assign m_rresp  [1*2 +:2]   = sw_rresp  ;
    assign m_rlast  [1]      = sw_rlast  ;
    assign m_rvalid [1]      = sw_rvalid ;

    switch_wrap U_switch (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        .s_axi_awaddr   (sw_awaddr ),
        .s_axi_awlen    (sw_awlen  ),
        .s_axi_awsize   (sw_awsize ),
        .s_axi_awburst  (sw_awburst),
        .s_axi_awvalid  (sw_awvalid),
        .s_axi_awready  (sw_awready),
        .s_axi_wdata    (sw_wdata  ),
        .s_axi_wstrb    (sw_wstrb  ),
        .s_axi_wlast    (sw_wlast  ),
        .s_axi_wvalid   (sw_wvalid ),
        .s_axi_wready   (sw_wready ),
        .s_axi_bresp    (sw_bresp  ),
        .s_axi_bvalid   (sw_bvalid ),
        .s_axi_bready   (sw_bready ),
        .s_axi_araddr   (sw_araddr ),
        .s_axi_arlen    (sw_arlen  ),
        .s_axi_arsize   (sw_arsize ),
        .s_axi_arburst  (sw_arburst),
        .s_axi_arvalid  (sw_arvalid),
        .s_axi_arready  (sw_arready),
        .s_axi_rdata    (sw_rdata  ),
        .s_axi_rresp    (sw_rresp  ),
        .s_axi_rlast    (sw_rlast  ),
        .s_axi_rvalid   (sw_rvalid ),
        .s_axi_rready   (sw_rready ),
        .switch_i       (sw)
    );

    // =====================================================
    // Slave 2: LED
    // =====================================================
    wire [31:0] led_awaddr  = m_awaddr [2*32 +:32];
    wire [ 7:0] led_awlen   = m_awlen  [2* 8 +: 8];
    wire [ 2:0] led_awsize  = m_awsize [2* 3 +: 3];
    wire [ 1:0] led_awburst = m_awburst[2* 2 +: 2];
    wire        led_awvalid = m_awvalid[2];
    wire        led_awready;
    wire [31:0] led_wdata   = m_wdata  [2*32 +:32];
    wire [ 3:0] led_wstrb   = m_wstrb  [2* 4 +: 4];
    wire        led_wlast   = m_wlast  [2];
    wire        led_wvalid  = m_wvalid [2];
    wire        led_wready ;
    wire        led_bready  = m_bready [2];
    wire [ 1:0] led_bresp  ;
    wire        led_bvalid ;
    wire [31:0] led_araddr  = m_araddr [2*32 +:32];
    wire [ 7:0] led_arlen   = m_arlen  [2* 8 +: 8];
    wire [ 2:0] led_arsize  = m_arsize [2* 3 +: 3];
    wire [ 1:0] led_arburst = m_arburst[2* 2 +: 2];
    wire        led_arvalid = m_arvalid[2];
    wire        led_arready;
    wire        led_rready  = m_rready [2];
    wire [31:0] led_rdata  ;
    wire [ 1:0] led_rresp  ;
    wire        led_rlast  ;
    wire        led_rvalid ;

    assign m_awready[2]      = led_awready;
    assign m_wready [2]      = led_wready ;
    assign m_bresp  [2*2 +:2] = led_bresp  ;
    assign m_bvalid [2]      = led_bvalid ;
    assign m_arready[2]      = led_arready;
    assign m_rdata  [2*32 +:32] = led_rdata  ;
    assign m_rresp  [2*2 +:2]   = led_rresp  ;
    assign m_rlast  [2]      = led_rlast  ;
    assign m_rvalid [2]      = led_rvalid ;

    led_wrap U_led (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        .s_axi_awaddr   (led_awaddr ),
        .s_axi_awlen    (led_awlen  ),
        .s_axi_awsize   (led_awsize ),
        .s_axi_awburst  (led_awburst),
        .s_axi_awvalid  (led_awvalid),
        .s_axi_awready  (led_awready),
        .s_axi_wdata    (led_wdata  ),
        .s_axi_wstrb    (led_wstrb  ),
        .s_axi_wlast    (led_wlast  ),
        .s_axi_wvalid   (led_wvalid ),
        .s_axi_wready   (led_wready ),
        .s_axi_bresp    (led_bresp  ),
        .s_axi_bvalid   (led_bvalid ),
        .s_axi_bready   (led_bready ),
        .s_axi_araddr   (led_araddr ),
        .s_axi_arlen    (led_arlen  ),
        .s_axi_arsize   (led_arsize ),
        .s_axi_arburst  (led_arburst),
        .s_axi_arvalid  (led_arvalid),
        .s_axi_arready  (led_arready),
        .s_axi_rdata    (led_rdata  ),
        .s_axi_rresp    (led_rresp  ),
        .s_axi_rlast    (led_rlast  ),
        .s_axi_rvalid   (led_rvalid ),
        .s_axi_rready   (led_rready ),
        .led_o          (led)
    );

    // =====================================================
    // Slave 3: Digital Tube
    // =====================================================
    wire [31:0] dig_awaddr  = m_awaddr [3*32 +:32];
    wire [ 7:0] dig_awlen   = m_awlen  [3* 8 +: 8];
    wire [ 2:0] dig_awsize  = m_awsize [3* 3 +: 3];
    wire [ 1:0] dig_awburst = m_awburst[3* 2 +: 2];
    wire        dig_awvalid = m_awvalid[3];
    wire        dig_awready;
    wire [31:0] dig_wdata   = m_wdata  [3*32 +:32];
    wire [ 3:0] dig_wstrb   = m_wstrb  [3* 4 +: 4];
    wire        dig_wlast   = m_wlast  [3];
    wire        dig_wvalid  = m_wvalid [3];
    wire        dig_wready ;
    wire        dig_bready  = m_bready [3];
    wire [ 1:0] dig_bresp  ;
    wire        dig_bvalid ;
    wire [31:0] dig_araddr  = m_araddr [3*32 +:32];
    wire [ 7:0] dig_arlen   = m_arlen  [3* 8 +: 8];
    wire [ 2:0] dig_arsize  = m_arsize [3* 3 +: 3];
    wire [ 1:0] dig_arburst = m_arburst[3* 2 +: 2];
    wire        dig_arvalid = m_arvalid[3];
    wire        dig_arready;
    wire        dig_rready  = m_rready [3];
    wire [31:0] dig_rdata  ;
    wire [ 1:0] dig_rresp  ;
    wire        dig_rlast  ;
    wire        dig_rvalid ;

    assign m_awready[3]      = dig_awready;
    assign m_wready [3]      = dig_wready ;
    assign m_bresp  [3*2 +:2] = dig_bresp  ;
    assign m_bvalid [3]      = dig_bvalid ;
    assign m_arready[3]      = dig_arready;
    assign m_rdata  [3*32 +:32] = dig_rdata  ;
    assign m_rresp  [3*2 +:2]   = dig_rresp  ;
    assign m_rlast  [3]      = dig_rlast  ;
    assign m_rvalid [3]      = dig_rvalid ;

    digled_wrap U_dig (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        .s_axi_awaddr   (dig_awaddr ),
        .s_axi_awlen    (dig_awlen  ),
        .s_axi_awsize   (dig_awsize ),
        .s_axi_awburst  (dig_awburst),
        .s_axi_awvalid  (dig_awvalid),
        .s_axi_awready  (dig_awready),
        .s_axi_wdata    (dig_wdata  ),
        .s_axi_wstrb    (dig_wstrb  ),
        .s_axi_wlast    (dig_wlast  ),
        .s_axi_wvalid   (dig_wvalid ),
        .s_axi_wready   (dig_wready ),
        .s_axi_bresp    (dig_bresp  ),
        .s_axi_bvalid   (dig_bvalid ),
        .s_axi_bready   (dig_bready ),
        .s_axi_araddr   (dig_araddr ),
        .s_axi_arlen    (dig_arlen  ),
        .s_axi_arsize   (dig_arsize ),
        .s_axi_arburst  (dig_arburst),
        .s_axi_arvalid  (dig_arvalid),
        .s_axi_arready  (dig_arready),
        .s_axi_rdata    (dig_rdata  ),
        .s_axi_rresp    (dig_rresp  ),
        .s_axi_rlast    (dig_rlast  ),
        .s_axi_rvalid   (dig_rvalid ),
        .s_axi_rready   (dig_rready ),
        .dig_en         (dig_en),
        .dig_seg        (dig_seg),
        .dig_seg1       (dig_seg1)
    );

    // =====================================================
    // Slave 4: UART
    // =====================================================
    wire [31:0] uart_awaddr  = m_awaddr [4*32 +:32];
    wire [ 7:0] uart_awlen   = m_awlen  [4* 8 +: 8];
    wire [ 2:0] uart_awsize  = m_awsize [4* 3 +: 3];
    wire [ 1:0] uart_awburst = m_awburst[4* 2 +: 2];
    wire        uart_awvalid = m_awvalid[4];
    wire        uart_awready;
    wire [31:0] uart_wdata   = m_wdata  [4*32 +:32];
    wire [ 3:0] uart_wstrb   = m_wstrb  [4* 4 +: 4];
    wire        uart_wlast   = m_wlast  [4];
    wire        uart_wvalid  = m_wvalid [4];
    wire        uart_wready ;
    wire        uart_bready  = m_bready [4];
    wire [ 1:0] uart_bresp  ;
    wire        uart_bvalid ;
    wire [31:0] uart_araddr  = m_araddr [4*32 +:32];
    wire [ 7:0] uart_arlen   = m_arlen  [4* 8 +: 8];
    wire [ 2:0] uart_arsize  = m_arsize [4* 3 +: 3];
    wire [ 1:0] uart_arburst = m_arburst[4* 2 +: 2];
    wire        uart_arvalid = m_arvalid[4];
    wire        uart_arready;
    wire        uart_rready  = m_rready [4];
    wire [31:0] uart_rdata  ;
    wire [ 1:0] uart_rresp  ;
    wire        uart_rlast  ;
    wire        uart_rvalid ;

    assign m_awready[4]      = uart_awready;
    assign m_wready [4]      = uart_wready ;
    assign m_bresp  [4*2 +:2] = uart_bresp  ;
    assign m_bvalid [4]      = uart_bvalid ;
    assign m_arready[4]      = uart_arready;
    assign m_rdata  [4*32 +:32] = uart_rdata  ;
    assign m_rresp  [4*2 +:2]   = uart_rresp  ;
    assign m_rlast  [4]      = uart_rlast  ;
    assign m_rvalid [4]      = uart_rvalid ;

    uart_wrap U_uart (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        .s_axi_awaddr   (uart_awaddr ),
        .s_axi_awlen    (uart_awlen  ),
        .s_axi_awsize   (uart_awsize ),
        .s_axi_awburst  (uart_awburst),
        .s_axi_awvalid  (uart_awvalid),
        .s_axi_awready  (uart_awready),
        .s_axi_wdata    (uart_wdata  ),
        .s_axi_wstrb    (uart_wstrb  ),
        .s_axi_wlast    (uart_wlast  ),
        .s_axi_wvalid   (uart_wvalid ),
        .s_axi_wready   (uart_wready ),
        .s_axi_bresp    (uart_bresp  ),
        .s_axi_bvalid   (uart_bvalid ),
        .s_axi_bready   (uart_bready ),
        .s_axi_araddr   (uart_araddr ),
        .s_axi_arlen    (uart_arlen  ),
        .s_axi_arsize   (uart_arsize ),
        .s_axi_arburst  (uart_arburst),
        .s_axi_arvalid  (uart_arvalid),
        .s_axi_arready  (uart_arready),
        .s_axi_rdata    (uart_rdata  ),
        .s_axi_rresp    (uart_rresp  ),
        .s_axi_rlast    (uart_rlast  ),
        .s_axi_rvalid   (uart_rvalid ),
        .s_axi_rready   (uart_rready ),
        .rx             (rx),
        .tx             (tx)
    );

    // =====================================================
    // Slave 5: Timer
    // =====================================================
    wire [31:0] timer_awaddr  = m_awaddr [5*32 +:32];
    wire [ 7:0] timer_awlen   = m_awlen  [5* 8 +: 8];
    wire [ 2:0] timer_awsize  = m_awsize [5* 3 +: 3];
    wire [ 1:0] timer_awburst = m_awburst[5* 2 +: 2];
    wire        timer_awvalid = m_awvalid[5];
    wire        timer_awready;
    wire [31:0] timer_wdata   = m_wdata  [5*32 +:32];
    wire [ 3:0] timer_wstrb   = m_wstrb  [5* 4 +: 4];
    wire        timer_wlast   = m_wlast  [5];
    wire        timer_wvalid  = m_wvalid [5];
    wire        timer_wready ;
    wire        timer_bready  = m_bready [5];
    wire [ 1:0] timer_bresp  ;
    wire        timer_bvalid ;
    wire [31:0] timer_araddr  = m_araddr [5*32 +:32];
    wire [ 7:0] timer_arlen   = m_arlen  [5* 8 +: 8];
    wire [ 2:0] timer_arsize  = m_arsize [5* 3 +: 3];
    wire [ 1:0] timer_arburst = m_arburst[5* 2 +: 2];
    wire        timer_arvalid = m_arvalid[5];
    wire        timer_arready;
    wire        timer_rready  = m_rready [5];
    wire [31:0] timer_rdata  ;
    wire [ 1:0] timer_rresp  ;
    wire        timer_rlast  ;
    wire        timer_rvalid ;

    assign m_awready[5]      = timer_awready;
    assign m_wready [5]      = timer_wready ;
    assign m_bresp  [5*2 +:2] = timer_bresp  ;
    assign m_bvalid [5]      = timer_bvalid ;
    assign m_arready[5]      = timer_arready;
    assign m_rdata  [5*32 +:32] = timer_rdata  ;
    assign m_rresp  [5*2 +:2]   = timer_rresp  ;
    assign m_rlast  [5]      = timer_rlast  ;
    assign m_rvalid [5]      = timer_rvalid ;

    timer_wrap U_timer (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        .s_axi_awaddr   (timer_awaddr ),
        .s_axi_awlen    (timer_awlen  ),
        .s_axi_awsize   (timer_awsize ),
        .s_axi_awburst  (timer_awburst),
        .s_axi_awvalid  (timer_awvalid),
        .s_axi_awready  (timer_awready),
        .s_axi_wdata    (timer_wdata  ),
        .s_axi_wstrb    (timer_wstrb  ),
        .s_axi_wlast    (timer_wlast  ),
        .s_axi_wvalid   (timer_wvalid ),
        .s_axi_wready   (timer_wready ),
        .s_axi_bresp    (timer_bresp  ),
        .s_axi_bvalid   (timer_bvalid ),
        .s_axi_bready   (timer_bready ),
        .s_axi_araddr   (timer_araddr ),
        .s_axi_arlen    (timer_arlen  ),
        .s_axi_arsize   (timer_arsize ),
        .s_axi_arburst  (timer_arburst),
        .s_axi_arvalid  (timer_arvalid),
        .s_axi_arready  (timer_arready),
        .s_axi_rdata    (timer_rdata  ),
        .s_axi_rresp    (timer_rresp  ),
        .s_axi_rlast    (timer_rlast  ),
        .s_axi_rvalid   (timer_rvalid ),
        .s_axi_rready   (timer_rready )
    );

endmodule
