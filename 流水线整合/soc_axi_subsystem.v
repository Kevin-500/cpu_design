`timescale 1ns / 1ps
`ifdef RUN_TRACE
`define SOC_DEFAULT_WORDS 2052
`else
`define SOC_DEFAULT_WORDS 131072
`endif
`define TCONN(I) .s_axi_awaddr(mawaddr[(I)*32 +:32]),.s_axi_awlen(mawlen[(I)*8 +:8]),.s_axi_awsize(mawsize[(I)*3 +:3]),.s_axi_awburst(mawburst[(I)*2 +:2]),.s_axi_awvalid(mawvalid[I]),.s_axi_awready(mawready[I]),.s_axi_wdata(mwdata[(I)*32 +:32]),.s_axi_wstrb(mwstrb[(I)*4 +:4]),.s_axi_wlast(mwlast[I]),.s_axi_wvalid(mwvalid[I]),.s_axi_wready(mwready[I]),.s_axi_bresp(mbresp[(I)*2 +:2]),.s_axi_bvalid(mbvalid[I]),.s_axi_bready(mbready[I]),.s_axi_araddr(maraddr[(I)*32 +:32]),.s_axi_arlen(marlen[(I)*8 +:8]),.s_axi_arsize(marsize[(I)*3 +:3]),.s_axi_arburst(marburst[(I)*2 +:2]),.s_axi_arvalid(marvalid[I]),.s_axi_arready(marready[I]),.s_axi_rdata(mrdata[(I)*32 +:32]),.s_axi_rresp(mrresp[(I)*2 +:2]),.s_axi_rlast(mrlast[I]),.s_axi_rvalid(mrvalid[I]),.s_axi_rready(mrready[I])
module soc_axi_subsystem #(
    parameter MEM_INIT_FILE = "docs/lab2/miniRV_basic/src/coe/lw.mem",
    parameter integer MEM_WORDS = `SOC_DEFAULT_WORDS
) (
    input  wire         aclk,
    input  wire         aresetn,
    input  wire [31:0]  s_axi_awaddr,
    input  wire [7:0]   s_axi_awlen,
    input  wire [2:0]   s_axi_awsize,
    input  wire [1:0]   s_axi_awburst,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wlast,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,
    input  wire [31:0]  s_axi_araddr,
    input  wire [7:0]   s_axi_arlen,
    input  wire [2:0]   s_axi_arsize,
    input  wire [1:0]   s_axi_arburst,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rlast,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,
    input  wire [15:0]  sw,
    output wire [15:0]  led,
    output wire [7:0]   dig_en,
    output wire [7:0]   dig_seg,
    output wire [7:0]   dig_seg1,
    input  wire         rx,
    output wire         tx
);

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
        .aclk           (aclk),
        .aresetn        (aresetn),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awlen    (s_axi_awlen),
        .s_axi_awsize   (s_axi_awsize),
        .s_axi_awburst  (s_axi_awburst),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wlast    (s_axi_wlast),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arlen    (s_axi_arlen),
        .s_axi_arsize   (s_axi_arsize),
        .s_axi_arburst  (s_axi_arburst),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rlast    (s_axi_rlast),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
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

`ifdef RUN_TRACE
  `ifdef TRACE_USE_AXI_BRAM_MODEL
    axi_bram #(
        .WORDS      (MEM_WORDS),
        .INIT_FILE  (MEM_INIT_FILE)
    ) U_bram (
        .aclk       (aclk),
        .aresetn    (aresetn),
        `TCONN(0)
    );
  `else
    bram_axi U_bram (
        .s_aclk         (aclk),
        .s_aresetn      (aresetn),
        .s_axi_awid     (4'h0),
        .s_axi_awlock   (1'b0),
        .s_axi_awcache  (4'h0),
        .s_axi_awprot   (3'h0),
        `TCONN(0),
        .s_axi_bid      (),
        .s_axi_arid     (4'h0),
        .s_axi_arlock   (1'b0),
        .s_axi_arcache  (4'h0),
        .s_axi_arprot   (3'h0),
        .s_axi_rid      ()
    );
  `endif
`elsif USE_VIVADO_BRAM_AXI
    bram_axi U_bram (
        .s_aclk         (aclk),
        .s_aresetn      (aresetn),
        .s_axi_awid     (4'h0),
        `TCONN(0),
        .s_axi_bid      (),
        .s_axi_arid     (4'h0),
        .s_axi_rid      ()
    );
`else
    axi_bram #(
        .WORDS      (MEM_WORDS),
        .INIT_FILE  (MEM_INIT_FILE)
    ) U_bram (
        .aclk       (aclk),
        .aresetn    (aresetn),
        `TCONN(0)
    );
`endif

    switch_wrap U_switch (
        .aclk       (aclk),
        .aresetn    (aresetn),
        `TCONN(1),
        .switch_i   (sw)
    );

    led_wrap U_led (
        .aclk       (aclk),
        .aresetn    (aresetn),
        `TCONN(2),
        .led_o      (led)
    );

    digled_wrap U_dig (
        .aclk       (aclk),
        .aresetn    (aresetn),
        `TCONN(3),
        .dig_en     (dig_en),
        .dig_seg    (dig_seg),
        .dig_seg1   (dig_seg1)
    );

    uart_wrap U_uart (
        .aclk       (aclk),
        .aresetn    (aresetn),
        `TCONN(4),
        .rx         (rx),
        .tx         (tx)
    );

    timer_wrap U_timer (
        .aclk       (aclk),
        .aresetn    (aresetn),
        `TCONN(5)
    );

endmodule
`undef TCONN
`undef SOC_DEFAULT_WORDS
