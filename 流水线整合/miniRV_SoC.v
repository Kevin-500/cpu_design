`timescale 1ns / 1ps

`define TCONN(I) .s_axi_awaddr(mawaddr[(I)*32 +:32]),.s_axi_awlen(mawlen[(I)*8 +:8]),.s_axi_awsize(mawsize[(I)*3 +:3]),.s_axi_awburst(mawburst[(I)*2 +:2]),.s_axi_awvalid(mawvalid[I]),.s_axi_awready(mawready[I]),.s_axi_wdata(mwdata[(I)*32 +:32]),.s_axi_wstrb(mwstrb[(I)*4 +:4]),.s_axi_wlast(mwlast[I]),.s_axi_wvalid(mwvalid[I]),.s_axi_wready(mwready[I]),.s_axi_bresp(mbresp[(I)*2 +:2]),.s_axi_bvalid(mbvalid[I]),.s_axi_bready(mbready[I]),.s_axi_araddr(maraddr[(I)*32 +:32]),.s_axi_arlen(marlen[(I)*8 +:8]),.s_axi_arsize(marsize[(I)*3 +:3]),.s_axi_arburst(marburst[(I)*2 +:2]),.s_axi_arvalid(marvalid[I]),.s_axi_arready(marready[I]),.s_axi_rdata(mrdata[(I)*32 +:32]),.s_axi_rresp(mrresp[(I)*2 +:2]),.s_axi_rlast(mrlast[I]),.s_axi_rvalid(mrvalid[I]),.s_axi_rready(mrready[I])

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

    // AXI bus signals between cpu_top and axi_bridge
    wire [31:0] awaddr, wdata, araddr, rdata;
    wire [7:0]  awlen, arlen;
    wire [2:0]  awsize, arsize;
    wire [1:0]  awburst, bresp, arburst, rresp;
    wire        awvalid, awready, wlast, wvalid, wready;
    wire        bready, bvalid, arvalid, arready;
    wire        rready, rlast, rvalid;
    wire [3:0]  wstrb;

    cpu_top U_cpu (
        .cpu_clk        (sys_clk),
        .cpu_rst        (sys_rst),
        .m_axi_awaddr   (awaddr),
        .m_axi_awlen    (awlen),
        .m_axi_awsize   (awsize),
        .m_axi_awburst  (awburst),
        .m_axi_awvalid  (awvalid),
        .m_axi_awready  (awready),
        .m_axi_wdata    (wdata),
        .m_axi_wstrb    (wstrb),
        .m_axi_wlast    (wlast),
        .m_axi_wvalid   (wvalid),
        .m_axi_wready   (wready),
        .m_axi_bready   (bready),
        .m_axi_bresp    (bresp),
        .m_axi_bvalid   (bvalid),
        .m_axi_araddr   (araddr),
        .m_axi_arlen    (arlen),
        .m_axi_arsize   (arsize),
        .m_axi_arburst  (arburst),
        .m_axi_arvalid  (arvalid),
        .m_axi_arready  (arready),
        .m_axi_rready   (rready),
        .m_axi_rdata    (rdata),
        .m_axi_rresp    (rresp),
        .m_axi_rlast    (rlast),
        .m_axi_rvalid   (rvalid)
    );

    // axi_bridge intermediate wires (N=6 slaves)
    localparam N = 6;

    wire [N*32-1:0] mawaddr;
    wire [N*32-1:0] mwdata;
    wire [N*32-1:0] maraddr;
    wire [N*32-1:0] mrdata;
    wire [N*8-1:0]  mawlen;
    wire [N*8-1:0]  marlen;
    wire [N*3-1:0]  mawsize;
    wire [N*3-1:0]  marsize;
    wire [N*2-1:0]  mawburst;
    wire [N*2-1:0]  mbresp;
    wire [N*2-1:0]  marburst;
    wire [N*2-1:0]  mrresp;
    wire [N*4-1:0]  mwstrb;
    wire [N-1:0]    mawvalid;
    wire [N-1:0]    mawready;
    wire [N-1:0]    mwlast;
    wire [N-1:0]    mwvalid;
    wire [N-1:0]    mwready;
    wire [N-1:0]    mbvalid;
    wire [N-1:0]    mbready;
    wire [N-1:0]    marvalid;
    wire [N-1:0]    marready;
    wire [N-1:0]    mrlast;
    wire [N-1:0]    mrvalid;
    wire [N-1:0]    mrready;

    axi_bridge U_bridge (
        .aclk           (sys_clk),
        .aresetn        (!sys_rst),
        .s_axi_awaddr   (awaddr),
        .s_axi_awlen    (awlen),
        .s_axi_awsize   (awsize),
        .s_axi_awburst  (awburst),
        .s_axi_awvalid  (awvalid),
        .s_axi_awready  (awready),
        .s_axi_wdata    (wdata),
        .s_axi_wstrb    (wstrb),
        .s_axi_wlast    (wlast),
        .s_axi_wvalid   (wvalid),
        .s_axi_wready   (wready),
        .s_axi_bresp    (bresp),
        .s_axi_bvalid   (bvalid),
        .s_axi_bready   (bready),
        .s_axi_araddr   (araddr),
        .s_axi_arlen    (arlen),
        .s_axi_arsize   (arsize),
        .s_axi_arburst  (arburst),
        .s_axi_arvalid  (arvalid),
        .s_axi_arready  (arready),
        .s_axi_rdata    (rdata),
        .s_axi_rresp    (rresp),
        .s_axi_rlast    (rlast),
        .s_axi_rvalid   (rvalid),
        .s_axi_rready   (rready),
        .m_axi_awaddr   (mawaddr),
        .m_axi_awlen    (mawlen),
        .m_axi_awsize   (mawsize),
        .m_axi_awburst  (mawburst),
        .m_axi_awvalid  (mawvalid),
        .m_axi_awready  (mawready),
        .m_axi_wdata    (mwdata),
        .m_axi_wstrb    (mwstrb),
        .m_axi_wlast    (mwlast),
        .m_axi_wvalid   (mwvalid),
        .m_axi_wready   (mwready),
        .m_axi_bresp    (mbresp),
        .m_axi_bvalid   (mbvalid),
        .m_axi_bready   (mbready),
        .m_axi_araddr   (maraddr),
        .m_axi_arlen    (marlen),
        .m_axi_arsize   (marsize),
        .m_axi_arburst  (marburst),
        .m_axi_arvalid  (marvalid),
        .m_axi_arready  (marready),
        .m_axi_rdata    (mrdata),
        .m_axi_rresp    (mrresp),
        .m_axi_rlast    (mrlast),
        .m_axi_rvalid   (mrvalid),
        .m_axi_rready   (mrready)
    );

    // Main Memory (slave 0)
    bram_axi U_bram (
        .s_aclk         (sys_clk),
        .s_aresetn      (!sys_rst),
        .s_axi_awid     (4'h0),
        `TCONN(0),
        .s_axi_bid      (),
        .s_axi_arid     (4'h0),
        .s_axi_rid      ()
    );

    // Peripheral: Switch (slave 1)
    switch_wrap U_switch (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        `TCONN(1),
        .switch_i   (sw)
    );

    // Peripheral: LED (slave 2)
    led_wrap U_led (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        `TCONN(2),
        .led_o      (led)
    );

    // Peripheral: Digital Tube (slave 3)
    digled_wrap U_dig (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        `TCONN(3),
        .dig_en     (dig_en),
        .dig_seg    (dig_seg),
        .dig_seg1   (dig_seg1)
    );

    // Peripheral: UART (slave 4)
    uart_wrap U_uart (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        `TCONN(4),
        .rx         (rx),
        .tx         (tx)
    );

    // Peripheral: Timer (slave 5)
    timer_wrap U_timer (
        .aclk       (sys_clk),
        .aresetn    (!sys_rst),
        `TCONN(5)
    );

endmodule
`undef TCONN
