`timescale 1ns / 1ps
`include "axi_peripheral.vh"
module timer_wrap (`AXI_SLAVE_PORTS);
    wire wr_en, rd_en; wire [31:0] wr_addr, wr_data, rd_addr; wire [3:0] wr_strb;
    reg [63:0] timer; wire [31:0] rd_data = (rd_addr[11:0]==12'h008) ? timer[63:32] : timer[31:0];
    axi_reg_slave U_bus (`AXI_REG_CONNECT, .wr_en(wr_en), .wr_addr(wr_addr),
        .wr_data(wr_data), .wr_strb(wr_strb), .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data));
    always @(posedge aclk or negedge aresetn) if(!aresetn) timer<=0; else timer<=timer+1'b1;
    wire unused = ^{wr_en, wr_addr, wr_data, wr_strb, rd_en};
endmodule
