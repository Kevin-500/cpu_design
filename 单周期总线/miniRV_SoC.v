`timescale 1ns / 1ps
module miniRV_SoC(input wire fpga_clk,input wire fpga_rst,input wire [15:0] sw,output wire [15:0] led,output wire [7:0] dig_en,output wire [7:0] dig_seg,output wire [7:0] dig_seg1,input wire rx,output wire tx);
`ifdef RUN_TRACE
 wire sys_clk=fpga_clk; wire sys_rst=fpga_rst;
`else
 wire pll_clk1,pll_lock; wire sys_clk=pll_lock&pll_clk1; reg sys_rst;
 always @(posedge fpga_clk) sys_rst<=!fpga_rst|!pll_lock;
 clk_wiz_0 U_clkgen(.clk_in1(fpga_clk),.locked(pll_lock),.clk_out1(pll_clk1));
`endif
 wire [31:0] awaddr,wdata,araddr,rdata; wire [7:0] awlen,arlen; wire [2:0] awsize,arsize; wire [1:0] awburst,bresp,arburst,rresp; wire awvalid,awready,wlast,wvalid,wready,bready,bvalid,arvalid,arready,rready,rlast,rvalid; wire [3:0] wstrb;
 cpu_top U_cpu(.cpu_clk(sys_clk),.cpu_rst(sys_rst),.m_axi_awaddr(awaddr),.m_axi_awlen(awlen),.m_axi_awsize(awsize),.m_axi_awburst(awburst),.m_axi_awvalid(awvalid),.m_axi_awready(awready),.m_axi_wdata(wdata),.m_axi_wstrb(wstrb),.m_axi_wlast(wlast),.m_axi_wvalid(wvalid),.m_axi_wready(wready),.m_axi_bready(bready),.m_axi_bresp(bresp),.m_axi_bvalid(bvalid),.m_axi_araddr(araddr),.m_axi_arlen(arlen),.m_axi_arsize(arsize),.m_axi_arburst(arburst),.m_axi_arvalid(arvalid),.m_axi_arready(arready),.m_axi_rready(rready),.m_axi_rdata(rdata),.m_axi_rresp(rresp),.m_axi_rlast(rlast),.m_axi_rvalid(rvalid));
 soc_axi_subsystem U_subsystem(.aclk(sys_clk),.aresetn(!sys_rst),.s_axi_awaddr(awaddr),.s_axi_awlen(awlen),.s_axi_awsize(awsize),.s_axi_awburst(awburst),.s_axi_awvalid(awvalid),.s_axi_awready(awready),.s_axi_wdata(wdata),.s_axi_wstrb(wstrb),.s_axi_wlast(wlast),.s_axi_wvalid(wvalid),.s_axi_wready(wready),.s_axi_bresp(bresp),.s_axi_bvalid(bvalid),.s_axi_bready(bready),.s_axi_araddr(araddr),.s_axi_arlen(arlen),.s_axi_arsize(arsize),.s_axi_arburst(arburst),.s_axi_arvalid(arvalid),.s_axi_arready(arready),.s_axi_rdata(rdata),.s_axi_rresp(rresp),.s_axi_rlast(rlast),.s_axi_rvalid(rvalid),.s_axi_rready(rready),.sw(sw),.led(led),.dig_en(dig_en),.dig_seg(dig_seg),.dig_seg1(dig_seg1),.rx(rx),.tx(tx));
endmodule
