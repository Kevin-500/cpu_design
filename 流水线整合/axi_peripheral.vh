`ifndef AXI_PERIPHERAL_VH
`define AXI_PERIPHERAL_VH

`define AXI_SLAVE_PORTS \
    input wire aclk, input wire aresetn, \
    input wire [31:0] s_axi_awaddr, input wire [7:0] s_axi_awlen, \
    input wire [2:0] s_axi_awsize, input wire [1:0] s_axi_awburst, \
    input wire s_axi_awvalid, output wire s_axi_awready, \
    input wire [31:0] s_axi_wdata, input wire [3:0] s_axi_wstrb, \
    input wire s_axi_wlast, input wire s_axi_wvalid, output wire s_axi_wready, \
    output wire [1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready, \
    input wire [31:0] s_axi_araddr, input wire [7:0] s_axi_arlen, \
    input wire [2:0] s_axi_arsize, input wire [1:0] s_axi_arburst, \
    input wire s_axi_arvalid, output wire s_axi_arready, \
    output wire [31:0] s_axi_rdata, output wire [1:0] s_axi_rresp, \
    output wire s_axi_rlast, output wire s_axi_rvalid, input wire s_axi_rready

`define AXI_REG_CONNECT \
    .aclk(aclk), .aresetn(aresetn), \
    .s_axi_awaddr(s_axi_awaddr), .s_axi_awlen(s_axi_awlen), \
    .s_axi_awsize(s_axi_awsize), .s_axi_awburst(s_axi_awburst), \
    .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready), \
    .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wlast(s_axi_wlast), \
    .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready), \
    .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready), \
    .s_axi_araddr(s_axi_araddr), .s_axi_arlen(s_axi_arlen), \
    .s_axi_arsize(s_axi_arsize), .s_axi_arburst(s_axi_arburst), \
    .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready), \
    .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rlast(s_axi_rlast), \
    .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready)

`endif
