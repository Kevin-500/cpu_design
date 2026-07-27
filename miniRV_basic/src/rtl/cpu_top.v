`timescale 1ns / 1ps

`include "defines.vh"

module cpu_top(
    input  wire         cpu_clk,
    input  wire         cpu_rst,
    output wire [31:0]  m_axi_awaddr,
    output wire [7:0]   m_axi_awlen,
    output wire [2:0]   m_axi_awsize,
    output wire [1:0]   m_axi_awburst,
    output wire         m_axi_awvalid,
    input  wire         m_axi_awready,
    output wire [31:0]  m_axi_wdata,
    output wire [3:0]   m_axi_wstrb,
    output wire         m_axi_wlast,
    output wire         m_axi_wvalid,
    input  wire         m_axi_wready,
    output wire         m_axi_bready,
    input  wire [1:0]   m_axi_bresp,
    input  wire         m_axi_bvalid,
    output wire [31:0]  m_axi_araddr,
    output wire [7:0]   m_axi_arlen,
    output wire [2:0]   m_axi_arsize,
    output wire [1:0]   m_axi_arburst,
    output wire         m_axi_arvalid,
    input  wire         m_axi_arready,
    output wire         m_axi_rready,
    input  wire [31:0]  m_axi_rdata,
    input  wire [1:0]   m_axi_rresp,
    input  wire         m_axi_rlast,
    input  wire         m_axi_rvalid
);

    wire if_req, if_valid;
    wire [31:0] if_addr, if_inst;
    wire [3:0] d_ren, d_wen;
    wire [31:0] d_addr, d_rdata, d_wdata;
    wire d_valid, d_wresp;
    wire ic_rrdy, ic_rvalid;
    wire [3:0] ic_ren;
    wire [31:0] ic_raddr;
    wire [`IC_BLK_SIZE-1:0] ic_rdata;
    wire dc_wrdy, dc_rrdy, dc_rvalid;
    wire [3:0] dc_wen, dc_ren;
    wire [31:0] dc_waddr, dc_wdata, dc_raddr;
    wire [`DC_BLK_SIZE-1:0] dc_rdata;

    cpu_core U_core (
        .cpu_clk        (cpu_clk),
        .cpu_rst        (cpu_rst),
        .ifetch_req     (if_req),
        .ifetch_addr    (if_addr),
        .ifetch_valid   (if_valid),
        .ifetch_inst    (if_inst),
        .daccess_ren    (d_ren),
        .daccess_addr   (d_addr),
        .daccess_rvalid (d_valid),
        .daccess_rdata  (d_rdata),
        .daccess_wen    (d_wen),
        .daccess_wdata  (d_wdata),
        .daccess_wresp  (d_wresp)
    );

    ICache U_icache (
        .cpu_clk    (cpu_clk),
        .cpu_rst    (cpu_rst),
        .inst_rreq  (if_req),
        .inst_addr  (if_addr),
        .inst_valid (if_valid),
        .inst_out   (if_inst),
        .dev_rrdy   (ic_rrdy),
        .cpu_ren    (ic_ren),
        .cpu_raddr  (ic_raddr),
        .dev_rvalid (ic_rvalid),
        .dev_rdata  (ic_rdata)
    );

    DCache U_dcache (
        .cpu_clk    (cpu_clk),
        .cpu_rst    (cpu_rst),
        .data_ren   (d_ren),
        .data_addr  (d_addr),
        .data_valid (d_valid),
        .data_rdata (d_rdata),
        .data_wen   (d_wen),
        .data_wdata (d_wdata),
        .data_wresp (d_wresp),
        .dev_wrdy   (dc_wrdy),
        .cpu_wen    (dc_wen),
        .cpu_waddr  (dc_waddr),
        .cpu_wdata  (dc_wdata),
        .dev_rrdy   (dc_rrdy),
        .cpu_ren    (dc_ren),
        .cpu_raddr  (dc_raddr),
        .dev_rvalid (dc_rvalid),
        .dev_rdata  (dc_rdata)
    );

    axi_master U_aximaster (
        .aclk           (cpu_clk),
        .areset         (cpu_rst),
        .ic_dev_rrdy    (ic_rrdy),
        .ic_cpu_ren     (ic_ren),
        .ic_cpu_raddr   (ic_raddr),
        .ic_dev_rvalid  (ic_rvalid),
        .ic_dev_rdata   (ic_rdata),
        .dc_dev_wrdy    (dc_wrdy),
        .dc_cpu_wen     (dc_wen),
        .dc_cpu_waddr   (dc_waddr),
        .dc_cpu_wdata   (dc_wdata),
        .dc_dev_rrdy    (dc_rrdy),
        .dc_cpu_ren     (dc_ren),
        .dc_cpu_raddr   (dc_raddr),
        .dc_dev_rvalid  (dc_rvalid),
        .dc_dev_rdata   (dc_rdata),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awsize   (m_axi_awsize),
        .m_axi_awburst  (m_axi_awburst),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bready   (m_axi_bready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rready   (m_axi_rready),
        .m_axi_rdata    (m_axi_rdata),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rvalid   (m_axi_rvalid)
    );

endmodule
